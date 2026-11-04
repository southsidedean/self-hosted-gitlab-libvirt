# Changelog

## 0.3.0 (unreleased)

- Fixed `cleanup.sh`, which asked the VM to shut down and deleted its disk without waiting. It now stops the VM first, waits up to 5 minutes, and keeps the disk if the VM won't stop. It also deletes the disk when `prepare.sh` failed before creating a VM.
- `prepare.sh` now waits up to 5 minutes for a VM's address and for SSH, up from 30 seconds each, and the scripts always use the system libvirt instance.
- `runner-builder.sh` and `prepare.sh` stop with a clear message when the SSH key is missing.
- The job VM image is now Debian 13, and a weekly test builds it and runs real jobs in it.
- Removed the `/opt/tf-state` share that every job VM mounted. GitLab-managed Terraform state replaces it.
- `runner-builder.sh` no longer takes a password. The root password is random, and the README's steps catch up in 0.4.0.

## 0.2.0 (2026-11-04)

The tutorial's steps don't change in this version, apart from one typo fix.

- Added `PLAN.md`, the logo, and a warning at the top of the README that some of the steps are out of date.
- Moved the 2023 screenshots to `images/archive/`, with private details replaced by example values.
- Added the licenses: GPL-3.0 for the scripts and CC BY-SA 4.0 for the README, guides, and images. The files that come from GitLab's docs now say so.
- Fixed the `iconcurrent` typo in `config.toml` and the README. The setting is `concurrent`.
- Added checks that run on every pull request.

## 0.1.0 (2026-11-03)

A snapshot of the tutorial as it stood in 2023. See the [release notes](https://github.com/southsidedean/self-hosted-gitlab-libvirt/releases/tag/v0.1.0) for its known problems.
