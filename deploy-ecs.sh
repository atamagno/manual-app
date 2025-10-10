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

getStackOutputs () {
  stackOutputs=$(aws cloudformation describe-stacks --region ${AWS_REGION} --stack-name ${1} | jq -r '.Stacks[0].Outputs | map({key:.OutputKey,value:.OutputValue})| .[] | "Stack_" + .key + "=" + .value' | tr -d '\r')
  if [[ -z "$stackOutputs" ]]; then
    if [ "${2}" = "noexit" ]; then
      return
    fi
      echo "Failed to retrieve stack outputs from stack (${1})"
      echo "Aborting pipeline"
      exit 255
  else
    echo "Successfully retrieved values from ${1}"
    for key in ${stackOutputs}; do
      export ${key}
    done
  fi
}

# Configuration
APP_NAME="manual-app"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
PREFIX="${APP_NAME}-${ENVIRONMENT_NAME}-"
POSTFIX="-${ACCOUNT_ID}-${AWS_REGION}"
ECR_REPOSITORY_NAME="${PREFIX}repository${POSTFIX}"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${GIT_HASH:-latest}" # TODO: add a condition to use latest if specified
IMAGE_URI="$ECR_REGISTRY/$ECR_REPOSITORY_NAME:$IMAGE_TAG"
VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"

VPC_CFN_TEMPLATE="cfn/vpc.yml"
VPC_STACK="${PREFIX}vpc-stack"
ECS_CFN_TEMPLATE="cfn/ecs.yml"
ECS_STACK="${PREFIX}ecs-stack"
ELB_STACK="${PREFIX}elb-stack"
ELB_CFN_TEMPLATE="cfn/elb.yml"
CFN_TAGS="Application=${APP_NAME} Environment=${ENVIRONMENT_NAME}"

echo "Deploying VPC stack $VPC_STACK"

aws cloudformation deploy \
  --stack-name $VPC_STACK \
  --template-file $VPC_CFN_TEMPLATE \
  --parameter-overrides \
      pAppName=$APP_NAME \
      pEnvironmentName=$ENVIRONMENT_NAME \
      pVpcCidr=$VPC_CIDR \
      pGitBranch=$GIT_BRANCH \
      pGitHash=$GIT_HASH \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --tags $CFN_TAGS \
  --region $AWS_REGION

getStackOutputs $VPC_STACK

VPC_ID=$Stack_VPC
PUBLIC_SUBNET_IDS=$Stack_PublicSubnets
PRIVATE_SUBNET_IDS=$Stack_PrivateSubnets

echo "Using VPC $VPC_ID and subnets $PUBLIC_SUBNET_IDS"

echo "Deploying ELB stack $ELB_STACK"

aws cloudformation deploy \
  --stack-name $ELB_STACK \
  --template-file $ELB_CFN_TEMPLATE \
  --parameter-overrides \
      pAppName=$APP_NAME \
      pEnvironmentName=$ENVIRONMENT_NAME \
      pVpcId=$VPC_ID \
      pPublicSubnetIds=$PUBLIC_SUBNET_IDS \
      pGitBranch=$GIT_BRANCH \
      pGitHash=$GIT_HASH \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --tags $CFN_TAGS \
  --region $AWS_REGION

getStackOutputs $ELB_STACK

ELB_SECURITY_GROUP_ID=$Stack_ELBSecurityGroupId
ELB_TARGET_GROUP_A_ARN=$Stack_ELBTargetGroupAArn

echo "Deploying ECS stack $ECS_STACK"

aws cloudformation deploy \
  --stack-name $ECS_STACK \
  --template-file $ECS_CFN_TEMPLATE \
  --parameter-overrides \
      pAppName=$APP_NAME \
      pEnvironmentName=$ENVIRONMENT_NAME \
      pImageUri=$IMAGE_URI \
      pVpcId=$VPC_ID \
      pPrivateSubnetIds=$PRIVATE_SUBNET_IDS \
      pELBSecurityGroupId=$ELB_SECURITY_GROUP_ID \
      pTargetGroupArn=$ELB_TARGET_GROUP_A_ARN \
      pGitBranch=$GIT_BRANCH \
      pGitHash=$GIT_HASH \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --tags $CFN_TAGS \
  --region $AWS_REGION

END_TIME=$(date -R)

echo "Start time : ${START_TIME}"
echo "End time   : ${END_TIME}"