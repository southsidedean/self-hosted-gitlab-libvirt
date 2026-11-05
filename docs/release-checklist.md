# Release Checklist

Run this before each release, on a disposable VM with nested virtualization.  It's a full install, from an empty VM to a green pipeline.

## Before You Start

- [ ] The weekly `vm-test` is still enabled and passing.  GitHub turns off scheduled workflows after 60 days without repository activity:
  ```bash
  gh workflow view vm-test.yml
  ```
- [ ] Click through the links in the README and the guides by hand.

## Create the Test VM

We'll call the test VM `lab-host`, and the machine it runs on the outer host.

- [ ] Nested virtualization is on for the outer host.  This should print `Y` or `1`:
  ```bash
  cat /sys/module/kvm_intel/parameters/nested /sys/module/kvm_amd/parameters/nested 2>/dev/null
  ```
- [ ] Create the VM from an Ubuntu 26.04 image, with at least 6 vCPUs, 16 GB of memory, and 100 GB of disk.  Add `--cpu host-passthrough` to `virt-install`, or job VMs won't get KVM.  An older outer host may not know Ubuntu 26.04, so use its newest Ubuntu for `--osinfo`.
- [ ] On `lab-host`, `/dev/kvm` exists.

## Install the Host

- [ ] Install `libvirt` and the VM tools:
  ```bash
  sudo apt-get update
  ```
  ```bash
  sudo apt-get install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients virtinst guestfs-tools
  ```
- [ ] Look at the two layers' networks.  The outer host probably uses `192.168.122.0/24`, and `lab-host` is on that network, so `libvirt` on `lab-host` should pick another range by itself.  Check that the address below isn't the same network as `lab-host`'s own address, and save it, as `<<LIBVIRT_IP>>`:
  ```bash
  sudo virsh net-dumpxml default | grep "<ip "
  ```
- [ ] `passt` isn't installed.  If it is, the image build won't get a network, so remove it:
  ```bash
  dpkg -l passt
  ```
- [ ] Clone this repository, install the driver, and build the base image:
  ```bash
  sudo ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
  ```
  ```bash
  sudo ./install-libvirt-driver.sh
  ```
  ```bash
  sudo ./runner-builder.sh
  ```

## Install GitLab

- [ ] Point the name at `lab-host`'s `libvirt` address, in `/etc/hosts`.  Job VMs can reach that address, and they find the name through the `libvirt` network's DNS, so this line is all they need:
  ```
  <<LIBVIRT_IP>> gitlab.example.com
  ```
- [ ] Install GitLab Community Edition, using `EXTERNAL_URL="http://gitlab.example.com"`.  Let's Encrypt can't reach a VM behind NAT, so this test uses HTTP.
- [ ] GitLab's installer treats `gitlab.example.com` as a placeholder, so it may finish without starting anything.  If the sign-in page doesn't load, run:
  ```bash
  sudo gitlab-ctl reconfigure
  ```
- [ ] Log in as `root`, with the password in `/etc/gitlab/initial_root_password`.

## Set Up the Runner

- [ ] Install GitLab Runner on `lab-host`, from [GitLab's repository](https://docs.gitlab.com/runner/install/linux-repository/).
- [ ] In GitLab, go to **Admin --> CI/CD --> Runners**, create an instance runner with **Run untagged** selected, and copy its `glrt-` token.
- [ ] Register the runner, and restart it:
  ```bash
  sudo gitlab-runner register --non-interactive \
    --url http://gitlab.example.com --token <<TOKEN>> \
    --name libvirt-driver --executor custom \
    --builds-dir /home/gitlab-runner/builds --cache-dir /home/gitlab-runner/cache \
    --custom-prepare-exec /opt/libvirt-driver/prepare.sh \
    --custom-run-exec /opt/libvirt-driver/run.sh \
    --custom-cleanup-exec /opt/libvirt-driver/cleanup.sh
  ```
  ```bash
  sudo systemctl restart gitlab-runner
  ```

## Run the Jobs

- [ ] Create a project with this `.gitlab-ci.yml`:
  ```yaml
  say-hello:
    script:
      - echo "Hello from $(hostname)!"
      - cat /etc/os-release
      - whoami
  ```
- [ ] The job goes green, running as `gitlab-runner` on Debian 13.
- [ ] While the job runs, `sudo virsh list --all` shows a `runner-` VM.  Afterward, the VM and its disk are gone, and `gitlab-runner-base.qcow2` is still in `/var/lib/libvirt/images/`.
- [ ] Copy `examples/terraform-state/` to a second project, and run its pipeline twice.  The second run says `No changes`.

## Turn On the Firewall

- [ ] Follow the firewall steps in the security guide, with your own network in the SSH and Cockpit rules.
- [ ] Add this job, and run it.  It should print `gitlab 200` and `internet 200`:
  ```yaml
  network-check:
    script:
      - getent hosts gitlab.example.com
      - curl -sS -o /dev/null -w "gitlab %{http_code}\n" --max-time 20 http://gitlab.example.com/users/sign_in
      - curl -sS -o /dev/null -w "internet %{http_code}\n" --max-time 20 https://deb.debian.org/
  ```
- [ ] Reboot `lab-host`, wait for GitLab to come back, and run the job again.
- [ ] `libvirt`'s TCP port isn't listening.  This shouldn't print anything:
  ```bash
  ss -ltn | grep 16509
  ```

## By Hand, on a Machine With a Real DNS Name

A VM behind NAT can't test these:

- [ ] Let's Encrypt and HTTPS
- [ ] Port forwarding, on a custom port if you use one
- [ ] Reaching GitLab's URL from a job VM, through your router

## Clean Up

- [ ] Delete the test VM and its disks on the outer host.
