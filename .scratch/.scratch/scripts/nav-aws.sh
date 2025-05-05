#!/bin/bash
set -euo pipefail

# Ensure required commands are installed
for cmd in jq fzf saml2aws aws; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# User inputs for environment and database connection details
read -rp "Enter environment (e.g., dev): " ENV
read -rp "Enter database URL: " DATABASE_URL
read -rp "Enter database port (e.g., 5432): " DATABASE_PORT
read -rp "Enter local port to forward (e.g., 2222): " LOCAL_PORT

# Use default AWS region, adjust as necessary
AWS_REGION="${AWS_REGION:-us-west-2}"

# Authenticate using saml2aws
echo "Logging into environment '$ENV'..."
saml2aws login -a "$ENV"

echo "Gathering all ECS tasks in region '$AWS_REGION' across available clusters..."

declare -a TASK_ITEMS

# List all clusters in the specified region
CLUSTERS=$(saml2aws exec -a "$ENV" -- aws ecs list-clusters --region "$AWS_REGION" | jq -r '.clusterArns[]')

# Iterate over clusters and list tasks for each
for cluster in $CLUSTERS; do
  TASK_ARNS=$(saml2aws exec -a "$ENV" -- aws ecs list-tasks --cluster "$cluster" --region "$AWS_REGION" | jq -r '.taskArns[]')
  for task_arn in $TASK_ARNS; do
    # Extract task ID and store along with cluster ARN for display
    task_id=$(basename "$task_arn")
    TASK_ITEMS+=("$cluster | $task_id")
  done
done

# Abort if no tasks were found
if [ "${#TASK_ITEMS[@]}" -eq 0 ]; then
  echo "No ECS tasks found in region '$AWS_REGION'. Exiting."
  exit 1
fi

# Present all found tasks with clusters to the user for selection via fzf
SELECTED=$(printf "%s\n" "${TASK_ITEMS[@]}" | fzf --prompt="Select a task: ")

# Validate selection
if [ -z "$SELECTED" ]; then
  echo "No selection made. Exiting."
  exit 1
fi

# Parse selected cluster and task ID
SELECTED_CLUSTER=$(echo "$SELECTED" | cut -d'|' -f1 | xargs)
SELECTED_TASK_ID=$(echo "$SELECTED" | cut -d'|' -f2 | xargs)

echo "Selected Cluster: $SELECTED_CLUSTER"
echo "Selected Task ID: $SELECTED_TASK_ID"

# Retrieve runtime ID from the first container of the selected task
RUNTIME_ID=$(saml2aws exec -a "$ENV" -- aws ecs describe-tasks \
  --cluster "$SELECTED_CLUSTER" \
  --tasks "$SELECTED_TASK_ID" \
  --region "$AWS_REGION" \
  --query "tasks[].containers[0].runtimeId" |
  jq -r '.')

if [ -z "$RUNTIME_ID" ] || [ "$RUNTIME_ID" == "null" ]; then
  echo "Could not retrieve runtime ID for the selected task. Exiting."
  exit 1
fi

echo "Starting port-forwarding session to database at $DATABASE_URL:$DATABASE_PORT via local port $LOCAL_PORT..."

# Initiate SSM port-forwarding session using the retrieved runtime ID
saml2aws exec -a "$ENV" -- aws ssm start-session \
  --target "ecs:${SELECTED_CLUSTER}_${SELECTED_TASK_ID}_${RUNTIME_ID}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --region "$AWS_REGION" \
  --parameters "{\"host\":[\"$DATABASE_URL\"],\"portNumber\":[\"$DATABASE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}"
