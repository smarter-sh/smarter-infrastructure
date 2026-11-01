# smarter-infrastructure Agent Skills

This folder holds the [Agent Skills](https://agentskills.io/specification) for
working on this repository with an AI coding agent such as Claude Code. They
follow the same format and conventions as the skills in
[smarter-sh/smarter](https://github.com/smarter-sh/smarter/tree/main/skills),
whose README explains Agent Skills in more depth.

A skill is a folder with a `SKILL.md` (YAML frontmatter with `name` and
`description`, then instructions) and sometimes a `scripts/` or `references/`
folder. An agent sees only each skill's name and description until a task
matches it, then reads the body.

## What's here

| Skill                                | Use it when                                                                             |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| `smarter-infrastructure-development` | You're making any change. Start here.                                                   |
| `smarter-infrastructure-apply`       | You're about to run terraform, terragrunt, aws, helm or kubectl, or hand over a change. |
| `smarter-kubectl`                    | You're reading the live cluster: add-on pods, nodes, events, Calico, APIServices.       |
| `smarter-code-quality`               | You're about to finish a change and need to run the pre-commit hooks.                   |
| `smarter-git-commits`                | You've been asked to write a commit message.                                            |

The bundled script `smarter-kubectl/scripts/kubectl.sh` runs one read-only
kubectl command against a named context and namespace, and refuses anything
that writes or that would print a secret's values. You can run it yourself from the repository root.

## How Claude Code finds them

Claude Code reads project skills from `.claude/skills/`. This repository links
the two with a committed symlink, `.claude/skills -> ../skills`:

```bash
mkdir -p .claude && ln -s ../skills .claude/skills
```

On a checkout without symlink support (some Windows setups), the link breaks
and Claude Code silently stops seeing the skills.

## Why they matter here

Your shell has live AWS credentials, a kubeconfig for the real EKS cluster and
access to the Terraform state. One `terragrunt apply` can replace every node,
delete a DNS zone, or destroy a bucket of backups. The skills keep an agent to
changing code, validating it without touching state, and handing the user a
plan to review and apply.

**Review a change to this folder as carefully as a change to CI.** A skill is
instructions that an agent follows without asking. Watch for new scripts,
network calls, and anything that weakens the rules in
`smarter-infrastructure-apply`.

## Adding or changing a skill

- Add to an existing skill before adding a new one.
- Write the `description` as "Use when ...", naming the concrete situations.
- Explain why a rule exists, and point to real files rather than copying code.
- When a convention changes (a module, a stack, a hook), update the skill in
  the same pull request.
- Add a new skill to the table above and to the index in
  `smarter-infrastructure-development/SKILL.md`.
- No secrets, account ids, ARNs or private host names: this repository is
  public.
