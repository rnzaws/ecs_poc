# ECS POC

This is a simple POC to showcase deploying a basic ECS cluster.

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

The goal of this POC is to provide a fully automated stack that can be deployed N times
per AWS account and provide additional visibility (via events sent to SNS topics) into various ECS
operations. As with all demo open source code, please review and test extensively to verify
that all of your use cases are covered.

---

## Network

The VPC setup and bastion server CloudFormation templates are based on the
[AWS Startup Kit Templates](https://github.com/awslabs/startup-kit-templates). Please [review the README](https://github.com/awslabs/startup-kit-templates/blob/master/README.md)
file for a more detailed explanation of the network and bastion server. In this example, the bastion server
security group is not IP restricted (allows 0.0.0.0/0), but you can pass in a SshFrom parameter to the 
basion.cfm.yml stack to restrict access to specific IP addresses. We highly recommend isolating access to your
bastion server.


