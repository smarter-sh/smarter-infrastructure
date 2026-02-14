# The Smarter Project - AWS Infrastructure

[![Amazon AWS](https://a11ybadges.com/badge?logo=amazonaws)](https://aws.amazon.com/)
[![Terraform](https://a11ybadges.com/badge?logo=terraform)](https://www.terraform.io/)<br>
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

- [aws/global.hcl](./aws/global.hcl)
- [aws/terragrunt.hcl](./aws/terragrunt.hcl)
- [aws/stack/stack.hcl](./aws/stack/stack.hcl)

### .env

Create a .env file in the root of the repo with the following values.
You'll need to `source .env` in order for Terraform to see these values.


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


## Usage

You should first review aws/global.hcl and aws/terragrunt.hcl, and edit as needed. Values in aws/global.hcl of the form `get_env("AWS_REGION", "ca-central-1")`
can be overridden with environment variables. Example: `export AWS_REGION=us-east-1`. You can also optional create a .env file with multiple values, and then use the single command, `set -a; source .env; set +a`.

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

## Documentation

Please see:[https://docs.smarter.sh/](https://docs.smarter.sh/)

## Support

Please report bugs to the [GitHub Issues Page](https://github.com/QueriumCorp/smarter/issues) for this project.

You can also contact [Lawrence McDaniel](https://lawrencemcdaniel.com/contact) directly.
