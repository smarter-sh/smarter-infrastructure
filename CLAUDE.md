# CLAUDE.md

Guidance for Claude Code (and other coding agents) working in this repository.

smarter-infrastructure is the Terraform and Terragrunt code that builds the AWS
infrastructure under the [Smarter platform](https://github.com/smarter-sh/smarter)
(usually checked out beside this repository as `../smarter`): one VPC and one
EKS cluster shared by every environment, the cluster's add-ons (Calico,
Traefik, cert-manager, the descheduler, the cluster autoscaler, the ECR
pull-through cache), and, per environment (`alpha`, `prod`, ...), a namespace,
DNS zones, certificates, ingresses, S3 buckets, CloudFront, SES and secrets.
The Smarter application itself is deployed into that namespace by the Helm
chart in `../smarter/helm` and the deploy action in `../smarter-deploy`, not
from here.

Detailed know-how lives in the Agent Skills under `skills/` (symlinked to
`.claude/skills`). **Load `smarter-infrastructure-development` first for any
change.** This file holds only what applies to nearly every task.

## Hard rules

1. **Never run git write commands**, here or in any other repository.
   "Write a git commit" means print the command as text. See
   `smarter-git-commits`.
2. **Never change real infrastructure.** Your AWS profile, kubeconfig and
   Terraform state are the live ones. Never run `terragrunt`/`terraform`
   `apply`, `destroy`, `import`, `state rm|mv`, `taint`, `force-unlock`, or
   any `run --all` command, nor `make terraform-build`. Never run a write with
   the `aws` cli, `helm` or `kubectl`. Hand the user the command instead. See
   `smarter-infrastructure-apply` for what you may run and how to hand a
   change over.
3. **Every change ends as "not yet applied".** Your summary, and the commit
   body, say what `terragrunt plan` should show (creates, in-place updates,
   **replacements and destroys**), which stack to apply first, any `import`
   that must come first, and what a replacement disrupts (a node group
   replacement drains every node).
4. **The pre-commit hooks are the lint standard** (terraform fmt, terraform
   validate, codespell, the pre-commit-hooks checks, commitlint). Run them on
   the files you changed. See `smarter-code-quality`.
5. **This repository is public.** No AWS account ids, IAM user names or ARNs,
   access keys, passwords, private hostnames or customer data in code,
   comments, docs, skills or commit messages. Real values come from `.env`
   through `aws/global.hcl`.
6. **Don't read or print secrets.** Never open, edit or `cat` `.env`. The
   Terraform state holds generated passwords (`random_password`) and
   Kubernetes secrets, so don't run `terraform output`, `state show` or
   `state pull`. The Makefile `include`s and `export`s `.env`, so any `make`
   target runs with every secret in its environment.
7. **`get_env()` appears only in `aws/global.hcl`.** Everything else reads
   `global.hcl` and `stack.hcl` locals.

## Repository map

| Path                      | Contents                                                                                   |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `aws/global.hcl`          | Every value read from `.env`, the derived names (`cluster_name`, ...), and the global tags |
| `aws/terragrunt.hcl`      | Root config: generated AWS provider, S3 remote state, `inputs` merged into every stack     |
| `aws/stack/stack.hcl`     | Cluster-wide settings: Kubernetes version, node group sizes and instance types             |
| `aws/stack/<module>/`     | Terragrunt stacks for the shared cluster: `vpc`, `kubernetes`, `kubernetes_*` add-ons      |
| `aws/environments/<env>/` | One Terragrunt stack per Smarter environment, all using `aws/terraform/smarter`            |
| `aws/terraform/<module>/` | The Terraform modules that the stacks point `source` at                                    |
| `aws/test/`               | Stale: its `source` names a folder that doesn't exist. Don't copy it.                      |
| `doc/`                    | Contributor docs (Terraform getting started, 12-factor, coding practice)                   |
| `skills/`                 | Agent Skills for working on this repository                                                |

Apply order: `vpc` → `kubernetes` → `kubernetes_ingress`,
`kubernetes_cert_manager`, `kubernetes_descheduler` → `environments/<env>`.

When you search the code, use `git grep`, or exclude `.terraform/` and
`.terragrunt-cache/`: they hold vendored copies of every upstream module and
bury the real hits.

## Common commands

```bash
# Lint and validate changed files (validate runs terraform init -backend=false: no state, no AWS)
source venv/bin/activate && git diff --name-only | xargs pre-commit run --files

# Format one module
terraform fmt -recursive aws/terraform/<module>

# Read-only look at the live cluster (see smarter-kubectl)
skills/smarter-kubectl/scripts/kubectl.sh <context> <namespace> get pods
```

## Conventions

- **Pattern first.** Find the nearest existing resource of the same kind
  (a Helm release, an IRSA role, a network policy, a Route53 record) and copy
  its structure, naming, tags and comments.
- **New inputs flow down the hierarchy:** `.env` → `global.hcl` (or
  `stack.hcl` for cluster settings) → the stack's `inputs` → the module's
  `variables.tf`, with a `description`.
- **A stack that reads another stack's output** declares a `dependency` with
  `mock_outputs` for `init`, `validate` and `destroy`, so validation works
  before the other stack exists.
- **Pin versions.** Helm charts get an explicit `version`, upstream modules a
  `~>` constraint, so an upgrade is a deliberate change.
- **Images come through the ECR pull-through cache** (prefixes `docker-hub`,
  `quay`, `k8s`, `ecr-public`, from the `kubernetes` stack's
  `ecr_pull_through_cache` output), not straight from Docker Hub.
- **Comments say why.** This code is read by people learning AWS and
  Kubernetes; explain non-obvious settings and their cost, as the existing
  comments do.
- **DNS:** the root domain's A record points to the marketing site, not the
  platform load balancer. Never copy it onto platform or API hosts.
- **Companion changes.** A new output the platform needs (a bucket, a secret,
  a role) usually needs a change in `../smarter/helm` or `../smarter-deploy`
  too. Say so in your summary; read their `CLAUDE.md` before touching them.

## Definition of done

- The change follows an existing pattern in this repository.
- `pre-commit` passes on the changed files, including `terraform validate`.
- Nothing was applied, and your summary says what the plan should show, the
  apply order, any imports, and what is disrupted.
- Docs (`README.md`, `doc/`) describe user-visible changes, such as a new
  `.env` variable.
- Your summary says what changed, what you verified, and what you skipped.
