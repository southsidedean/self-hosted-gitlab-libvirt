#!/usr/bin/bash

# Script to build GitLab libvirt runner
# See https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html
# Tom Dean
# 10/11/23

# Set root password here, from first argument
# If you want a randomized password, don't set it, but
# remove the last line of the command (that sets the root password)

ROOT_PASSWORD=$1

# Let's build our runner image

virt-builder debian-11 \
    --size 8G \
    --output /var/lib/libvirt/images/gitlab-runner-base.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-bullseye \
    --network \
    --install curl,gnupg,software-properties-common,libvirt-clients,libvirt-daemon-system,genisoimage,xsltproc,docker,sudo \
    --run-command 'wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg' \
    --run-command 'gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint' \
    --run-command 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list' \
    --run-command 'apt update' \
    --install terraform \
    --run-command 'curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash' \
    --run-command 'curl -s "https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh" | bash' \
    --run-command 'useradd -m -p "" gitlab-runner -s /bin/bash' \
    --install gitlab-runner,git,git-lfs,openssh-server \
    --run-command "git lfs install --skip-repo" \
    --run-command "mkdir -p /opt/tf-state" \
    --run-command "chown -R gitlab-runner:gitlab-runner /opt/tf-state" \
    --run-command "chmod -R 775 /opt/tf-state" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa.pub \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub-mkconfig -o /boot/grub/grub.cfg" \
    --run-command "echo 'auto eth0' >> /etc/network/interfaces" \
    --run-command "echo 'allow-hotplug eth0' >> /etc/network/interfaces" \
    --run-command "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces" \
    --root-password password:$ROOT_PASSWORD
