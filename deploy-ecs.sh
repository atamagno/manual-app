#!/bin/bash
START_TIME=$(date -R)
GLOBAL_OVERRIDES=$1

set -e  # Exit on any error

export PERMISSIONS_BOUNDARY="none"
######## Get script parameters separated by ; and set them as global variables #########
OLD_IFS=$IFS # backup original separator (new line usually) so we can revert it as other code might rely on it
export IFS=";"
ALLOWED_KEYS=("AWS_REGION" "ACCOUNT_ID" "ENVIRONMENT_NAME" "IMAGE_TAG")
for keyVal in $GLOBAL_OVERRIDES; do
  KEY=${keyVal%=*}
  VALUE=${keyVal#*=}
  # Check if KEY is in the whitelist
  for allowed in "${ALLOWED_KEYS[@]}"; do
    if [[ "$KEY" == "$allowed" ]]; then
      export ${KEY}="${VALUE}"
      break
    fi
  done
done
export IFS=$OLD_IFS # put separator back to normal

if [ -z "${AWS_REGION}" ]
then
  echo "AWS_REGION environment variable is not set. Aborting."
  exit 1
fi

if [ -z "${ACCOUNT_ID}" ]
then
  export ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
fi

export GIT_HASH=`git rev-parse --short HEAD`
if [ -z "${GIT_HASH}" ]; then
  export GIT_HASH="unknown"
  echo "Using default git hash of unknown"
fi

export GIT_BRANCH=`git symbolic-ref --short HEAD`
if [ -z "${GIT_BRANCH}" ]; then
  export GIT_BRANCH="hash"
  echo "Using default git branch of hash"
fi

# Configuration
APP_NAME="manual-app"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
PREFIX="${APP_NAME}-${ENVIRONMENT_NAME}-"
POSTFIX="-${ACCOUNT_ID}-${AWS_REGION}"
ECR_REPOSITORY_NAME="${PREFIX}repository${POSTFIX}"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_URI="$ECR_REGISTRY/$ECR_REPOSITORY_NAME:$IMAGE_TAG"

ECS_CFN_TEMPLATE="cfn/ecs.yml"
ECS_STACK="${PREFIX}ecs-stack"
CFN_TAGS="Application=${APP_NAME} Environment=${ENVIRONMENT_NAME}"

echo "Deploying ECS stack $ECS_STACK to region $AWS_REGION with image $IMAGE_URI"

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $AWS_REGION --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $AWS_REGION --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

echo "Using VPC $VPC_ID and subnets $SUBNET_IDS"

aws cloudformation deploy \
  --stack-name $ECS_STACK \
  --template-file $ECS_CFN_TEMPLATE \
  --parameter-overrides \
      pAppName=$APP_NAME \
      pEnvironmentName=$ENVIRONMENT_NAME \
      pImageUri=$IMAGE_URI \
      pVpcId=$VPC_ID \
      pSubnetIds=$SUBNET_IDS \
      pGitBranch=$GIT_BRANCH \
      pGitHash=$GIT_HASH \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --tags $CFN_TAGS \
  --region $AWS_REGION

END_TIME=$(date -R)

echo "Start time : ${START_TIME}"
echo "End time   : ${END_TIME}"