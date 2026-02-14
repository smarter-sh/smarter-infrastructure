# The Smarter Project - AWS Infrastructure

[![Amazon AWS](https://a11ybadges.com/badge?logo=amazonaws)](https://aws.amazon.com/)
[![Terraform](https://a11ybadges.com/badge?logo=terraform)](https://www.terraform.io/)<br>
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326ce5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![hack.d Lawrence McDaniel](https://img.shields.io/badge/hack.d-Lawrence%20McDaniel-orange.svg)](https://lawrencemcdaniel.com)

This repo contains Terraform source code for creating the AWS cloud
infrastructure that supports the Smarter Api and web platform.

Smarter is a declarative extensible AI authoring and resource management system.
It is used as an instructional tool at [University of British Columbia](https://www.ubc.ca/)
for teaching cloud computing at scale, and generative AI prompt engineering
techniques including advanced use of LLM tool calling involving secure
integrations to remote data sources like Sql databases and remote Apis.

## At a Glance

Creates a standalone AWS EKS (Elastic Kubernetes Service) Kubernetes cluster,
and installs supporting Helm packages for Traefik and Cert-Manager, for
implementing the necessary cloud support behind traditional TLS-terminated
ingresses.

This infrastructure is designed to host multiple environments on the same
Kubernetes cluster (ie alpha, beta, next, prod). Additional envionment-specific
AWS resources that this project fully manages include:

- IAM (Identity Access Management) Roles, Users, and Policies
- Cloudfront Content Delivery network
- Elastic Container Registry for private Smarter app repos (optional)
- Route53 DNS records
- S3 storage bucket
- Simple Email Service configuration
- Certificate Manager

## Configuration

Review the following files. Adjust as necessary.

- [.env](./.env.example)
- [aws/global.hcl](./aws/global.hcl)
- [aws/terragrunt.hcl](./aws/terragrunt.hcl)
- [aws/stack/stack.hcl](./aws/stack/stack.hcl)

### Environment Variables

**NOTE**: running `make` from the terminal window will automatically
initialize a `.env` file for you. Otherwise, create a .env file in the root of the repo with the values described
below.

**IMPORTANT**: You'll need to run `set -a; source .env; set +a` in order for
these environment variables to become visible inside of running Terraform code.
Afterwards, values of the form `get_env("AWS_REGION", "ca-central-1")` can see the environment variables that you have set in your .env file.

```console
IAM_ADMIN_USER_ARN=arn:aws:iam::123456789012:user/username

AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
AWS_PROFILE=SET-ME-PLEASE

ROOT_DOMAIN=example.com
MYSQL_ROOT_USERNAME=root
MYSQL_ROOT_PASSWORD=SET-ME-PLEASE
PLATFORM_SUBDOMAIN=platform
COST_CODE=SET-ME-PLEASE
UNIQUE_ID=SET-ME-PLEASE

DOCKER_USERNAME=docker_username
DOCKER_PAT=docker_personal_access_token
```

`IAM_ADMIN_USER_ARN`: (Required) The AWS existing IAM user that will own the
EKS Kubernetes cluster. Specifically, in configMap.aws-auth, an entry will
be created in mapUsers that adds this IAM user to the
Kubernetes system:master group.

`AWS_REGION`: (Optional) Defaults to 'us-east-1'. The AWS data center from
which all resources will be created. Certain exceptions apply due to
technical/service constraints, where noted. For example, AWS Cloudfront
only accepts ssl certificates from us-east-1, IAM resources and Route53 are
globally managed, etcetera.

`AWS_ACCOUNT_ID`: (Required) your 12-digit AWS Account number, found in the
top-right corner of the AWS web console after having authenticated.

`AWS_PROFILE`: (Optional) but strongly recommended as an alternative to persisting
your AWS key-pair to this .env file. If it exists, the aws cli will automatically
cross-reference your AWS_PROFILE name to the assigned AWS Keypair. This is the
sole AWS credential for the entire project. **Note:** if you do not provide a
AWS_PROFILE then you must provide AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY.
See [Configuration and credential file settings in the AWS CLI](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html)

`ROOT_DOMAIN`: (Required) example: 'ai.my-university.edu'.
Importantly, Your ROOT_DOMAIN **MUST** be managed by AWS Route53 DNS service.
These Terraform modules as well as the Smarter Python-Django codebase itself
expect to find an AWS Route53 HostedZone for this domain. Technically, this is
the 'base' domain in that Smarter in point of fact, allows subdomains.

`MYSQL_ROOT_USERNAME` & `MYSQL_ROOT_PASSWORD`: (Optional) the MySql root
credentials for the existing MySql backing service for the entire Smarter
installation. This pair, to the extent that you are using existing, shared
Mysql infrastructure such as AWS RDS (Relational Database Service), are used
for creating the MySql database, and the actual MySql
user and password for your installation, on a per-environment basis. That is, each of
alpha, beta, next, prod has its own credentials, generated from the root
credentials and persisted to Kubernetes Secrets.

`PLATFORM_SUBDOMAIN`: (Optional) Defaults to 'platform'. This value becomes the base
subdomain for environmnents, and also the middle values of Kubernetes
environment namespaces. Examples: the domain 'platform.smarter.sh', and the
namespace 'smarter-platform-prod'. Changing the value post-deployment is
technically feasible, though **highly** disruptive, so choose this value
carefully. For environments hosted at 'smarter.sh' this is the client code.
Example: 'ubc.smarter.sh', and 'smarter-ubc-prod'.

`COST_CODE`: (Optional) Defaults to 'smarter'. Generally this should be the
same value as `PLATFORM_SUBDOMAIN`. This become a global AWS tag that is added
to every AWS resource of the installation.

`UNIQUE_ID`: (Optional) Defaults to 'YYYYMMDDHHMM' of the current datetime.
More generally, this is a string value that is suffixed to AWS resources, as
necessary, to ensure global uniqueness throughout the AWS account. Best
practice is to use an alpha-numeric value that carries some meaning for the
installation. For example, a datestamp like 'eval' or 'live'. This value
becomes a global tag that is added to all AWS resources.

`DOCKER_USERNAME` & `DOCKER_PAT`: (Required). These are propagated to EC2
instances when they are created. These credentials are used for authenticating
to DockerHub Api. Authenticating to DockerHub exponentially increases the
number of requests that you can make before throttling is triggered. Moreover,
this project also sets up a Docker caching mechanism via AWS Elastic Container
Registry which additionally significantly reduce Api requests to Dockerhub. This
not only significantly speeds up deployments, but also significantly reduces the
risk of DockerHub throttling your Api requests.

## Usage

Build the Kubernetes Cluster

```console
cd aws/stack/
terragrunt run-all init
terragrunt run-all apply
```

Build a Smarter Environment

```console
cd aws/environments/prod
terragrunt run-all init
terragrunt run-all apply
```

## AWS Resource Tags

These Terraform modules create several tags that are applied globally to all
AWS resources. These are useful for tracking, reporting and cost accounting
purposes. Tags include, but are not limited to the following:

```console
contact=Lawrence McDaniel - https://lawrencemcdaniel.com/
cost_code=smarter
create_kms_key=FALSE
Name=smarter
smarter=TRUE
smarter/cluster_name=smarter-platform-us-202602121853
smarter/mysql_host=mysql.service.localhost
smarter/platform_name=smarter
smarter/platform_region=us
smarter/platform_subdomain=platform
smarter/root_domain=ai.my-university.edu
smarter/unique_id=202602121853
terraform=TRUE
```

## Documentation

See: [https://docs.smarter.sh/](https://docs.smarter.sh/)

## Support

Please report bugs to the [GitHub Issues Page](https://github.com/QueriumCorp/smarter/issues) for this project.

You can also contact [Lawrence McDaniel](https://lawrencemcdaniel.com/contact) directly.
