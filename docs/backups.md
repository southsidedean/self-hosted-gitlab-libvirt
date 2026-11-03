# Backing Up GitLab

[GitLab: Back up GitLab](https://docs.gitlab.com/administration/backup_restore/backup_gitlab/)

[GitLab: Restore GitLab](https://docs.gitlab.com/administration/backup_restore/restore_gitlab/)

[GitLab: Back up the configuration](https://docs.gitlab.com/omnibus/settings/backups/)

This is your primary place to do development, so it deserves a backup.  There's a catch, though: **GitLab's backup command doesn't include your configuration files.**  You need both parts.

## What to Back Up

| What | Command | Where it goes |
|---|---|---|
| Repositories, database, uploads | `gitlab-backup create` | `/var/opt/gitlab/backups` |
| Configuration and secrets (`/etc/gitlab`) | `gitlab-ctl backup-etc` | `/etc/gitlab/config_backup` |

The configuration matters more than you'd think.  `/etc/gitlab/gitlab-secrets.json` holds the key that decrypts sensitive data in the database.  Without it, a restore can leave users with two-factor authentication locked out, and your runners unable to sign in.

## Make a Backup

Back up GitLab:
```bash
sudo gitlab-backup create
```

Back up the configuration:
```bash
sudo gitlab-ctl backup-etc
```

## Schedule It

Let's run both every night, by adding them to the `root` crontab:
```bash
sudo crontab -e -u root
```

Add these lines:
```
0 2 * * * /opt/gitlab/bin/gitlab-backup create CRON=1
30 3 * * * /opt/gitlab/bin/gitlab-ctl backup-etc
```

To keep a week of GitLab backups, add this to `/etc/gitlab/gitlab.rb`:
```ruby
gitlab_rails['backup_keep_time'] = 604800
```

Then, apply the change:
```bash
sudo gitlab-ctl reconfigure
```

## Get It Off the Machine

A backup on the same disk won't help you if that disk dies, so copy both parts somewhere else.  Keep them **apart from each other**, too.  That way, anyone who gets hold of your data doesn't also get the keys to decrypt it.

## Test a Restore

A backup you've never restored is just a hope.  Try it on a spare virtual machine at some point, not on your running instance, since **a restore overwrites the GitLab database**.

The new machine needs to be running exactly the same GitLab version and edition (CE or EE) as the backup.  Then:

1. Put your original `gitlab-secrets.json` and `gitlab.rb` in `/etc/gitlab`, and run `sudo gitlab-ctl reconfigure`.
2. Copy the backup into place:
   ```bash
   sudo cp <backup-file>_gitlab_backup.tar /var/opt/gitlab/backups/
   sudo chown git:git /var/opt/gitlab/backups/<backup-file>_gitlab_backup.tar
   ```
3. Stop the processes that connect to the database:
   ```bash
   sudo gitlab-ctl stop puma
   sudo gitlab-ctl stop sidekiq
   ```
4. Restore the backup, leaving `_gitlab_backup.tar` off the name:
   ```bash
   sudo gitlab-backup restore BACKUP=<backup-file>
   ```
5. Follow the short database step in the [restore docs](https://docs.gitlab.com/administration/backup_restore/restore_gitlab/), then reconfigure and start GitLab:
   ```bash
   sudo gitlab-ctl reconfigure
   sudo gitlab-ctl start
   ```
6. Check your work:
   ```bash
   sudo gitlab-rake gitlab:check SANITIZE=true
   sudo gitlab-rake gitlab:doctor:secrets
   ```

***You don't need to back up your job VMs.  They're thrown away after every job, and you can rebuild the base image with `runner-builder.sh`.***
