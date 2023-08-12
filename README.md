# Verified to Work in Release
This example repository shows how to use a [CloudFormation template](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-sample-templates.html) with Release. The CloudFormation template creates a simple [DynamoDB table](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/sample-templates-services-us-west-2.html) and then tears it down when the environment is deleted.

> :warning: **WARNING** This template creates an Amazon DynamoDB table. You will be billed for the AWS resources used if you create a stack from this template.

## How it Works
### Service Account
By default, Release EKS clusters are built with an OIDC provider that allows Release to provide an EKS identity (a service account) access to an IAM role with an attached policy. The policy needs to have permissions to deploy resources, as well as run CloudFormation changes in the account. The example policy in this case is stored [here](cf-policy.json). The role that is created needs a trust relationship to the OIDC provider, an example is located [here](cf-trust-policy.json). Things get a bit "hand wavy" in how to create these roles, there are basically three options:

1. Create the role manually. This is suitable if you own the account and are only setting it up once. It might also be suitable if you are willing to ask the account owner to do this for you once.
2. Use terraform. This is the preferred method that is [documented](https://github.com/releasehub-samples/service-account-cloud-role-aws) and supported by Release. It has the benefit of leveraging roles, policies, and defaults that we have bootstrapped for Release customer clusters.
3. Some other method using IAAC, like [Pulumi](https://www.pulumi.com/blog/eks-oidc/), yet another CloudFormation template, [eksctl](https://eksctl.io/usage/iamserviceaccounts/), etc.
<details>

<summary>The role is specified here</summary>

```yaml
service_accounts:
- name: cf-role
  cloud_role: arn:aws:iam::${cloud_account_id}:role/myDynamoDBRole
```
</details>

### CloudFormation Deploy and Teardown
The [Release Application Template](.release/application_template.yaml) holds all the details of how this app would be deployed. The CloudFormation template is built and torn down by a set of jobs and workflows.
<details>

<summary>For example, the deploy job looks like this:</summary>

```yaml
services:
- name: cf-template
  has_repo: true
  image: awesome-release/cloudformation_dynamodb/cf_template
  build:
    context: "."
jobs:
- name: cf-template-deploy
  service_account_name: cf-role
  from_services: cf-template
  command:
  - "/bin/sh"
  - "-c"
  - aws cloudformation deploy --template-file dynamodb.yaml --stack-name dynamodb-${RELEASE_ENV_ID} --parameter-overrides TableName=${TABLE_NAME}-${RELEASE_ENV_ID} HashKeyElementName=${PRIMARY_KEYNAME}
```
</details><details>

<summary>And the teardown looks like this:</summary>

```yaml
- name: cf-template-destroy
  service_account_name: cf-role
  from_services: cf-template
  command:
  - "/bin/sh"
  - "-c"
  - aws cloudformation delete-stack --stack-name dynamodb-${RELEASE_ENV_ID}
```
</details><details>

<summary>The workflow looks like this:</summary>

```yaml
workflows:
- name: setup
  parallelize:
  - step: step-0
    tasks:
    - jobs.cf-template-deploy
- name: patch
  parallelize:
  - step: step-0
    tasks:
    - jobs.cf-template-deploy
- name: teardown
  parallelize:
  - step: remove-db
    tasks:
    - jobs.cf-template-destroy
  - step: remove-environment
    tasks:
    - release.remove_environment
```
</details>

### Environment Variables
The [environment variables](.release/environment_variables.yaml) used to populate the table parameters are used in the application template to pass variables into the cloudformation template.

- Each stack name gets a name based on the ID of the enviroment
- Each table name gets a unique prefix from the `TABLE_NAME` environment variable.
- The primary key is based on the `PRIMARY_KEYNAME` environment variable.

### Deploy Examples
<details>

<summary>The output from an initial deployment would yield:</summary>

```
[2023-08-11 16:14:02] RUNNING JOB : ar-cf-dynamodb-cf-template-deploy
[2023-08-11 16:14:02] Waiting up to 1200 seconds for deployment to complete
[2023-08-11 16:14:05] ar-cf-dynamodb-cf-template-deploy-blw69/ar-cf-dynamodb-cf-template-deploy: Waiting for changeset to be created..
[2023-08-11 16:14:11] ar-cf-dynamodb-cf-template-deploy-blw69/ar-cf-dynamodb-cf-template-deploy: Waiting for stack create/update to complete
[2023-08-11 16:14:40] ar-cf-dynamodb-cf-template-deploy-blw69/ar-cf-dynamodb-cf-template-deploy: Successfully created/updated stack - dynamodb-ted1234
[2023-08-11 16:14:44] Waiting up to 600 seconds for pod to become ready
[2023-08-11 16:14:45] Task [1234567] finished successfully as part of Task Chain [1234567]!
```
</details><details>

<summary>The output from a subsequent update to the template would yield:</summary>

```
[2023-08-11 16:15:54] RUNNING JOB : ar-cf-dynamodb-cf-template-deploy
[2023-08-11 16:15:54] Waiting up to 1200 seconds for deployment to complete
[2023-08-11 16:15:57] ar-cf-dynamodb-cf-template-deploy-xbh7s/ar-cf-dynamodb-cf-template-deploy: Waiting for changeset to be created..
[2023-08-11 16:15:57] ar-cf-dynamodb-cf-template-deploy-xbh7s/ar-cf-dynamodb-cf-template-deploy:
[2023-08-11 16:15:57] ar-cf-dynamodb-cf-template-deploy-xbh7s/ar-cf-dynamodb-cf-template-deploy: No changes to deploy. Stack dynamodb-ted1234 is up to date
[2023-08-11 16:16:01] Waiting up to 600 seconds for pod to become ready
[2023-08-11 16:16:02] Task [1234576] finished successfully as part of Task Chain [1234576]!
```
</details><details>

<summary>The teardown is successful and the full history from the console log looks like this:</summary>

|Timestamp|Logical ID|Status|Status reason|Timestamp|Logical ID|Status|Status reason|
|:--------|:---------|:-----|:------------|:--------|:---------|:-----|:-----------|
|2023-08-11 16:55:05 UTC-0700|dynamodb-ted1234|DELETE_COMPLETE|-|2023-08-11 16:55:05 UTC-0700|myDynamoDBTable|DELETE_COMPLETE|-|
|2023-08-11 16:54:53 UTC-0700|myDynamoDBTable|DELETE_IN_PROGRESS|-|2023-08-11 16:54:51 UTC-0700|dynamodb-ted1234|DELETE_IN_PROGRESS|User Initiated|
|2023-08-11 16:14:26 UTC-0700|dynamodb-ted1234|CREATE_COMPLETE|-|2023-08-11 16:14:25 UTC-0700|myDynamoDBTable|CREATE_COMPLETE|-|
|2023-08-11 16:14:14 UTC-0700|myDynamoDBTable|CREATE_IN_PROGRESS|Resource creation Initiated|2023-08-11 16:14:13 UTC-0700|myDynamoDBTable|CREATE_IN_PROGRESS|-|
|2023-08-11 16:14:10 UTC-0700|dynamodb-ted1234|CREATE_IN_PROGRESS|User Initiated|2023-08-11 16:14:04 UTC-0700|dynamodb-ted1234|REVIEW_IN_PROGRESS|User Initiated|
</details>
