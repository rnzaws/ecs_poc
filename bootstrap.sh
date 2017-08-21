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

GITHUB_TOKEN="$2"

#
# Upsert the bootstrap template and then package and upload the CFN templates.
#

aws cloudformation describe-stacks --stack-name system-bootstrap-${APP_ENV} >> /dev/null 2>&1
stack_describe=$?

stack_command="create"

# If the value is zero, then the stack exists.
if [ "$stack_describe" == "0" ]; then
  stack_command="update"
fi

bootstrap_output=$((aws cloudformation ${stack_command}-stack --stack-name system-bootstrap-${APP_ENV} --template-body file://templates/bootstrap.cfn.yml) 2>&1)
bootstrap_exit_code=$?

if [ "$bootstrap_exit_code" != "0" ]; then
  if [[ $bootstrap_output != *"No updates are to be performed"* ]]; then
     echo $bootstrap_output
     exit $bootstrap_exit_code
  fi
else
  aws cloudformation wait stack-${stack_command}-complete --stack-name system-bootstrap-${APP_ENV}
fi

TEMPLATE_BUCKET=$(aws cloudformation describe-stacks --stack-name system-bootstrap-${APP_ENV} --output text --query 'Stacks[0].Outputs[?OutputKey==`TemplateBucketName`].OutputValue' | tr -d '"')

zip -q ecs-poc-templates.zip ecs-poc-cfn.yml templates/* templates/service/*

aws s3 cp ecs-poc-templates.zip "s3://${TEMPLATE_BUCKET}" --quiet --exclude '*.swp'

aws s3 cp ecs-poc.cfn.yml "s3://${TEMPLATE_BUCKET}" --quiet --exclude '*.swp'

aws s3 cp --recursive templates/ "s3://${TEMPLATE_BUCKET}/templates" --quiet --exclude '*.swp'

aws s3 cp --recursive templates/service "s3://${TEMPLATE_BUCKET}/templates/service" --quiet --exclude '*.swp'

aws cloudformation update-stack --stack-name ecs-poc-${APP_ENV} --template-url https://s3.amazonaws.com/${TEMPLATE_BUCKET}/ecs-poc.cfn.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=TemplateBucket,ParameterValue=${TEMPLATE_BUCKET} \
    ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN




