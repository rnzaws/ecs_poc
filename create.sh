#!/bin/bash

APP_ENV="$1"

GITHUB_TOKEN="$2"

aws cloudformation create-stack --stack-name system-bootstrap-$APP_ENV --template-body file://ops/cfn/bootstrap.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-bootstrap-$APP_ENV

BOOTSTRAP_BUCKET=$(aws cloudformation describe-stacks --stack-name system-bootstrap-$APP_ENV --query 'Stacks[0].Outputs[0].OutputValue' | tr -d '"')

aws cloudformation create-stack --stack-name system-vpc-$APP_ENV --template-body file://ops/cfn/vpc.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-vpc-$APP_ENV

aws cloudformation create-stack --stack-name system-ci-repository-$APP_ENV --template-body file://ops/cfn/ci-repository.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-ci-repository-$APP_ENV


aws cloudformation create-stack --stack-name system-bastion-$APP_ENV --template-body file://ops/cfn/bastion.cfn.yml \
  --parameters ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV

aws cloudformation wait stack-create-complete --stack-name system-bastion-$APP_ENV

aws cloudformation create-stack --stack-name app-alb-$APP_ENV --template-body file://ops/cfn/load-balancer.cfn.yml \
  --parameters ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV

aws cloudformation wait stack-create-complete --stack-name app-alb-$APP_ENV

aws cloudformation create-stack --stack-name app-ecs-$APP_ENV --template-body file://ops/cfn/ecs-cluster.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV \
    ParameterKey=AlbStackName,ParameterValue=app-alb-$APP_ENV \
    ParameterKey=BastionStackName,ParameterValue=system-bastion-$APP_ENV

aws cloudformation wait stack-create-complete --stack-name app-ecs-$APP_ENV

#
# Create a CodePipeline for each service. Each app/service must have a buildspec.yml and ops/cfn/service.cfn.yml file in the repository.
#

aws cloudformation create-stack --stack-name not-found-ci-$APP_ENV --template-body file://ops/cfn/deployment-pipeline.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=EcsClusterStackName,ParameterValue=app-ecs-$APP_ENV \
    ParameterKey=AlbStackName,ParameterValue=app-alb-$APP_ENV \
    ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV \
    ParameterKey=GitHubSourceRepo,ParameterValue=404 \
    ParameterKey=ServiceStackName,ParameterValue=not-found-service-$APP_ENV \
    ParameterKey=CiRepositoryStackName,ParameterValue=system-ci-repository-$APP_ENV \
    ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
    ParameterKey=TaskName,ParameterValue=not-found-$APP_ENV \
    ParameterKey=DesiredCount,ParameterValue=2

aws cloudformation wait stack-create-complete --stack-name not-found-ci-$APP_ENV

aws cloudformation create-stack --stack-name sample-app-ci-$APP_ENV --template-body file://ops/cfn/deployment-pipeline.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=EcsClusterStackName,ParameterValue=app-ecs-$APP_ENV \
    ParameterKey=AlbStackName,ParameterValue=app-alb-$APP_ENV \
    ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV \
    ParameterKey=GitHubSourceRepo,ParameterValue=ecs-demo-php-simple-app \
    ParameterKey=ServiceStackName,ParameterValue=sample-app-service-$APP_ENV \
    ParameterKey=CiRepositoryStackName,ParameterValue=system-ci-repository-$APP_ENV \
    ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
    ParameterKey=TaskName,ParameterValue=sample-app-$APP_ENV \
    ParameterKey=DesiredCount,ParameterValue=2

aws cloudformation wait stack-create-complete --stack-name sample-app-ci-$APP_ENV


