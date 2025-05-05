#!/bin/bash
set -euo pipefail

# Ensure required commands are installed
for cmd in jq fzf saml2aws aws; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# Prompt for environment and region inputs
read -rp "Enter environment (e.g., dev): " ENV
read -rp "Enter AWS region (default us-west-2): " region_input
AWS_REGION=${region_input:-us-west-2}

# Authenticate using saml2aws
echo "Logging into environment '$ENV'..."
saml2aws login -a "$ENV"

declare -a TASK_ITEMS

echo "Gathering ECS tasks across clusters in region '$AWS_REGION'..."

# List all clusters in the specified region
CLUSTERS=$(
  saml2aws exec -a "$ENV" -- aws ecs list-clusters --region "$AWS_REGION" |
    jq -r '.clusterArns[]'
)

if [ -z "$CLUSTERS" ]; then
  echo "No clusters found in region '$AWS_REGION'. Exiting."
  exit 1
fi

# Iterate over each cluster to gather tasks and containers
for cluster in $CLUSTERS; do
  TASK_ARNS=$(
    saml2aws exec -a "$ENV" -- aws ecs list-tasks \
      --cluster "$cluster" \
      --region "$AWS_REGION" |
      jq -r '.taskArns[]'
  )
  # Skip clusters with no tasks
  [ -z "$TASK_ARNS" ] && continue

  for task_arn in $TASK_ARNS; do
    task_id=$(basename "$task_arn")
    # Fetch container names for the task
    CONTAINERS=$(
      saml2aws exec -a "$ENV" -- aws ecs describe-tasks \
        --cluster "$cluster" \
        --tasks "$task_id" \
        --region "$AWS_REGION" |
        jq -r '.tasks[].containers[].name'
    )
    for container in $CONTAINERS; do
      # Create a selectable entry for each container
      TASK_ITEMS+=("$cluster|$task_id|$container")
    done
  done
done

if [ "${#TASK_ITEMS[@]}" -eq 0 ]; then
  echo "No ECS tasks found in region '$AWS_REGION'. Exiting."
  exit 1
fi

# Use fzf to interactively select a container with a preview of its details
SELECTED=$(
  printf "%s\n" "${TASK_ITEMS[@]}" |
    fzf \
      --delimiter='|' \
      --preview='
        saml2aws exec -a "'"$ENV"'" -- aws ecs describe-tasks \
          --cluster {1} --tasks {2} \
          --region "'"$AWS_REGION"'" \
          --query "tasks[].containers[?name==\"{3}\"]" \
          | jq .
      ' \
      --prompt="Select cluster/task/container to bash into: "
)

if [ -z "$SELECTED" ]; then
  echo "No selection made. Exiting."
  exit 1
fi

# Parse the selected line to extract cluster, task ID, and container name
SELECTED_CLUSTER=$(echo "$SELECTED" | cut -d'|' -f1 | xargs)
SELECTED_TASK_ID=$(echo "$SELECTED" | cut -d'|' -f2 | xargs)
SELECTED_CONTAINER=$(echo "$SELECTED" | cut -d'|' -f3 | xargs)

echo "Launching bash in container '$SELECTED_CONTAINER' on task '$SELECTED_TASK_ID' in cluster '$SELECTED_CLUSTER'..."

# Execute an interactive bash session in the selected container
saml2aws exec -a "$ENV" -- aws --region "$AWS_REGION" ecs execute-command \
  --cluster "$SELECTED_CLUSTER" \
  --task "$SELECTED_TASK_ID" \
  --container "$SELECTED_CONTAINER" \
  --command "/bin/bash" \
  --interactive
