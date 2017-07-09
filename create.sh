#!/bin/bash

APP_ENV="$1"

aws cloudformation create-stack --stack-name system-bootstrap-$APP_ENV --template-body file://ops/cfn/bootstrap.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-bootstrap-$APP_ENV

BOOTSTRAP_BUCKET=$(aws cloudformation describe-stacks --stack-name system-bootstrap-$APP_ENV --query 'Stacks[0].Outputs[0].OutputValue' | tr -d '"')

aws cloudformation create-stack --stack-name system-vpc-$APP_ENV --template-body file://ops/cfn/vpc.cfn.yml

aws cloudformation wait stack-create-complete --stack-name system-vpc-$APP_ENV

aws cloudformation create-stack --stack-name app-alb-$APP_ENV --template-body file://ops/cfn/load-balancer.cfn.yml \
  --parameters ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV

aws cloudformation wait stack-create-complete --stack-name app-alb-$APP_ENV

aws cloudformation create-stack --stack-name app-ecs-$APP_ENV --template-body file://ops/cfn/ecs-cluster.cfn.yml --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=VpcStackName,ParameterValue=system-vpc-$APP_ENV ParameterKey=AlbStackName,ParameterValue=app-alb-$APP_ENV

aws cloudformation wait stack-create-complete --stack-name app-ecs-$APP_ENV









