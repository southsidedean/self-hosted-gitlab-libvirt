# Plan: refreshing the lab in a box

Status: 0.2.0 done, 0.3.0 next (2026-11-04). `v0.1.0` is the 2023 tutorial's last version. First drafts of the guides are on the `guide-draft` branch.

## Goal

Someone with one Linux machine can follow the README and the pages it links to, and end up with their own GitLab, running each CI/CD job in a fresh KVM virtual machine. The tutorial works on current software, and CI warns us when that stops being true. Short guides show how to protect the lab, prove it works, and keep it current.

## Ground rules

- **Tom's voice stays.** The introduction and the story stay as written, in the past tense, as his 2023 setup. A short, dated "2026 update" note says what changed and what the tutorial targets now. Edits to the prose are technical corrections, and they're shown to Tom before they go in.
- **Easy to read for beginners.** Plain bash, plain words, no frameworks and nothing clever. If a check or a test is harder to read than the script it checks, simplify it.
- **Small on purpose.** This repository is a tutorial with a few scripts. It borrows from `kodi-iptv-assistant` and `observability-k3d` only what fits that size.
- **Keep private details out.** Host names and network details are sanitized in everything new: files, screenshots, commits, and pull requests. Examples use `gitlab.example.com`, `lab-host`, and the `192.0.2.x` documentation addresses.

## Decisions

| Question | Decision |
|---|---|
| First tag | `v0.1.0` on `88b1413`, signed, with a release that lists the known problems (done 2026-11-03) |
| Host OS for the tutorial | Ubuntu 26.04, with 24.04 as the fallback if testing finds a blocker. `virt-builder` and libvirt build and boot a VM on 26.04 (`vm-test.yml`), but the full tutorial is untested there |
| GitLab edition | Community Edition in the tutorial and guides |
| Job VM image | Debian 13, with Debian 12 as the fallback only if the build fails |
| Terraform state | GitLab-managed state replaces the `/opt/tf-state` share. Every job VM mounts the same folder today, and managed state adds locking and encryption. This undoes `e5df696` and `88b1413` |
| Terraform | Stays the default, with a short note about OpenTofu. GitLab's docs now center on OpenTofu, so the tutorial writes its own `backend "http"` example |
| Licenses | GPL-3.0 for the scripts (`LICENSE`), CC BY-SA 4.0 for the README, guides, and images (`LICENSE-docs`). The scripts that come from GitLab's docs say so in a short header |
| Old screenshots | Moved to `images/archive/`, with private details replaced by example values and the README's links updated, until new ones replace them |
| Git history | Not rewritten. Old commits and the `v0.1.0` tag keep the original 2023 screenshots and the host name |
| Logo | The pipeline logo, `images/gitlab-libvirt-logo.svg` and its dark version |
| Social image | `images/social-preview.png`, built from `images/social-preview.html`, showing the whole lab and not only the runner |
| Add-on guides | Each gets a short page in `docs/`, linked from the README. First drafts wait on the `guide-draft` branch until they're tested |
| Dependency updates | Dependabot, for pinned GitHub Actions |
| Merging | Pull requests only, squash merges, signed release tags |
| `PLAN.md` | Tracked and public |
| Claude Code files | `CLAUDE.md` is tracked and public. `CLAUDE.local.md`, `.claude/`, and similar stay out of the repository, through `.git/info/exclude` |

## Roadmap

### 0.1.0: Snapshot (done)

The tag and the release.

### 0.2.0: Foundation (done)

No change to how the tutorial works, apart from fixing `iconcurrent`.

- Sync local `main` with GitHub. Both sides made the same change, so `git pull --rebase` should drop the duplicate.
- Add `PLAN.md`, `CLAUDE.md`, `LICENSE`, `LICENSE-docs`, `.gitignore`, `CHANGELOG.md`, `.github/dependabot.yml`, and a pull request template with a checkbox for looking at every image. Keep `CONTRIBUTING.md` and `SECURITY.md` to a few lines each.
- Add the source and license header to each file that comes from GitLab's docs: `base.sh`, `prepare.sh`, `run.sh`, `cleanup.sh`, `runner-builder.sh`, and `config.toml`.
- Remove `images/.DS_Store`.
- Commit the screenshot archive and the warning at the top of the README.
- Add the logo to the top of the README, and commit the social image. Tom uploads it in GitHub's settings.
- Fix `iconcurrent` in both `config.toml` and the README.
- Add `scripts/check.sh` and `.github/workflows/tests.yml` (see [CI](#ci)).
- Fix what shellcheck finds at warning level, with no change in behavior.
- Turn on secret scanning with push protection, Dependabot security updates, private vulnerability reporting, and deleting branches after merging. Allow squash merges only.
- Add two rulesets: `Protect main`, requiring the `checks` job, and `Protect release tags`.

Done when: `checks` is required on `main`, and the first pull request after that goes through it.

### 0.3.0: Working scripts

Each test lands in the same pull request as the fix it covers.

- Fix `cleanup.sh` so it stops the VM, waits, and only then deletes the disk, as GitLab's current script does. Add one small test file, with fake commands, covering the cleanup order and failure exit codes.
- Pick up the rest of GitLab's script changes: `LIBVIRT_DEFAULT_URI` and the longer waits.
- Move the job VM image to Debian 13:
  - Generate SSH host keys with `ssh-keygen -A`. Without that line, a test VM booted but refused SSH.
  - Remove `docker` and `software-properties-common`, which Debian 13 doesn't have. No job in the tutorial uses Docker, and `docker.io` is there for anyone who needs it.
  - Install `lsb-release` directly, or read the codename from `/etc/os-release`, because the HashiCorp step needs it.
  - Use `curl` in place of `wget`.
  - Install `git-lfs` from Debian if that works, and drop its separate repository.
  - Update `--os-variant` and the host name.
- Make `--root-password random` the default. Nothing needs the password once the README's console step is gone, so there's no argument to check or leak.
- Have the scripts stop with a clear message when the SSH key is missing.
- Replace the `/opt/tf-state` share with GitLab-managed Terraform state. Remove its lines from `runner-builder.sh` and `prepare.sh`, including `numa` and `memorybacking` if nothing else needs them. Add a one-sentence note on moving existing state, and a tested `backend "http"` example using `CI_JOB_TOKEN`.
- Rename `config.toml` to `config.example.toml`, add `config.toml` to `.gitignore`, and update every reference in the same pull request.
- Grow `.github/workflows/vm-test.yml` to run the real scripts, then give it its weekly schedule. It boots a small test VM today.
- Write `docs/release-checklist.md`, including the test VM's network, how a job VM finds GitLab, how to avoid a clash between the two layers' default libvirt networks, a check that the weekly run is still enabled, and a hand check of the links.

Done when: `checks` passes, and the sample job in the first-pipeline guide goes green on a test install, following the checklist.

### 0.4.0: README refresh and guides

**README**

- Correct the runner steps: GitLab Runner and the driver scripts run on the host.
- Choose one way to set up the runner, and test it. Today, pasting a config with a fake token and then running `gitlab-runner register` leaves two entries.
- Move to the current registration flow: create the runner in GitLab with **Run untagged** selected, then register with its `glrt-` token.
- Say "instance runner" where GitLab now does.
- Document everything the host needs, including the exact command for the SSH key. The scripts expect `/root/.ssh/id_rsa`, and newer `ssh-keygen` versions default to ed25519.
- Update the steps to Ubuntu 26.04, leaving the story as written.
- Update the title and GitHub's repository description, which name Ubuntu 22.04. Show both to Tom first.
- Add the "2026 update" note, which replaces the warning at the top.
- Add one short warning to check sign-up settings, since anyone with an account can run jobs on the machine.
- Move the Cockpit port change to a systemd override, starting with an empty `ListenStream=`.
- Replace the GitLab 15.7 link that returns a 404, and hand-check the rest.
- Replace the host name in the README's sample output.
- Retake the screenshots, with plain file names and sanitized contents. Remove `images/archive/` once nothing links to it.

**Guides**

- Test the guides on `guide-draft` (hardware, first pipeline, security, backups, upgrades, and Cockpit VMs), fix what the test finds, and bring them into `docs/` on `main`. They're drafted from GitLab's and Cockpit's docs, and haven't been run yet.
- Add the README's "Add-On Guides" section, linking them.
- Add a short guide to finding and removing job VMs and disks left behind by a failed cleanup.
- Expand the note in `docs/upgrades.md` on refreshing the base image with `runner-builder.sh`.
- Add an optional paragraph to `docs/security.md` on using WireGuard or Tailscale in place of port forwarding, when only you need to reach the lab.
- Link GitLab's SMTP docs, since the README sets up mail DNS but never configures sending.
- Point out GitLab's built-in container registry and Pages in a sentence.
- Link `observability-k3d` for anyone who wants full monitoring.
- Add one optional paragraph on reaching libvirt on the host from a job, using an authenticated connection like `qemu+ssh`. Warn that a job with that access can control the host, which undoes the isolation of a fresh VM.

Done when: Tom has read and approved every change to the prose; `iconcurrent`, `--registration-token`, and the real host name are gone from the current files; and the links were checked.

### 1.0.0: Proven

- Start from a clean VM and reach a passing CI job using only the README and the pages it links to, noting every place that wasn't enough. Ideally, someone other than the author runs this.
- Fix what that finds, then repeat on an older machine without AVX as a final check.
- Do an independent review of every file.

Done when: the walkthrough succeeds without outside help, and the review has no open findings.

## Staying out of the stack

The lab doesn't need another major service. These stay out so it stays a simple one-machine build:

- Kubernetes, Proxmox, and OpenStack: they'd replace the one-machine idea.
- Vault: GitLab's CI/CD variables are enough for a home lab.
- A Prometheus and Grafana stack: `observability-k3d` covers monitoring, and Cockpit handles the basics here.
- Single sign-on: one person doesn't need it.

## CI

`tests.yml` follows the shape of the two example repositories: it runs on pull requests, pushes to `main`, a weekly schedule, and by hand, with actions pinned to full commits, read-only permissions, and a time limit. It has one job, `checks`, which runs `scripts/check.sh`, so you can run the same checks locally. Only `checks` is required, so adding a test later doesn't change the ruleset.

| In `scripts/check.sh` | What it catches | Added in |
|---|---|---|
| shellcheck (`-x --severity=warning`) | Mistakes in the bash scripts | 0.2.0 |
| actionlint and zizmor | Mistakes and security problems in the workflows. Neither comes with the runner, so zizmor goes first if installing them makes `check.sh` long | 0.2.0 |
| A few `grep` lines | `iconcurrent` coming back in the example config or the README | 0.2.0 |
| Script tests | The cleanup order and failure exit codes, using fake `virsh`, `ssh`, `qemu-img`, and `virt-install` commands | 0.3.0 |

`vm-test.yml` is separate and isn't required. It runs weekly and by hand on `ubuntu-26.04`, building the image and running `prepare.sh`, `run.sh`, and `cleanup.sh` with fake CI variables. It's the most valuable test here: shellcheck found none of the bugs listed in the `v0.1.0` release, and fake commands catch only the cleanup order.

GitHub turns off scheduled workflows after 60 days without activity in a public repository, and this one can be quiet for a long time. The release checklist confirms the weekly run is still on. Monthly Dependabot merges may keep it alive, though that isn't confirmed.

### Left out on purpose

- Python tools (pytest, ruff, bandit, mypy): there's no Python here, and the config check uses `grep`.
- CodeQL, Scorecard, and dependency review: there's little for them to analyze.
- Image builds and scans: there are no images to publish.
- Renovate: Dependabot is enough for pinned actions.
- An automated link check: sites block or rate-limit checkers, so it's a hand check on the release checklist.
- A self-hosted runner: this repository is public, so a pull request from a fork could run code on the machine.

## How it gets tested

1. **On every pull request:** `checks`, on GitHub's hosted runners.
2. **Weekly:** `checks` and `vm-test.yml`.
3. **For each release:** a full install in a disposable VM with nested virtualization, following `docs/release-checklist.md`. A full GitLab install is too heavy for routine CI.

The test VM isn't created until the 0.3.0 work needs it. The default libvirt network uses NAT, so Let's Encrypt and port forwarding can't be tested this way. Those steps stay a manual check on a machine with a real DNS name.

## Open questions

- **Does `ufw` get in the way of the job VMs?** `docs/security.md` turns on a firewall, and `libvirt` manages firewall rules of its own. Check that job VMs still get an address and reach GitLab.
- **Does the full Debian 13 image work as it's set up?** A small test image builds and boots, and it gets an address using the `/etc/network/interfaces` lines. The HashiCorp and GitLab Runner repositories exist, but the full build, with their packages, hasn't been run.
