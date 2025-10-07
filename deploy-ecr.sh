#!/bin/bash
START_TIME=$(date -R)
GLOBAL_OVERRIDES=$1

set -e  # Exit on any error

export PERMISSIONS_BOUNDARY="none"
######## Get script parameters separated by ; and set them as global variables #########
OLD_IFS=$IFS # backup original separator (new line usually) so we can revert it as other code might rely on it
export IFS=";"
for keyVal in $GLOBAL_OVERRIDES; do
  KEY=${keyVal%=*}
  VALUE=${keyVal#*=}
  export ${KEY}=${VALUE}
done
export IFS=$OLD_IFS # put separator back to normal

if [ -z "${AWS_REGION}" ]
then
  echo "AWS_REGION environment variable is not set. Aborting."
  exit 1
fi

if [ -z "${ACCOUNT_ID}" ]
then
  export ACCOUNT_ID=`aws sts get-caller-identity | jq -r '.Account'`
fi

# Configuration
APP_NAME="manual-app"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
PREFIX="${APP_NAME}-${ENVIRONMENT_NAME}-"
POSTFIX="-${ACCOUNT_ID}-${AWS_REGION}"
ECS_CLUSTER_NAME="${PREFIX}cluster${POSTFIX}"
ECS_SERVICE_NAME="${PREFIX}service${POSTFIX}"
ECR_REPOSITORY_NAME="${PREFIX}repository${POSTFIX}"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
CONTAINER_PORT=3000
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Create ECR repo if it doesn’t exist
if ! aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION >/dev/null 2>&1; then
  echo "Creating ECR repository: $ECR_REPOSITORY_NAME"
  aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION
fi

echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

echo "Building Docker image..."
docker build --provenance false -t $ECR_REPOSITORY_NAME:$IMAGE_TAG .

echo "Tagging image with $IMAGE_TAG..."
docker tag $ECR_REPOSITORY_NAME:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY_NAME:$IMAGE_TAG

echo "Pushing image to ECR..."
docker push $ECR_REGISTRY/$ECR_REPOSITORY_NAME:$IMAGE_TAG

echo "Image pushed to ECR successfully!"
echo "Image: $ECR_REGISTRY/$ECR_REPOSITORY_NAME:$IMAGE_TAG"

END_TIME=$(date -R)

echo "Start time : ${START_TIME}"
echo "End time   : ${END_TIME}"