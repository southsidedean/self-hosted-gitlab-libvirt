<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/gitlab-libvirt-logo-dark.svg">
  <img src="images/gitlab-libvirt-logo.svg" alt="self-hosted-gitlab-libvirt logo: a pipeline of three stages" width="88">
</picture>

# Deploying a Self-Hosted GitLab Instance With a KVM GitLab Shared Runner on Ubuntu Linux 22.04

### Tom Dean: [LinkedIn](https://www.linkedin.com/in/tomdeanjr/)

> **Heads up (November 2026):** *I wrote this tutorial in 2023, and some of the steps are out of date.  I'm refreshing it now, so check [the plan](PLAN.md) to see where that stands before you follow along.*

## Introduction

For the past year or so, I've been authoring and managing content in a "homemade" hands-on labs platform, running in Amazon Web Services (AWS), with HashiCorp Terraform/Packer, using GitLab with CI/CD, and, frankly, *it has spoiled me rotten*.  

Last week, when my position was impacted in the second round of layoffs at my previous employer, one of the things I knew I was going to miss dearly (*other than my fantastic team!*) was this wonderful place to create and manage infrastructure-as-code projects.

*I guess the one great thing about periods of unemployment is the opportunity to tackle passion projects!*

After the dust settled, I realized that a great first project to soothe my soul and give me a place to create and store the coming torrent of projects and content would be a similar GitLab setup.  Being unemployed, I wanted to avoid the Cloud (*for now*) and utilize what I had on hand.  This would mean building on Ubuntu Linux 22.04, with a local, self-hosted GitLab instance, utilizing KVM/`libvirt` for a local GitLab shared runner for CI/CD operations.

In addition, the plan was to also use KVM/`libvirt` to run my local workloads, use Terraform/Ansible for automation in projects, and Packer and `virt-builder` for creating system images.  I plan to add more functionality in the future, but wanted to keep things manageable on the outset so I could get up and running in short order.

*In other words, we're going to build a "lab in a box"!*

In this tutorial, I'm not going to provide a step-by-step guide for installation, as there are many variables, depending on your environment.  I will point out the high-level considerations, where I ran into issues and will document any resources I used in this repository.

***Let's go!***

## High-Level Thinking

### Hardware

I have a **Dell Precision T5500** workstation sitting under my desk, which I recently upgraded:

- Ubuntu 22.04
- Dual six-core Xeons
- Plenty of storage
    - RAID-1 SSD for system: 250GB
    - RAID-1 HDD for data: 6TB
- Dual 1GB network connections
    - Public/General network
    - Private/Data/Application Network
- 72GB of RAM
- Decent GPU, possible future use?

The workstation was already up and running with Ubuntu 22.04, mostly idle, only serving as an NFS server at this point.  Yes, it's kind of old, but it's still a trooper, like me.

### Software

I wanted my "lab in a box" to have the following functionality:

- GitLab: *Keep it local!*
    - Place to do primary development
        - Release projects/content on GitHub
    - Local GitLab instance
    - Publically accessible (*by me*)
    - CI/CD
        - KVM/`libvirt` runner
- Terraform
    - Write automation for labs and projects
    - Execute workloads on KVM/`libvirt`
- Packer
    - Create images for projects
    - Also use `virt-builder` and Image Builder as needed
- Ansible
    - Might use in future projects, or for lab infrastructure
- Cockpit
    - Web-based server information and management
    - For when you want to treat your "lab in the box" as an appliance and skip the CLI

***Let's see how we build that!***

## KVM/`libvirt`: Install

[Ubuntu: libvirt](https://ubuntu.com/server/docs/virtualization-libvirt)

[How To Install KVM Hypervisor on Ubuntu 22.04|20.04](https://computingforgeeks.com/install-kvm-hypervisor-on-ubuntu-linux/)

[Red Hat: Getting started with virtualization](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/getting-started-with-virtualization-in-rhel-8_configuring-and-managing-virtualization#enabling-virtualization-in-rhel8_virt-getting-started)

[Creating a Directory-based Storage Pool with virsh](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_administration_guide/sect-virtualization-storage_pools-creating-local_directories-virsh)

At the bottom of the "lab in a box" stack, our foundation, is `libvirt`.  We're going to use it to execute our project workloads, including the shared GitLab runner we use for CI/CD.

The exact set of steps required to install the KVM/`libvirt` components will vary, based on your Linux distribution.  I've included links for Ubuntu and RHEL variants above, but you should be able to Google it and get instructions.  Remember, make sure you can install GitLab on your distribution as well.  If you're using some obscure distribution, you might be out of luck.

Once you have KVM/`libvirt` installed, let's give it a test:
```
virsh --help | more
```

You should get help for the `virsh` command-line utility, which is what we use to manage our virtual machine environment.

Let's make sure we can build virtual machine images:
```
virt-builder --help
```

We will use the `virt-builder` utility to build the image for our GitLab shared runner VM.

Let's check our system for virtual machines:
```
virsh list --all
```

***We shouldn't see any virtual machines at this point, unless you have some running already, of course.  We can move on to setting up our GitLab instance.***

## GitLab: Install and Configure

### GitLab: Prerequisites

Before you jump right in and install GitLab, you will need to configure some external items:

- DNS
    - GitLab Instance
        - ex: gitlab.example.com
    - GitLab Mail
        - ex: gitlab-mail.example.com
- Port Forwarding
    - GitLab Instance
        - Port 443, or another port, for HTTPS
            - Often 443 won't be available, you can pick another
            - If you use a different one, it will be on that port on the server
            - If you're using a custom port for HTTPS, make sure to append it to the URL you configure GitLab with
        - Port 80 (for Let's Encrypt, not needed for HTTP)

I would configure both of these before installation, so you have all the values pinned down, and so everything works at installation time.  Some of this stuff is needed during installation, so proceed at your own peril without it.

If you are only going to access the instance inside your network, you can use HTTP (if you're down with that), and don't need to forward any ports.  You will still need working DNS.

Read the Installation and DNS pages before you install, from front-to-back, and you'll be fine.


### GitLab: Installation

[Install self-managed GitLab](https://about.gitlab.com/install/)

[GitLab: DNS settings](https://docs.gitlab.com/omnibus/settings/dns.html)

Follow the instructions.  Again, if you're using a custom port for HTTPS, make sure to append it to the URL you configure GitLab with, for example `https://gitlab.example.com:PORT`.  GitLab will be listening on that port on the server, so make sure you forward that external port to the same port on the server.

Once installation is complete, head over to your web browser, plug in the URL to your GitLab instance and look for the login screen as shown below.

![GitLab Achieved!](images/archive/GitLab_Achieved.png)

At this point, you'll want to log in as `root`, change the default password that was supplied at installation time (*you saved that, right?*), and create a local GitLab user for yourself (and give that user Admin permissions, if desired).

Create a new project, set it up, add some code, give GitLab a workout.

***If you're not looking to do CI/CD, you can skip the next step, but I don't know why you wouldn't want to!***


### GitLab: Instance Runner: Information

[GitLab: Manage runners](https://docs.gitlab.com/ci/runners/runners_scope/)

In order to execute our GitLab CI/CD jobs, we're going to need a runner.  I've decided to use KVM/`libvirt` as the environment to "*run my runner*", and followed the instructions in the GitLab docs referenced below.

GitLab Runner itself runs on the host.  For each CI/CD job, it starts a fresh virtual machine from a base image, runs the job in it, and removes it when the job is done.

If you'd like to know more about GitLab runners, check out the link above.


### GitLab Instance Runner: Build the Job VM Image

[Using libvirt with the Custom executor](https://docs.gitlab.com/runner/executors/custom_examples/libvirt/)

Before we can run a job, we'll need to build a virtual machine image for our job VMs.  We're going to use `virt-builder`, as specified in the **"Using libvirt with the Custom executor"** instructions above.  You can follow the documents like I did, and should get a good result.  I have included assets and scripts in this repository to speed up deploying the `libvirt-driver` (`install-libvirt-driver.sh`) and building the image (`runner-builder.sh`).  Feel free to use them if you'd like.

#### If you'd like to use the scripts, do the following:

Clone this GitHub repository.  From the root of the repository:

Deploy `libvirt-driver`:
```bash
sudo ./install-libvirt-driver.sh
```

This will create the `/opt/libvirt-driver` directory, copy the `libvirt-driver` scripts to it and set permissions and ownership for the scripts.

You should see a result similar to this:
```bash
tom@lab-host:~$ ls -al /opt/libvirt-driver/
total 24
drwxr-xr-x 2 root root 4096 Nov  5 15:51 .
drwxr-xr-x 4 root root 4096 Nov  5 15:53 ..
-rwxr-xr-x 1 root root  936 Nov  5 15:51 base.sh
-rwxr-xr-x 1 root root 1518 Nov  5 15:51 cleanup.sh
-rwxr-xr-x 1 root root 2182 Nov  5 15:51 prepare.sh
-rwxr-xr-x 1 root root  687 Nov  5 15:51 run.sh
```

The runner reaches each job VM over SSH, using a key that belongs to `root` on the host.  If you don't have one at `/root/.ssh/id_rsa`, create it:
```bash
sudo ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
```

Next, we'll build the image, using the script.  `virt-builder` gives it a random `root` password, which we won't need, since the runner uses the SSH key.

Build job VM image:
```bash
sudo ./runner-builder.sh
```

***You don't need to start a virtual machine yourself.  The runner does that for each job.***


### GitLab Instance Runner: Install GitLab Runner

[Install GitLab Runner](https://docs.gitlab.com/runner/install/linux-repository/)

We'll install GitLab Runner on the host.  Add GitLab's repository:
```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" -o script.deb.sh
```
```bash
sudo bash script.deb.sh
```

Install GitLab Runner:
```bash
sudo apt-get install -y gitlab-runner
```

***Let's go ahead and register our instance runner with our GitLab instance!***


### GitLab Instance Runner: Register Your Instance Runner

[GitLab: Registering runners](https://docs.gitlab.com/runner/register/)

In order to utilize our instance runner, we must create it in GitLab and then register it.  As a GitLab Administrator, select **Admin** in the upper-right corner, then choose **CI/CD --> Runners**.  Select **Create instance runner**, select **Run untagged jobs**, then select **Create runner**.  GitLab will show you a token that starts with `glrt-`.  It only displays for a short time, so copy it now, and treat it like a password.

GitLab's page shows a shorter command, which asks you questions, but we'll use this one, which has all the answers.  Hop back to your host, and run the following command.  Replace the <<URL>> and <<TOKEN>> values with your values.  Your job VMs have to be able to reach this URL, because that's where they get your code from.

```bash
sudo gitlab-runner register --non-interactive \
  --url <<URL>> --token <<TOKEN>> \
  --name libvirt-driver --executor custom \
  --builds-dir /home/gitlab-runner/builds --cache-dir /home/gitlab-runner/cache \
  --custom-prepare-exec /opt/libvirt-driver/prepare.sh \
  --custom-run-exec /opt/libvirt-driver/run.sh \
  --custom-cleanup-exec /opt/libvirt-driver/cleanup.sh
```

This writes your settings to `/etc/gitlab-runner/config.toml`.  I've also provided an example in the repository (`config.example.toml`) if you'd like to compare.  When the process is complete, restart GitLab Runner, and you should see the instance runner appear (after a short delay, possibly).

```bash
sudo systemctl restart gitlab-runner
```

![Shared Runner Registered!](images/archive/Screen%20Shot%202023-02-20%20at%203.18.06%20PM.png)

If you have any projects you'd like to enable your instance runner for, navigate to the projects, go to **Settings --> CI/CD** and then expand the **Runners** section.  You can enable and check the status of instance runners for that project here.

![Shared Runner in Project](images/archive/Screen%20Shot%202023-02-20%20at%203.18.57%20PM.png)

We're not going to dive into CI/CD and instance runners right now, but if you know all that stuff, feel free to test and debug your runnner now.

***With GitLab and the instance runner installed, configured and working, the bulk of the work is done.  Let's finish the rest!***


## Terraform/Packer: Install

[Hashicorp: Official Packaging Guide](https://www.hashicorp.com/official-packaging-guide)

[Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

[Install Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)

I've written quite a bit of infrastructure-as-code in Terraform, using AWS, for lab environments and projects in the past, so I decided to try my hand with Terraform + KVM/`libvirt` to provide IaC automation for my projects.

I've also used Packer to build AMIs in the past, so I installed it, for when I start building in the Cloud.  I might explore using it to build local VM images.  For now, I've been using `virt-builder`.

To install these, you first need to add the repositories for Hashicorp, as described in the link above.  Follow the steps for your operating system.  Once the repositiories have been added, you can install Terraform and Packer as instructed in the links above.

You can verify your installation by checking the versions of Terraform and Packer:
```
terraform --version
```
```
packer --version
```

You should get the installed versions back.


## Ansible: Install

[How To Install and Configure Ansible on Ubuntu 22.04](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-ansible-on-ubuntu-22-04)

While you might not opt for it, at some point I figure I might need it, so I installed Ansible.  If you're not using Ubuntu, your procedure will be different.  It's pretty well-documented, so Google it.

Install Ansible repository for Ubuntu:
```
sudo apt-add-repository ppa:ansible/ansible
```

Install Ansible:
```
sudo apt-get update ; sudo apt install -y ansible
```

Again, totally optional, and if you're using a platform other than Ubuntu, follow the proper steps.  I'm not going to configure Ansible at this point, as it's a future project.


## Cockpit: Install/Configure

[Running Cockpit](https://cockpit-project.org/running)

Like I said above, sometimes you want to treat your "lab in the box" as an appliance and skip the CLI, so having the option to use Cockpit for system monitoring and administration is nice.  We can install Cockpit with a single command, and a quick configuration change.

For Ubuntu (22.04):
```
sudo apt-get update ; sudo apt-get install -y cockpit
```

Since GitLab is using the default Cockpit web interface port of `9090`, we need to change that.  I made it `8090` by editing the `/lib/systemd/system/cockpit.socket` file and changing it there.

Edit `/lib/systemd/system/cockpit.socket`:
```
sudo vi /lib/systemd/system/cockpit.socket
```

Like this:
```
[Socket]
ListenStream=8090
```

Next, you will need to reload the `systemd` unit files to pick up the changes:
```
sudo systemctl daemon-reload
```

Now, we can restart the `cockpit.socket` and `cockpit.service` units:
```
sudo systemctl restart cockpit.socket ; sudo systemctl restart cockpit.service
```

And check the status of Cockpit:
```
sudo systemctl status cockpit
```

Now you can log in to Cockpit at `https://yourhostname:8090`.

![Cockpit Overview Screen](images/archive/Screen%20Shot%202023-02-22%20at%203.01.05%20PM.png)

You should be able to log in as `root`, or another local user, and should get the dashboard as seen above.

***That's it!***


## Summary

In this tutorial, we created a "lab in a box" to host a local GitLab instance with CI/CD runner,levearging KVM/`libvirt` for our own "private cloud", Terraform/Packer/Anisible for automation/builds and Cockpit for a GUI management interface.  This should give us a great place to develop and test code, especially Infrastructure-as-Code projects.

Enjoy!

***Tom Dean***

## License

The scripts are licensed under [GPL-3.0](LICENSE), and this README, the guides, and the images are licensed under [CC BY-SA 4.0](LICENSE-docs).
