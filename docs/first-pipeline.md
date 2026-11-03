# Running Your First Pipeline

[GitLab: Tutorial: Create and run your first pipeline](https://docs.gitlab.com/ci/quick_start/)

[GitLab: Manage runners](https://docs.gitlab.com/ci/runners/runners_scope/)

So, you've got GitLab and a runner.  How do you know it all works?  Let's run a small pipeline that shows us the virtual machine our job is running in.

## Check Your Runner

Open your project, then go to **Settings --> CI/CD** and expand **Runners**.  You should see your instance runner, with a green circle next to it.  If you don't see it, turn on instance runners for the project here.

This pipeline's job doesn't have any tags, so your runner needs **Run untagged** turned on.  You'll find that in the runner's settings, under **Admin --> CI/CD --> Runners**.

## Add a Pipeline

In your project, go to **Code --> Repository**, and add a new file named `.gitlab-ci.yml` to the root of your repository, with these contents:
```yaml
say-hello:
  script:
    - echo "Hello from $(hostname)!"
    - cat /etc/os-release
    - whoami
```

Commit the file, and GitLab starts the pipeline for you.

## Watch It Go

On your GitLab host, list your virtual machines while the job runs:
```bash
virsh list --all
```

You should see a new VM with a name like this one, which only exists for this job:
```
runner-1-project-1-concurrent-0-job-1
```

In GitLab, go to **Build --> Pipelines** and select your pipeline, then select the `say-hello` job to read its log.  You should see the host name from the base image, the operating system of your job VM, and `gitlab-runner`.

Once the job finishes, run `virsh list --all` again.  ***The VM should be gone, ready for a fresh one on the next job!***

## If It Doesn't Work

| What you see | Where to look |
|---|---|
| The job stays **pending** | The runner isn't online, isn't enabled for this project, or doesn't have **Run untagged** turned on |
| The job fails before your script runs | Check the runner's log with `sudo journalctl -u gitlab-runner -e` |
| The VM never gets an IP address | Check that the `default` network is up with `virsh net-list --all` |
| The job can't clone your repository | The job VM has to reach your GitLab URL, so check DNS and your firewall from inside the VM |
