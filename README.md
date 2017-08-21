# Amazon EC2 Container Service POC

This is a simple POC to showcase deploying a basic [Amazon EC2 Container Service (ECS)](https://aws.amazon.com/ecs/) cluster.

Any code, applications, scripts, templates, proofs of concept,
documentation and other items are provided for illustration purposes only.

Copyright 2017 Amazon Web Services

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---

## Table of Contents
1. [Overview](#overview)
2. [Sample Services](#sample-services)
3. [Amazon CloudWatch Events](#amazon-cloudwatch-events)
4. [Amazon CloudWatch Logs](#amazon-cloudwatch-logs)
5. [Task Level Permissions](#task-level-permissions)
6. [CloudFormation Templates](#cloudformation-templates)

---

## Overview

"Everything fails, all the time." *-- [Werner Vogels](https://en.wikipedia.org/wiki/Werner_Vogels)*

The goal of this POC is to provide an example of an automated ECS stack that can be deployed N times
per AWS account and provide additional visibility into ECS operations and state. Added visibility is
obtained by routing additional log information and observing events published by ECS. Additionally, the POC
incorporates [AWS CodePipline](https://aws.amazon.com/codepipeline/) to handle building and deploying to the
ECS cluster.

As with all demo/open source code, please review and test extensively to verify
that all of your use cases/requirements are covered.

The core of the ECS cluster stack and the CodePipeline deployment components was based on the following
[Amazon Web Services - Labs](https://github.com/awslabs/) projects:

* [ecs-refarch-cloudformation](https://github.com/awslabs/ecs-refarch-cloudformation)
* [ecs-refarch-continuous-deployment](https://github.com/awslabs/ecs-refarch-continuous-deployment)

Both of these projects are excellent starting points for ECS (hence why we based our work on these projects),
but we were looking for additional best practices and examples. The main extension points in this POC are:

* Event notifications via [Amazon Simple Notification Service (SNS)](https://aws.amazon.com/sns/)
* ECS cluster [Container Instance](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_instances.html)
and [ECS Task](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html) logging
to [Amazon CloudWatch Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)
* Some control for service developers of their configuration/deployment
* Task specific [IAM Roles](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) for containers

Instead of having multiple reference architectures, we will probably be issuing some pull requests, once everything in this
project is flushed out.

---

## Sample Services

This POC builds and deploys the test services below to the ECS cluster. Changes to the test service can be made and once
committed to the GitHub branch the CodePipeline is listening on (master by default), a new build/deploy will be triggered.

| Service          | GitHub                              |
| ---------------- | ----------------------------------- |
| 404 Not Found    | https://github.com/rnzsgh/404       |
| PHP Hello        | https://github.com/rnzsgh/php-hello |

---

## Amazon CloudWatch Events

To provide additional visibility into ECS, this project added several
[CloudWatch Event Rules](http://docs.aws.amazon.com/AmazonCloudWatch/latest/events/WhatIsCloudWatchEvents.html) that send matched
events to SNS topics.

For more information about the events ECS publishes, see the [Amazon ECS Event Stream for CloudWatch Events](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch_event_stream.html) documentation.

### Event Rules

The rules below are created in the CloudFormation templates. ECS is a highly resilient service that is capable
of recovering from failures, but visibility is key to any [well-architected](https://aws.amazon.com/architecture/well-architected/) system.

All of the rules created by the POC CloudFormation templates send their matched events to specific SNS topics that are also created
by the stack.


#### Inactive Container Instance

The following rule sends an event to a topic if the ECS Container Instance has an INACTIVE state. You can test this
event by terminating an EC2 Container Instance in your test ECS cluster. If your ECS cluster auto scales down, this
rule will also match.

```json
{
  "detail-type": [
    "ECS Container Instance State Change"
  ],
  "source": [
    "aws.ecs"
  ],
  "detail": {
    "clusterArn": [
      "SET_ARN_OF_YOUR_ECS_CLUSTER"
    ],
    "status": [
      "INACTIVE"
    ]
  }
}
```

#### Essential Stopped Task
If one of your containers fails this event is triggered. You can test this by manually stopping the Docker
container on the ECS Container Instance or by adding code that triggers a process exit inside your Docker image.

The rule will not match if you deploy a new release and your old containers are stopped.

```json
{
  "detail-type": [
    "ECS Task State Change"
  ],
  "source": [
    "aws.ecs"
  ],
  "detail": {
    "taskDefinitionArn": [
      "ARN_OF_YOUR_TASK_DEFINITION"
    ],
    "stoppedReason": [
      "Essential container in task exited"
    ],
    "lastStatus": [
      "STOPPED"
    ],
    "desiredStatus": [
      "STOPPED"
    ]
  }
}
```

#### Basic CloudFormation Deploy Error
In this POC, new releases are trigged, built and deployed via [AWS CodePipeline](https://aws.amazon.com/codepipeline/). If your CloudFormation
template contains errors or there are system problems, this rule will match. For information on the errors this rule attempts
to match, see the [CloudFormation Common Errors](http://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/CommonErrors.html) documentation.

TODO: How do we test this event? Does this match syntax errors?

Currently, CodePipeline does not support notifications, so it is still possible for the deployment to fail without an event.
To solve this problem, you can create a scheduled Lambda function to monitor your CodePipeline and CloudFormation stacks.

```json
{
  "source": [
    "aws.cloudformation"
  ],
  "detail": {
    "errorCode": [
      "AccessDeniedException",
      "IncompleteSignature",
      "InternalFailure",
      "InvalidAction",
      "InvalidClientTokenId",
      "InvalidParameterCombination",
      "InvalidParameterValue",
      "InvalidQueryParameter",
      "MalformedQueryString",
      "MissingAction",
      "MissingAuthenticationToken",
      "MissingParameter",
      "OptInRequired",
      "RequestExpired",
      "ServiceUnavailable",
      "ThrottlingException",
      "ValidationError"
    ],
    "userIdentity": {
      "sessionContext": {
        "sessionIssuer": {
          "arn": [
            "YOUR_CODE_PIPELINE_SERVICE_ROLE_ARN"
          ]
        }
      },
      "invokedBy": [
        "codepipeline.amazonaws.com"
      ]
    }
  }
}
```

#### Container Instance State Change
The ECS Container Instance firehose. This is a feed of all state changes in the Container Instance.

The firehose is great for collecting metrics and verifying state, but is noisy and should be analyzed
programmatically.


```json
{
  "detail-type": [
    "ECS Container Instance State Change"
  ],
  "source": [
    "aws.ecs"
  ],
  "detail": {
    "clusterArn": [
      "SET_ARN_OF_YOUR_ECS_CLUSTER"
    ]
  }
}
```

#### Task State Change
The ECS task firehose. This is a feed of all state changes for a task.

The firehose is greate for collecting metrics and verifying state, but is noisy and should be analyzed
programmatically.


```json
{
  "detail-type": [
    "ECS Task State Change"
  ],
  "source": [
    "aws.ecs"
  ],
  "detail": {
    "clusterArn": [
      "SET_ARN_OF_YOUR_ECS_CLUSTER"
    ]
  }
}
```

---

## Amazon CloudWatch Logs

Logging is a basic tenet of software development. If something fails unexpectedly, and the application does not
know how to handle this failure, it is a common practice to log (one way or another) the failure. In addition to
application logging, operating system logging is also important. Both [soft errors](https://en.wikipedia.org/wiki/Soft_error)
and bugs do occur, so providing visibility via logging is important.

In this POC, we log everything to [Amazon CloudWatch Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html).

### Container Instance Operating System Logging

The [Amazon CloudWatch Logs Agent](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/QuickStartEC2Instance.html) is installed
and configured on the Container Instance as a part of the [Launch Configuration](http://docs.aws.amazon.com/autoscaling/latest/userguide/LaunchConfiguration.html)
definition. The ECS documentation provides additional information on the [service specific log files](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/logs.html).

The following Container Instance files are monitored and sent to CloudWatch Logs:


| Log File                    | Purpose |
| --------------------------- | --------- |
| /var/log/dmesg              | Log information for device drivers (most useful during boot) |
| /var/log/messages           | Global system messages including cron, daemon, kern, auth, etc. |
| /var/log/docker             | Log information for the Docker daemon |
| /var/log/ecs/ecs-agent.log  | The ECS agent log (also includes Docker events) |
| /var/log/ecs/ecs-init.log   | Log information for the container service |
| /var/log/ecs/audit.log      | Audit information about credentials provided to tasks via IAM roles |

### Task Logging

A best practice for logging in containers or applications is to simply configure log libraries to write to
[STDOUT](https://en.wikipedia.org/wiki/Standard_streams#Standard_output_.28stdout.29). By allowing an application
write directly to STDOUT, you decouple your log storage from your application, which creates more freedom
in routing/processing.

With ECS, you can [configure your tasks to use the awslogs log driver](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_awslogs.html)
to centralize your logging in CloudWatch Logs.

---

## Task Level Permissions

In line with [granting least privilege](http://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege) access to
applications/services, ECS supports assigning [IAM roles to tasks](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html).
With IAM Roles for tasks, you can grant the container access only to the services that it requires.

---

## CloudFormation Templates

### Bootstrap
The bootstrap CFN template creates a default bucket that can be used for deploying stacks.

[templates/bootstrap.cfn.yml](templates/bootstrap.cfn.yml)

### Container Registry
The CI stack creates a [Amazon EC2 Container Registry](https://aws.amazon.com/ecr/) (ECR), which is a fully-managed Docker container registry.
ECR supports [Docker Manifest V2, Schema 2](https://docs.docker.com/registry/spec/manifest-v2-2/).
ECR integrates with IAM, so you can have a central set of credentials/permissions/security
for accessing your Docker images. Usually, one registry per account is enough.

[templates/ci-repository.cfn.yml](templates/ci-repository.cfn.yml)

### Network

The VPC setup CloudFormation template is based on the
[AWS Startup Kit](https://github.com/awslabs/startup-kit-templates).
Please [review the README](https://github.com/awslabs/startup-kit-templates/blob/master/README.md)
for a detailed explanation of the network configuration.

[templates/vpc.cfn.yml](templates/vpc.cfn.yml)

### Bastion Host

Per best practices, the ECS Container Instances all have [private IP addresses](https://en.wikipedia.org/wiki/Private_network),
so if you need to access an instance via SSH, you will need to proxy through a [bastion host](https://en.wikipedia.org/wiki/Bastion_host).
The CloudFormation template for the bastion host is also based on the [AWS Startup Kit](https://github.com/awslabs/startup-kit-templates).

You should not need to SSH to your ECS servers because important Container Instance and Task logs are being routed to CloudWatch Logs.

In this example, the bastion host security group is not IP restricted (allows 0.0.0.0/0), but you can
pass in a SshFrom parameter to the bastion.cfm.yml stack to restrict access to specific IP addresses.
We *highly* recommend restricting access to your bastion host by IP address. Also, it is a best practice
to [stop the bastion server](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Stop_Start.html) if you do not need access
to any internal servers.

[templates/bastion.cfn.yml](templates/bastion.cfn.yml)

A common [anti-pattern](https://en.wikipedia.org/wiki/Anti-pattern)  with bastion hosts is to place SSH keys on
them that allow access to the destination servers. In this model, you connect to the bastion host and then issue
another command to SSH to the destination server using the local key. This practice is bad because if your bastion
server is compromised, you have left the keys to the vault on the kitchen table. The recommended approach for bastion
host access is to use the SSH ProxyCommand to route additional hops through the bastion host. The command below
provides an example of how this is accomplished.

```bash
ssh -i ~/.ssh/KEY_FOR_ECS_INSTANCE -o \
 "ProxyCommand ssh -W %h:%p -i ~/.ssh/KEY_FOR_BASTION_HOST ec2-user@BASTION_HOST" \
 ec2-user@ECS_INSTANCE_HOST
```

You can also place the ProxyCommand configuration in your local [SSH config file](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Proxies_and_Jump_Hosts).

### Load Balancer

The [Application Load Balancer](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) (ALB) is a
[Layer 7](https://en.wikipedia.org/wiki/OSI_model#Layer_7:_Application_Layer) HTTP/HTTPS router that supports both host and
path-based rules. With ALB, you can have a variety of services in ECS, with different endpoints running on the same load balancer.

[templates/load-balancer.cfn.yml](templates/load-balancer.cfn.yml)

### Amazon EC2 Container Service Cluster

Creates the ECS cluster with a simple [Auto Scaling Group](http://docs.aws.amazon.com/autoscaling/latest/userguide/AutoScalingGroup.html) that allows
the ECS Container Instances to expand/contract based on load. Additionally, the ECS Container Instances are configured (i.e, ECS, CLoudWatch Logs Agent) in the
[Launch Configuration](http://docs.aws.amazon.com/autoscaling/latest/userguide/LaunchConfiguration.html). You can add additional
Container Instance configuration in the Launch Configuration (e.g., install [OSSEC](https://ossec.github.io/)) file and
then [cycle out your existing Container Instances](https://aws.amazon.com/blogs/compute/how-to-automate-container-instance-draining-in-amazon-ecs/).

[templates/ecs-cluster.cfn.yml](templates/ecs-cluster.cfn.yml)

### Kinesis

In this POC, the sample [404 service](https://github.com/rnzsgh/404) writes events to an
[Amazon Kinesis Stream](https://aws.amazon.com/kinesis/streams/) for downstream processing.
The purpose of this example is to showcase [IAM Roles for Tasks](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html).

[templates/system-kinesis.cfn.yml](templates/system-kinesis.cfn.yml)

### Task Roles

Create the [IAM Roles for Tasks](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html). An ECS Task Role should only
grant access to the services/resources they require.

[templates/task-roles.cfn.yml](templates/task-roles.cfn.yml)

### Continuous Integration and Deployment

The core of the [CI/CD](https://en.wikipedia.org/wiki/CI/CD) process in this POC is the [AWS CodePipeline](https://aws.amazon.com/codepipeline/).
For each service deployed to the ECS cluster, you should create at least one CloudFormation CI/CD stack. The pipeline created for each service is triggered by a commit
to the [GitHub](github.com/) branch that is configured with. Once the pipeline is triggered, an [AWS CodeBuild](https://aws.amazon.com/codebuild/)
stage is executed and the process runs the logic defined in the [build spec file](http://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html).
Once the service is built, and the container is pushed to ECR, the service is deployed using the CloudFormation template located in the [templatess/service](templates/service) directory.

[templates/deployment-pipeline.cfn.yml](templates/deployment-pipeline.cfn.yml)


