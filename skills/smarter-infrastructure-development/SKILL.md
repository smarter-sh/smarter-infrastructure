---
name: smarter-infrastructure-development
description: Start here for any change to the smarter-infrastructure repository (Terraform modules under aws/terraform, Terragrunt stacks under aws/stack and aws/environments, global.hcl, stack.hcl, Helm releases of cluster add-ons, IAM, Route53, S3, ECR, EKS node groups, network policies). Gives the layout of the Terragrunt hierarchy, how inputs and dependencies flow, the apply order, the conventions to copy, and an index of the narrower skills.
---

# smarter-infrastructure Development

This repository builds the AWS infrastructure for the Smarter platform with
Terraform modules, wired together and configured by Terragrunt. One VPC and
one EKS cluster are shared by every environment. Each environment (`alpha`,
`prod`, ...) adds a namespace and its own AWS resources on top.

## The Terragrunt hierarchy

```text
.env                               values for this installation (never read it)
└── aws/global.hcl                 get_env() calls, derived names, global tags
    └── aws/terragrunt.hcl         provider + S3 remote state for every stack
        ├── aws/stack/stack.hcl    cluster settings: k8s version, node group
        │   ├── aws/stack/vpc                     -> aws/terraform/vpc
        │   ├── aws/stack/kubernetes              -> aws/terraform/kubernetes
        │   ├── aws/stack/kubernetes_ingress      -> aws/terraform/kubernetes_ingress
        │   ├── aws/stack/kubernetes_cert_manager -> aws/terraform/kubernetes_cert_manager
        │   └── aws/stack/kubernetes_descheduler  -> aws/terraform/kubernetes_descheduler
        └── aws/environments/<env>                -> aws/terraform/smarter
```

- A stack's `terragrunt.hcl` reads `global.hcl` and `stack.hcl` with
  `read_terragrunt_config(find_in_parent_folders(...))`, `include`s the root
  config, points `terraform.source` at a module, and passes `inputs`.
- `aws/terragrunt.hcl` generates `provider.tf` (with `allowed_account_ids`,
  so a stack can't run against the wrong account) and `backend.tf` (state in
  `<account>-terraform-tfstate-<platform>`, keyed by the stack's path). Don't
  hand-write either file in a module.
- **`get_env()` belongs only in `global.hcl`.** A new installation setting is
  added to `.env.example`, read once in `global.hcl` with a safe default, and
  documented in `README.md`'s "Environment Variables".
- Cluster-wide sizing (instance types, node counts, Kubernetes version) lives
  in `stack.hcl`, with a comment that explains the choice.

## What each module owns

| Module                    | Owns                                                                                                                                                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `vpc`                     | The VPC and subnets (terraform-aws-modules/vpc), NAT gateway, S3 gateway endpoint, services subdomain                                                                                                        |
| `kubernetes`              | EKS (terraform-aws-modules/eks), node group, add-ons, IRSA roles, cluster autoscaler, Calico and the network policies (`network_policy.tf`), gp3 storage class, ECR pull-through cache                       |
| `kubernetes_ingress`      | Traefik and its CRDs, and the DNS records that point at its load balancer                                                                                                                                    |
| `kubernetes_cert_manager` | cert-manager and its IRSA role for Route53 DNS-01 challenges                                                                                                                                                 |
| `kubernetes_descheduler`  | The descheduler                                                                                                                                                                                              |
| `smarter`                 | One environment: namespace, Route53 zones and records, ACM, CloudFront, S3 (public assets, private backups, private data exports), ECR repo, SES and its SMTP user, Kubernetes secrets, ingresses, issuers, Traefik middlewares |

## Dependencies and apply order

Stacks pass outputs to each other through `dependency` blocks: `kubernetes`
reads `vpc`; the three add-on stacks read `vpc` and `kubernetes` (for
`ecr_pull_through_cache`, among others). Environments read the cluster through
data sources (`aws_eks_cluster`, the Traefik service), so they come last.

Apply order: `vpc` → `kubernetes` → the add-on stacks → `environments/<env>`.

When you add a `dependency`, give it `mock_outputs` for every output you read,
and `mock_outputs_allowed_terraform_commands = ["init", "validate", "destroy"]`,
as the existing stacks do. Without them, `validate` fails on a fresh checkout
and the stacks can't be destroyed in reverse order.

## Pattern-first workflow

1. Identify the kind of change: a Helm release, an IRSA role, an IAM policy,
   a network policy, a DNS record, a bucket, a new input, a node group setting.
2. Find the nearest existing example with `git grep` (not `grep -r`: the
   `.terraform/` and `.terragrunt-cache/` folders hold vendored upstream code).
3. Copy its structure: file placement, naming (`<platform>-<subdomain>-<env>`),
   `tags = local.tags` / `var.tags`, comment block style, and how it gets its
   inputs.
4. Make the change, run the hooks (`smarter-code-quality`), and write the
   hand-over (`smarter-infrastructure-apply`).

## Conventions

- **Pin versions.** A `helm_release` gets an explicit `version`; a module from
  the registry gets a `~>` constraint. An unpinned chart installs whatever was
  published that day, so a new environment silently differs from the old ones.
- **Images through the ECR pull-through cache.** Use the prefix map from the
  `kubernetes` stack's `ecr_pull_through_cache` output (`docker-hub`, `quay`,
  `k8s`, `ecr-public`). Pulling straight from Docker Hub hits its rate limits
  and pays NAT gateway charges.
- **Least privilege.** Scope IAM actions to the resources they need (see the
  pull-through policy in `kubernetes/main.tf`). Prefer IRSA roles to node
  role permissions.
- **Network policies are default-deny.** A new workload that must talk to
  MariaDB, Redis or the internet needs a matching rule in
  `kubernetes/network_policy.tf`. An empty `namespace_selector` matches every
  namespace in the cluster, not just this one.
- **Node instance types need 8 GiB or more** (see the comment in
  `stack.hcl`). Changing `instance_types` usually replaces the node group.
- **Explain why in comments**, including cost: the readers are often learning
  AWS. Remove comments that have become false; a stale description (as
  `enable_enhanced_security`'s once was) misleads the next change.
- **No account ids or user ARNs in code.** The repository is public. A value
  that differs per installation belongs in `.env` via `global.hcl`.
- **DNS:** the root domain's A record belongs to the marketing site. Platform
  and API hosts point at the Traefik load balancer.

## Other repositories

The Smarter Helm chart (`../smarter/helm`) and the deploy action
(`../smarter-deploy`) consume what this repository creates: the namespace, the
secrets, the buckets, the ECR repository. A new or renamed output usually needs
a companion change there. Read that repository's `CLAUDE.md` first, follow its
rules, and say in your summary which change must be deployed first.

## Which skill to load

| Task                                                              | Skill                          |
| ----------------------------------------------------------------- | ------------------------------ |
| Running terraform, terragrunt, aws, helm or kubectl; handing over | `smarter-infrastructure-apply` |
| Reading the live cluster with kubectl                             | `smarter-kubectl`              |
| Lint, format, validate, pre-commit                                | `smarter-code-quality`         |
| Writing a commit message                                          | `smarter-git-commits`          |

## Definition of done

- The change follows an existing pattern in this repository.
- The pre-commit hooks pass on the changed files.
- Nothing was applied, and the hand-over says what the plan should show.
- `README.md` documents any new `.env` variable.
- Your summary says what changed, what you verified, and what you skipped.
