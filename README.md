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

## At Glance

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
- [aws/prod/stack.hcl](./aws/prod/stack.hcl)

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

```console
cd aws/prod/
terragrunt run-all init
terragrunt run-all apply
```

## To taint secrets

terragrunt taint random_password.mysql_smarter
terragrunt taint random_password.smarter_admin_password
terragrunt taint random_password.django_secret_key
terragrunt taint aws_iam_access_key.smtp_user
terragrunt apply

## Designed by for prompt engineers

Smarter provides design teams with a web console, and a convenient yaml manifest-based command-line interface for Windows, macOS, and Linux.

### Plugin Architecture

Smarter features a unique Plugin architecture for extending the knowledge domain of any LLM aimed at generative AI text completions. Smarter Plugins are uncharacteristically accurate, highly cost effective, and have been designed around the needs of enterprise customers. Its unique 'selector' feature gives prompt engineers a sosphisticated strategy for managing when and how LLM's can make use of Smarter Plugin's powerful data integrations, which include the following:

- **Static**: an easy to implement scheme in which your private data is simply included in yaml Plugin manifest file.
- **Sql**: a flexible parameterized manifest scheme that exposes query parameters to the LLM, enabling it to make precise requests via proxy to your corporate databases.
- **Rest Api**: Similarly, you can also configure proxy connections to your Rest Api's, enabling the LLM to make precise requests to an unlimited range of private data sources.

### Yaml Manifest Resource Management

Smarter brings a [yaml-based manifest file](./smarter/smarter/apps/plugin/data/sample-plugins/example-configuration.yaml) approach to prompt engineering, originally inspired by the [kubectl](https://kubernetes.io/docs/reference/kubectl/) command-line interface for [Kubernetes](https://kubernetes.io/).

### Smarter ChatBot APIs

The following collection of rest api url endpoints are implemented for all Smarter chatbot, where `example` is the name of the chatbot. The chatbot sandbox React app and configuration api are available via these two url's, both of which require authentication and are only available to user associated with the Account to which the chatbot belongs.

```console
https://platform.smarter.sh/chatapp/example/
https://platform.smarter.sh/chatapp/example/config/
```

Chatbot REST api's are available at several different styles of url endpoint depending on your needs. Deployed chatbots are accessible via either of these two styles. These url's do not require authentication (ie they are publicly accessible) unless the customer chooses to add an optional api key.

```console
https://example.3141-5926-5359.api.platform.smarter.sh/chatbot/
https://custom-domain.com/chatbot/
```

Additionally, there's a sandbox url which works with Django authentication and is accessible regardless of the chatbot's deployment status.

```console
https://platform.smarter.sh/api/v0/chatbots/1/chatbot/
```

### ChatBot API

Customers can deploy personalized ChatBots with a choice of domain. The default URL format is as follows.

- api: [user-defined-subdomain].####-####-####.api.smarter.sh/chatbot/
- webapp: [user-defined-subdomain].####-####-####.api.smarter.sh/chatbot/webapp/

Customers can optionally register a custom domain which typically can be verified and activated in around 4 hours.

## Developer Quickstart

See onboarding videos:

- [Querium Smarter Developer Onboarding #1](https://youtu.be/-hZEO9sMm1s)
- [Smarter Developer Workflow Tutorial](https://youtu.be/XolFLX1u9Kg)

Works with Linux, Windows and macOS environments.

1. Verify project requirements: [Python 3.11](https://www.python.org/), [NPM](https://www.npmjs.com/) [Docker](https://www.docker.com/products/docker-desktop/), and [Docker Compose](https://docs.docker.com/compose/install/). Docker will need around 1 vCPU, 2Gib memory, and 30Gib of storage space.

2. Run `make` and add your credentials to the newly created `.env` file in the root of the repo.

3. Initialize, build and run the application locally.

```console
git clone https://github.com/QueriumCorp/smarter.git
make                # scaffold a .env file in the root of the repo
                    #
                    # ****************************
                    # STOP HERE!
                    # ****************************
                    # Add your credentials to .env located in the project root folder.
                    #
make python-init    # initialize Python virtual environment used for code auto-completion and linting
make docker-init    # initialize dev environment, build & init docker.
make docker-build   # builds and configures all docker containers
make docker-run     # runs all docker containers and starts a local web server http://127.0.0.1:8000/
```

_AWS Infrastructure Engineers: you additionally will need [AWS Account](https://aws.amazon.com/free/) and [CLI](https://aws.amazon.com/cli/) access, and [Terraform](https://www.terraform.io/). Make sure to eview and edit the master [Terraform configuration](./api/terraform/terraform.tfvars) file._

## Documentation

Detailed documentation for each endpoint is available here: [Documentation](./doc/examples/)

## Support

Please report bugs to the [GitHub Issues Page](https://github.com/QueriumCorp/smarter/issues) for this project.

## Developers

Please see:

- the [Developer Setup Guide](./doc/CONTRIBUTING.md)
- and these [commit comment guidelines](./doc/SEMANTIC_VERSIONING.md) 😬😬😬 for managing CI rules for automated semantic releases.

You can also contact [Lawrence McDaniel](https://lawrencemcdaniel.com/contact) directly.
