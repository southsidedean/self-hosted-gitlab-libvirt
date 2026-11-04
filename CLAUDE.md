# CLAUDE.md

This file guides Claude Code in this repository. It's public, so anything private or specific to one machine goes in `CLAUDE.local.md`, which is never committed.

## What this is

A tutorial for building a "lab in a box" on one Linux machine: self-hosted GitLab, a GitLab Runner that starts a fresh KVM/libvirt VM for each CI/CD job, plus Terraform, Packer, Ansible, and Cockpit. `README.md` is the tutorial. `runner-builder.sh` builds the job VMs' base image, `install-libvirt-driver.sh` installs the scripts in `opt/libvirt-driver/`, and `config.toml` is the runner's example configuration.

## Roadmap

`PLAN.md` holds the decisions and the roadmap. Read it before starting work, and update it in the same pull request when a decision changes. `v0.1.0` is the 2023 tutorial's last version.

## Rules

- **Keep Tom's voice.** Don't rewrite the introduction or the story. Show Tom any change to the README's prose before it goes in, and limit changes to technical corrections.
- **Keep the code easy for beginners to read.** Plain bash with no frameworks and nothing clever, including in the tests and CI.
- **Change `main` through pull requests only.** Squash merges, signed release tags. Commit and push only when asked.
- **Keep private details out of the repository.** Sanitize host names and network details in everything new: files, screenshots, commits, pull requests, and release notes. Use `gitlab.example.com`, `lab-host`, and the `192.0.2.x` documentation addresses. Test hosts live in Claude's project memory.
- **Ask before changing anything on a host.**

## Commands

```bash
scripts/check.sh   # every check a pull request has to pass; needs shellcheck, actionlint, and zizmor
```

To render the social image, see the comment at the top of `images/social-preview.html`.
