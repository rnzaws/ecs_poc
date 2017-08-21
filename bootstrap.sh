#!/bin/bash

# Any code, applications, scripts, templates, proofs of concept,
# documentation and other items are provided for illustration purposes only.
#
# Copyright 2017 Amazon Web Services
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.  # You may obtain a copy of the License at #
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

APP_ENV="$1"

GITHUB_USER="$2"

GITHUB_TOKEN="$3"

SSH_KEY_NAME="$4"


aws cloudformation create-stack --stack-name system-bootstrap-${APP_ENV} --template-body file://templates/bootstrap.cfn.yml
aws cloudformation wait stack-create-complete --stack-name system-bootstrap-${APP_ENV}

TEMPLATE_BUCKET=$(aws cloudformation describe-stacks --stack-name system-bootstrap-${APP_ENV} --output text --query 'Stacks[0].Outputs[?OutputKey==`TemplateBucketName`].OutputValue' | tr -d '"')

zip -q ecs-poc-templates.zip ecs-poc-cfn.yml templates/* templates/service/*
aws s3 cp ecs-poc-templates.zip "s3://${TEMPLATE_BUCKET}" --quiet --exclude '*.swp'
aws s3 cp ecs-poc.cfn.yml "s3://${TEMPLATE_BUCKET}" --quiet --exclude '*.swp'
aws s3 cp --recursive templates/ "s3://${TEMPLATE_BUCKET}/templates" --quiet --exclude '*.swp'
aws s3 cp --recursive templates/service "s3://${TEMPLATE_BUCKET}/templates/service" --quiet --exclude '*.swp'

aws cloudformation create-stack --stack-name ecs-poc-${APP_ENV} --template-url https://s3.amazonaws.com/${TEMPLATE_BUCKET}/ecs-poc.cfn.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=TemplateBucket,ParameterValue=${TEMPLATE_BUCKET} \
    ParameterKey=GitHubUser,ParameterValue=$GITHUB_USER \
    ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
    ParameterKey=InstanceKeyName,ParameterValue=$SSH_KEY_NAME

