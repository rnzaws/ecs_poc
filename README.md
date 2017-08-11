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

In order to additional better visibility into ECS, this project added several
[CloudWatch Event Rules](http://docs.aws.amazon.com/AmazonCloudWatch/latest/events/WhatIsCloudWatchEvents.html) that send matched
events to SNS topics.

For more information about the events ECS publishes, see the [Amazon ECS Event Stream for CloudWatch Events](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch_event_stream.html) documentation.

### Event Rules

The following are the event rules created in the CloudFormation templates:

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
      "SET_ARN_OF_ECS_CLUSTER"
    ],
    "status": [
      "INACTIVE"
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




