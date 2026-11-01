---
name: smarter-git-commits
description: Use whenever the user asks you to "write a git commit" (or a commit message, or the git add) in the smarter-infrastructure repo. Covers the never-execute rule, authorship, the multiple -m command format, conventional-commit types and scopes for Terraform changes, the 72-character header limit, and the body, which must end with the "not yet applied" hand-over.
---

# smarter-infrastructure Git Commits

## The rule: write, never execute

"Write a git commit", in any wording or tone, means **output the command as
text**. Never run `git commit`, `git add`, `git reset`, `git restore`,
`git push`, `git tag`, `git stash`, or any other git command that writes. The
user stages, commits and pushes. Read-only git (`status`, `diff`, `log`) is
fine. Don't volunteer commit messages; write one when asked.

## Authorship

You are the author; Lawrence McDaniel is the co-author.

```console
git commit --author="Claude <noreply@anthropic.com>" \
  -m "<type>(<scope>): <subject>" \
  -m "<body paragraph>" \
  -m "<area heading>:" \
  -m "- <change and why>
- <change and why>" \
  -m "Not yet applied. <the hand-over>" \
  -m "Co-authored-by: Lawrence McDaniel <lpm0073@gmail.com>"
```

- One `-m` per paragraph; a bullet list is one `-m` with real newlines.
- No heredoc, no `-F`, no `git add` in the same block. When asked for the
  `git add`, write it as a separate block that lists each path.
- Avoid backticks, `$` and `!` inside the double quotes: the shell expands
  them, and in zsh `!` aborts the command with `event not found`. Terraform
  addresses with quotes, like `upstream["docker-hub"]`, need `\"` escapes.
- Never write a CI skip instruction (`[skip ci]` and its variants) anywhere in
  the message, not even to describe one. GitHub reads the whole message.

## Subject line

`<type>(<scope>): <subject>`, checked by commitlint and read by
semantic-release (`release.config.js`).

- **type:** `feat`, `fix`, `docs`, `refactor`, `perf`, `style`, `build`,
  `ci`, `chore`, `test`, `revert`. `feat` (a minor release) is for something
  truly new, such as a new module or a new cluster add-on. Fixing, tightening
  or resizing what exists is `fix`. Formatting and hook changes are `chore`.
  `chore(release)` belongs to semantic-release.
- **scope:** the area, in lower case: `vpc`, `eks`, `ecr`, `calico`,
  `security`, `ingress`, `cert-manager`, `descheduler`, `s3`, `dns`, `ses`,
  `smarter` (the environment module). Omit it for repository-wide changes.
- **subject:** imperative, lower case, no trailing period.
- **72 characters at most**, header included. Measure, don't count by eye:
  `printf %s "fix(eks): drop 4 GiB c-family instance types" | wc -c`

## Body

Write for a reviewer with no context, a year from now.

- Start with the problem: what was wrong, and how it showed up (an eviction,
  a rate limit, a port open to the internet).
- Then area by area: a heading paragraph naming the files
  (`Kubernetes module (aws/terraform/kubernetes/main.tf, outputs.tf):`),
  then one bullet per change, with the reason for each non-obvious choice and
  the alternatives rejected. Name resources by their Terraform address.
- Include cost when it changes (NAT traffic, storage, instance hours).
- Say how you verified it: pre-commit and `terraform validate`, and any
  read-only checks of live values (`kubectl get ...`). Never claim a plan or
  apply you didn't see.
- **End with the hand-over** from `smarter-infrastructure-apply`: "Not yet
  applied." then where to plan, what the plan should show (call out
  replacements and destroys), imports to run first, apply order, companion
  changes in other repositories, and disruption.
- No account ids, ARNs, user names or host names: this repository is public.

## Before writing

1. Run `git status` and `git diff --stat` (and `git diff` where unclear), so
   the message describes the working tree, not your memory of it.
2. Measure the header with `wc -c`.
3. Start your reply with a one-line `Written for:` note naming the audience.

`git log -5` shows real examples in this format (`fix(ecr)`, `fix(calico)`).
