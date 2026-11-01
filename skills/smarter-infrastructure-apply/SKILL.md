---
name: smarter-infrastructure-apply
description: Use before running terraform, terragrunt, the aws cli, helm or kubectl in smarter-infrastructure, and when finishing any change, to hand it over for the user to plan and apply. Covers which commands are safe (fmt, validate with -backend=false, read-only kubectl), which are the user's alone (plan against live state, apply, destroy, import, state commands, run --all, helm and aws writes), the permission rules that block some of them, secrets in state and .env, checking live values read-only, and how to write the "not yet applied" hand-over - what the plan should show, replacements and destroys, imports, apply order and disruption.
---

# Planning and Applying smarter-infrastructure Changes

Your shell has the user's live AWS profile, kubeconfig and access to the
Terraform state bucket. A wrong command here changes production: it can
replace every node, delete a DNS zone or a bucket of backups, or leak a
password into the chat. So you change code, and the user changes
infrastructure.

## What you may run

| Command                                                           | Why it's safe                                                   |
| ----------------------------------------------------------------- | --------------------------------------------------------------- |
| `terraform fmt`                                                   | Rewrites whitespace in local files                              |
| `pre-commit run --files ...` (runs `terraform validate`)          | The hook runs `terraform init -backend=false`: no state, no AWS |
| `terraform init -backend=false && terraform validate` in a module | Same, by hand                                                   |
| `git grep`, `git log`, `git diff`, `git show`                     | Read-only                                                       |
| `skills/smarter-kubectl/scripts/kubectl.sh` reads                 | Read-only wrapper; see `smarter-kubectl`                        |

## What is the user's to run

Never run these. Write the exact command, with the directory to run it in, and
let the user run it.

- `terragrunt plan` / `terraform plan`. A plan only reads, but it reads live
  state with live credentials, and `terragrunt init` creates the state bucket
  and lock table when they're missing. Ask first; the user usually runs it.
- `apply`, `destroy`, `import`, `state rm|mv|pull|push`, `taint`, `untaint`,
  `force-unlock`, `refresh`, and anything with `run --all` (Terragrunt 1.x; the old `run-all` is gone).
- `make terraform-build` (runs `terraform apply`), `make release`,
  `make kubeconfig-update` (rewrites `~/.kube/config`).
- Any `aws` or `helm` command. `.claude/settings.local.json` denies both
  outright, along with `terraform apply|destroy`. A deny rule wins over any
  approval in chat: don't route around it with `bash -c`, an alias, `make`
  or a script. If you need a value from AWS or Helm (`helm list`,
  `helm get values`), give the user the command and ask for the output.
- `kubectl` writes (`apply`, `delete`, `edit`, `patch`, `scale`, `rollout
restart`, `annotate`, `label`, `cordon`, `drain`, `config use-context`).
  `kubectl exec` needs the user's OK each time.

## Secrets

- Never open, `cat`, `source` or edit `.env`. If you need to know whether a
  variable is set, ask.
- The state holds `random_password` results and Kubernetes secret data. Don't
  run `terraform output` (outputs can be sensitive), `state show`, or `state
pull`, and don't ask the user to paste them.
- The Makefile does `include .env` and `export`, so every `make` target runs
  with all of `.env` in its environment. Don't run make targets that print
  their environment or call AWS.

## Checking live values, read-only

Before changing a setting to "match what runs", look at what runs, and after
the user applies a change, confirm it worked. Use `smarter-kubectl`: its
wrapper passes `--context` and `-n` on every call, refuses anything that
writes, and refuses output that would print secret values.

## The hand-over

Every change ends unapplied. Your summary, and later the commit body, end with
a section that lets the user apply it safely. It says:

1. **Where to plan:** the user plans and applies from the environment they
   are working on, `aws/environments/<env>` (e.g. `aws/environments/prod`).
   Make the change reachable from there: a fix the user asked for goes in
   `aws/terraform/smarter`, not in a cluster stack under `aws/stack/`. Don't
   argue for another directory. Something that exists once per cluster
   (a cluster-wide add-on such as metrics-server) goes in `aws/terraform/smarter`
   behind a boolean variable, set true in that one environment's
   `terragrunt.hcl` (see `install_metrics_server`), because every environment
   on the cluster applies the same module. A plan that says "No changes" for
   a change you made means the change isn't reachable from that directory.
2. **What the plan should show:** each resource created, updated in place,
   **replaced** or **destroyed**, by its Terraform address. Call out every
   replacement and destroy, and anything with `prevent_destroy`. If the plan
   shows more than this, the user should stop and look.
3. **Imports first:** a resource that already exists in the account (made by
   hand, or by another stack) must be imported before apply, or apply fails or
   creates a duplicate. Give the exact command, e.g.
   `terragrunt import 'aws_ecr_pull_through_cache_rule.upstream["docker-hub"]' docker-hub`.
4. **Order:** which stack goes first (`vpc` → `kubernetes` → add-ons →
   environments), and which change in `../smarter` or `../smarter-deploy` must
   deploy before or after this one.
5. **Disruption:** what the apply interrupts and when to do it. Changing a
   node group's instance types, AMI or user data replaces the node group and
   drains every node; a renamed resource is destroyed and recreated; a DNS
   change takes TTL time to propagate.
6. **Clean-up by hand:** anything this repository doesn't manage that should
   now be removed (an IAM user, an old bucket prefix).
7. **How to tell it worked:** the read-only checks to run after the apply
   (`smarter-kubectl`), and offer to run them.

Work out the plan by reading the resource's provider docs for which arguments
force replacement (`ForceNew`), not by guessing. Say when you aren't sure.

Good examples are in `git log`: the bodies of the `fix(eks)`, `fix(ecr)`,
`fix(vpc)` and `fix(calico)` commits each end with this hand-over.
