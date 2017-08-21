#!/bin/bash

# Any code, applications, scripts, templates, proofs of concept,
# documentation and other items are provided for illustration purposes only.
#
# Copyright 2017 Amazon Web Services
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

APP_ENV="$1"

GITHUB_TOKEN="$2"

aws cloudformation create-stack --stack-name system-bootstrap-${APP_ENV} --template-body file://ops/cfn/bootstrap.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-bootstrap-${APP_ENV}

TEMPLATE_BUCKET=$(aws cloudformation describe-stacks --stack-name system-bootstrap-${APP_ENV} --query 'Stacks[0].Outputs[0].OutputValue' | tr -d '"')

aws cloudformation create-stack --stack-name system-vpc-${APP_ENV} --template-body file://ops/cfn/vpc.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-vpc-${APP_ENV}

aws cloudformation create-stack --stack-name system-ci-repository-${APP_ENV} --template-body file://ops/cfn/ci-repository.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-ci-repository-${APP_ENV}

aws cloudformation create-stack --stack-name system-bastion-${APP_ENV} --template-body file://ops/cfn/bastion.cfn.yml \
  --parameters ParameterKey=VpcStackName,ParameterValue=system-vpc-${APP_ENV}

aws cloudformation wait stack-create-complete --stack-name system-bastion-${APP_ENV}

aws cloudformation create-stack --stack-name app-alb-${APP_ENV} --template-body file://ops/cfn/load-balancer.cfn.yml \
  --parameters ParameterKey=VpcStackName,ParameterValue=system-vpc-${APP_ENV}

aws cloudformation wait stack-create-complete --stack-name app-alb-${APP_ENV}

aws cloudformation create-stack --stack-name app-ecs-${APP_ENV} --template-body file://ops/cfn/ecs-cluster.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=VpcStackName,ParameterValue=system-vpc-${APP_ENV} \
    ParameterKey=AlbStackName,ParameterValue=app-alb-${APP_ENV} \
    ParameterKey=BastionStackName,ParameterValue=system-bastion-${APP_ENV}

aws cloudformation wait stack-create-complete --stack-name app-ecs-${APP_ENV}

aws cloudformation create-stack --stack-name system-kinesis-${APP_ENV} --template-body file://ops/cfn/system-kinesis.cfn.yml --capabilities CAPABILITY_NAMED_IAM

aws cloudformation wait stack-create-complete --stack-name system-kinesis-${APP_ENV}

aws cloudformation create-stack --stack-name task-roles-${APP_ENV} --template-body file://ops/cfn/task-roles.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=SystemKinesisStackName,ParameterValue=system-kinesis-${APP_ENV}

aws cloudformation wait stack-create-complete --stack-name task-roles-${APP_ENV}

#
# Long repo names cause problems with declarative attribute names (max string lengths for some attributes in CFN templates).
# Keep your repo names somewhat short.
#
service_github_repos=(404 php-hello)

#
# The following services can be broken out to customize their parameters.
#
for service_github_repo in ${service_github_repos[*]}
do
  aws cloudformation create-stack --stack-name ecs-$service_github_repo-ci-${APP_ENV} --template-body file://ops/cfn/deployment-pipeline.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
      ParameterKey=EcsClusterStackName,ParameterValue=app-ecs-${APP_ENV} \
      ParameterKey=AlbStackName,ParameterValue=app-alb-${APP_ENV} \
      ParameterKey=VpcStackName,ParameterValue=system-vpc-${APP_ENV} \
      ParameterKey=GitHubSourceRepo,ParameterValue=$service_github_repo \
      ParameterKey=ServiceStackName,ParameterValue=ecs-$service_github_repo-service-${APP_ENV} \
      ParameterKey=TaskRoleStackName,ParameterValue=task-roles-${APP_ENV} \
      ParameterKey=SystemKinesisStackName,ParameterValue=system-kinesis-${APP_ENV} \
      ParameterKey=CiRepositoryStackName,ParameterValue=system-ci-repository-${APP_ENV} \
      ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
      ParameterKey=DesiredCount,ParameterValue=2
  aws cloudformation wait stack-create-complete --stack-name ecs-$service_github_repo-ci-${APP_ENV} &
done

wait
