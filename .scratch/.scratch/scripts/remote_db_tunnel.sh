CLUSTER=public-cluster-ProtechtDev
SERVICE_NAME=platform-api
ENV=dev
AWS_REGION=us-west-2
DATABASE_URL=aurora-protecht-protechtdev-provisioned.cluster-ckyucx1pqexy.us-west-2.rds.amazonaws.com
# DATABSE_URL=aurora-protechtdev.cluster-ckyucx1pqexy.us-west-2.rds.amazonaws.com
DATABASE_PORT=5432
LOCAL_PORT=2222

saml2aws login -a $ENV

TASK_ID=$(saml2aws exec -a $ENV -- aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE_NAME | jq -r '.taskArns[0] | split("/") | last')

echo "Running tunnel for:"
echo $CLUSTER
echo $SERVICE_NAME
echo "Task id: $TASK_ID"
echo $DATABASE_URL

RUNTIME_ID=$(saml2aws exec -a $ENV -- aws ecs describe-tasks \
  --cluster $CLUSTER \
  --task $TASK_ID \
  --region us-west-2 \
  --query "tasks[].containers[?name=='$SERVICE_NAME'].runtimeId | [0] | [0]" | jq -r '.')

saml2aws exec -a $ENV -- aws ssm start-session \
  --target "ecs:${CLUSTER}_${TASK_ID}_${RUNTIME_ID}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --region us-west-2 \
  --parameters "{\"host\":[\"$DATABASE_URL\"],\"portNumber\":[\"$DATABASE_PORT\"], \"localPortNumber\":[\"$LOCAL_PORT\"]}"
