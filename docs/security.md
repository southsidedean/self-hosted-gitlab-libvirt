# Locking Down Your Lab

[GitLab: Sign-up restrictions](https://docs.gitlab.com/administration/settings/sign_up_restrictions/)

[GitLab: Enforce two-factor authentication](https://docs.gitlab.com/security/two_factor_authentication/)

[GitLab: Operating system hardening](https://docs.gitlab.com/security/hardening_operating_system_recommendations/)

If you forwarded ports to reach GitLab from outside your network, the Internet can reach it too.  **Do this before you put anything you care about on it.**

## Turn Off New Sign-Ups

Anyone with an account can create a project and run a pipeline, and those pipelines run on *your* machine.  Unless you're running this for a group, turn sign-ups off.

As an administrator:

1. In the upper-right corner, select **Admin**.
2. In the left sidebar, select **Settings --> General**.
3. Expand **New user account restrictions**.
4. Clear **Allow new user accounts**, then select **Save changes**.

## Require Two-Factor Authentication

Set up two-factor authentication on your own account first, then require it for everyone:

1. In the upper-right corner, select **Admin**.
2. In the left sidebar, select **Settings --> General**.
3. Expand **Sign-in restrictions**.
4. Select **Enforce two-factor authentication**.

Remember, your two-factor settings depend on `/etc/gitlab/gitlab-secrets.json`, which is one more reason to [back it up](backups.md).

## Set Up a Firewall

GitLab only needs TCP ports `80` and `443` open for basic use.  Everything else should be blocked, or limited to your own network.  We'll use `ufw` here, with `192.0.2.0/24` standing in for your home network.

**Allow SSH before you turn on the firewall, or you can lock yourself out!**
```bash
sudo ufw allow from 192.0.2.0/24 to any port 22 proto tcp
```

Allow GitLab.  If you're using a custom HTTPS port, use that instead of `443`:
```bash
sudo ufw allow 80/tcp
```
```bash
sudo ufw allow 443/tcp
```

Allow Cockpit from your own network only, and **don't** forward this port from your router:
```bash
sudo ufw allow from 192.0.2.0/24 to any port 8090 proto tcp
```

Turn on the firewall and check your work:
```bash
sudo ufw enable
```
```bash
sudo ufw status verbose
```

After that, run a CI/CD job to make sure your job VMs can still get an address and reach GitLab.  [Run your first pipeline](first-pipeline.md) if you don't have one yet.

## Keep `libvirt` Off the Network

By default, `libvirt` only listens on a local socket.  If you turn on its TCP port without authentication, anyone who can reach that port can control your virtual machines, and that's as good as `root` on your host.

Let's make sure it isn't listening:
```bash
ss -ltn | grep 16509
```

***You shouldn't get anything back.  If a job needs to reach `libvirt` on the host, use an authenticated connection like `qemu+ssh` instead.***
