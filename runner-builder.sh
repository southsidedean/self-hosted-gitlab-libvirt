#!/usr/bin/bash

# Script to build GitLab libvirt runner
# Adapted from GitLab's libvirt custom executor example:
# https://docs.gitlab.com/runner/executors/custom_examples/libvirt/
# The original, by GitLab, is licensed CC BY-SA 4.0. This adapted version is
# licensed GPL-3.0; see LICENSE.
# Tom Dean
# 10/11/23

# This needs root, to read root's SSH key and write to libvirt's images folder

if [ "$(id -u)" -ne 0 ]; then
    echo 'Please run this as root: sudo ./runner-builder.sh'
    exit 1
fi

# The job VMs trust this key, so stop now if it's missing

if [ ! -f /root/.ssh/id_rsa.pub ]; then
    echo 'The SSH key /root/.ssh/id_rsa.pub is missing. Create it with:'
    echo '  sudo ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""'
    exit 1
fi

# Let's build our runner image
# The root password is random, and virt-builder prints it when it finishes.
# You don't need it to run jobs, because the scripts log in with the SSH key.

virt-builder debian-13 \
    --size 8G \
    --output /var/lib/libvirt/images/gitlab-runner-base.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-trixie \
    --network \
    --install curl,gnupg,libvirt-clients,libvirt-daemon-system,genisoimage,xsltproc,sudo \
    --run-command 'curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg' \
    --run-command 'gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint' \
    --run-command '. /etc/os-release && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/hashicorp.list' \
    --run-command 'apt update' \
    --install terraform \
    --run-command 'curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash' \
    --run-command 'useradd -m -p "" gitlab-runner -s /bin/bash' \
    --install gitlab-runner,git,git-lfs,openssh-server \
    --run-command "git lfs install --skip-repo" \
    --run-command "ssh-keygen -A" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa.pub \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub-mkconfig -o /boot/grub/grub.cfg" \
    --run-command "echo 'auto eth0' >> /etc/network/interfaces" \
    --run-command "echo 'allow-hotplug eth0' >> /etc/network/interfaces" \
    --run-command "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces" \
    --root-password random
