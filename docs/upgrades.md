# Upgrading GitLab

[GitLab: Upgrade paths](https://docs.gitlab.com/update/upgrade_paths/)

[GitLab: Upgrade Path tool](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/)

[GitLab: Upgrade a Linux package instance](https://docs.gitlab.com/update/package/)

[GitLab: Background migrations](https://docs.gitlab.com/update/background_migrations/)

Upgrade GitLab regularly, as many of those releases are security fixes.  If you let your lab sit for a while like I did, you can't just jump straight to the latest version.  GitLab has **required upgrade stops**, and you need to go through each one.

## Find Your Path

Check which version you're running:
```bash
sudo cat /opt/gitlab/embedded/service/gitlab-rails/VERSION
```

Plug that version and your target into the [Upgrade Path tool](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/), and it'll give you your list of stops.  Read GitLab's upgrade notes for each one.

## Upgrade, One Stop at a Time

Before you start, [make a backup](backups.md).

Install the version for your next stop, using the latest patch release of that version.  These examples are for Community Edition.  For Enterprise Edition, swap `gitlab-ce` for `gitlab-ee` and `-ce.0` for `-ee.0`.

See which versions are available:
```bash
apt-cache madison gitlab-ce
```

Install the version for your stop:
```bash
sudo apt update && sudo apt install gitlab-ce=<version>-ce.0
```

**Don't run `apt install gitlab-ce` without a version unless you're at your last stop.**  That installs the newest release, which skips your stops.

## Wait Before the Next Stop

GitLab finishes some of its upgrade work in the background.  Let it finish before you move to the next stop.

You can check in the web interface: select **Admin**, then **Monitoring --> Background migrations**.  **Queued** and **Finalizing** should be empty, with nothing in **Failed**.

Or, from the command line (*on GitLab 18.9 or later*):
```bash
sudo gitlab-rake gitlab:background_migrations:list
```

***Repeat until you reach your target version.***

## Don't Forget the Runner

Keep GitLab Runner on your host in step with GitLab:
```bash
sudo apt update && sudo apt install gitlab-runner
```

Your job VMs are built from the base image, so they don't get updates on their own.  Rebuild the base image with `runner-builder.sh` every so often to pick up the latest packages.

## Check Your Work

Run a [pipeline](first-pipeline.md) to make sure everything still works.

***Now, go put the next upgrade on your calendar, so you don't have a long list of stops next time!***
