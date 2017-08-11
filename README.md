# ECS POC

This is a simple POC to showcase deploying a basic [Amazon EC2 Container Service (ECS)](https://aws.amazon.com/ecs/) cluster.

Any code, applications, scripts, templates, proofs of concept,
documentation and other items are provided for illustration purposes only.

Copyright 2017 Amazon Web Services

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---

## Overview

The goal of this POC is to provide an example of an automated ECS stack that can be deployed N times
per AWS account and provide additional visibility (via events sent to SNS topics) into various ECS
operations. Additionally, the POC incorporates [AWS CodePipline](https://aws.amazon.com/codepipeline/) to
handle building and deploying to the ECS cluster.

As with all demo/open source code, please review and test extensively to verify
that all of your use cases/requirements are covered.

The core of the ECS cluster stack and the CodePipeline deployment components was based on the following
[Amazon Web Services - Labs](https://github.com/awslabs/) projects:

* [ecs-refarch-cloudformation](https://github.com/awslabs/ecs-refarch-cloudformation)
* [ecs-refarch-continuous-deployment](https://github.com/awslabs/ecs-refarch-continuous-deployment)

Both of these projects are excellent starting points for ECS (hence why we based our work on these projects),
but we were looking for additional best practices and examples. The main extension points in this POC are:

* Event notifications via [Amazon Simple Notification Service (SNS)](https://aws.amazon.com/sns/)
* ECS cluster host and task logging to [Amazon CloudWatch Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)
* Some control for service developers of their configuration/deployment
* Task specific [IAM Roles](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) for containers

Instead of having multiple reference architectures, we will probably be issuing some pull requests, once everything in this
project is flushed out.

---

## Amazon CloudWatch Events

To provide additional visibility into ECS, this project added several
[CloudWatch Event Rules](http://docs.aws.amazon.com/AmazonCloudWatch/latest/events/WhatIsCloudWatchEvents.html) that send matched
events to SNS topics.

For more information about the events ECS publishes, see the [Amazon ECS Event Stream for CloudWatch Events](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch_event_stream.html) documentation.

### Event Rules

The rules below are created in the CloudFormation templates. ECS is a highly resilient service that is capable
of recovering from failures, but visibility is key to any [well-architected](https://aws.amazon.com/architecture/well-architected/) system.

#### Inactive Host
The following rule sends an event to a topic if the ECS instance has an INACTIVE state. You can test this
event by terminating an EC2 instance in your test ECS cluster. If your ECS cluster auto scales down, this
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
container on the ECS instance or by adding code that triggers a process exit inside your Docker image.

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
In this POC, new releases are done via [AWS CodePipeline](https://aws.amazon.com/codepipeline/). If your CloudFormation
template contains errors or there are system problems, this rule will match. For information on the errors this rule attempts
to match, see the [CloudFormation Common Errors](http://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/CommonErrors.html) documentation.

TODO: How do we test this event?

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
The ECS container instance firehose. This is a feed of all state changes in the container instance.

The firehose is greate for collecting metrics and verifying state, but is noisy and should be analyzed
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




---

## Network

The VPC setup and bastion server CloudFormation templates are based on the
[AWS Startup Kit Templates](https://github.com/awslabs/startup-kit-templates). Please [review the README](https://github.com/awslabs/startup-kit-templates/blob/master/README.md)
for a more detailed explanation of the network and bastion server. In this example, the bastion server
security group is not IP restricted (allows 0.0.0.0/0), but you can pass in a SshFrom parameter to the
basion.cfm.yml stack to restrict access to specific IP addresses. We highly recommend isolating access to your
bastion server.

---




