---
name: smarter-code-quality
description: Use before finishing any change to smarter-infrastructure, to format and validate Terraform and Terragrunt files with the repository's pre-commit hooks (terraform fmt, terraform validate, codespell, the pre-commit-hooks checks, commitlint). Explains which tools are authoritative, why validate is safe to run, how to run the hooks on changed files under zsh, and the traps (.terraform folders, hcl files that terraform fmt skips).
---

# smarter-infrastructure Code Quality

`.pre-commit-config.yaml` is the authoritative standard. If a hook passes, the
code meets it. If a hook fails, fix the code. Never bypass a hook
(`--no-verify`, `SKIP=`) to make a change pass.

## What the hooks enforce

| Hook                                                                                      | Files           | Notes                                                                                   |
| ----------------------------------------------------------------------------------------- | --------------- | --------------------------------------------------------------------------------------- |
| `terraform-fmt`                                                                           | `aws/**/*.tf`   | Canonical formatting. Let it rewrite.                                                   |
| `terraform-validate`                                                                      | `aws/**/*.tf`   | Runs `terraform init -backend=false` then `validate` per module: no state, no AWS calls |
| `codespell`                                                                               | `aws/`          | Ignore list in `codespell.txt`; add real project words there                            |
| `trailing-whitespace`, `end-of-file-fixer`                                                | `aws/`          |                                                                                         |
| `check-yaml`, `check-json`, `check-merge-conflict`, `check-case-conflict`, symlink checks | all             |                                                                                         |
| `detect-aws-credentials`, `detect-private-key`                                            | all             | A hit means a secret is about to be committed. Remove it; never suppress.               |
| `commitlint`                                                                              | commit messages | `commit-msg` stage; see `smarter-git-commits`                                           |

tflint is not configured. Don't report its output as lint debt.

## How to run

From the repository root:

```console
source venv/bin/activate
git diff --name-only | xargs pre-commit run --files
git ls-files --others --exclude-standard | xargs pre-commit run --files   # new files
```

- Use `xargs`. Under zsh, `pre-commit run --files $FILES` passes one argument,
  and pre-commit checks nothing.
- Hooks that rewrite files (fmt, end-of-file-fixer) fail the first run and
  pass the second. Run twice, and read the diff of what they changed.
- `terraform-validate` downloads providers and modules into
  `aws/terraform/<module>/.terraform/` the first time, which takes a minute.
  Those folders are git-ignored and excluded from every hook.
- `make pre-commit-run` checks every tracked file, which is slower and skips
  untracked files.
- `make pre-commit-init` runs `pre-commit autoupdate`, which edits
  `.pre-commit-config.yaml`. That edit is a separate `build:` commit.
- If the venv is broken (its Python was uninstalled), `make pre-commit-init`
  rebuilds it.

## What the hooks don't cover

- **`.hcl` files.** `terraform fmt` only checks `.tf`. Keep Terragrunt files
  aligned by hand, in the style of their neighbours (`terragrunt hcl fmt`
  exists, but it reformats whole files; don't run it on files you didn't
  otherwise change).
- **Terragrunt wiring.** `validate` checks each module on its own, with no
  inputs. A misspelled input name in a stack's `inputs`, or a missing
  `mock_outputs` key, only shows up in `terragrunt plan`. Check every input you
  pass against the module's `variables.tf`, and every `dependency.*.outputs.*`
  you read against the other module's `outputs.tf` and the stack's
  `mock_outputs`.

## Principles

- Match the surrounding code: naming, tags, comment blocks.
- Don't reformat files you didn't otherwise change; it buries the real diff.
  If you must, say so in the commit body.
