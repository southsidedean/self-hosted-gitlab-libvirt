#!/usr/bin/env bash

# Builds a small Debian 13 VM, boots it with libvirt and KVM, and logs in over
# SSH. If this passes, the machine can run job VMs. It answers the plan's question
# about GitHub's hosted runners, and it uses the same steps a job VM needs.
#
# Run it as root, on a machine you don't mind changing:
#
#   sudo scripts/vm-test.sh

set -euo pipefail

VM_NAME="vm-test"
VM_IMAGE="/var/lib/libvirt/images/$VM_NAME.qcow2"
SSH_KEY="/root/.ssh/vm-test-key"

# If anything fails, show what libvirt knows about the VM and its network.
show_state() {
    echo "== vm-test FAILED. What libvirt can see:"
    virsh list --all || true
    virsh net-list --all || true
    virsh net-dhcp-leases default || true
    virsh domifaddr "$VM_NAME" || true
}
trap show_state ERR

echo "== Is KVM available?"
ls -l /dev/kvm
virt-host-validate qemu || true

echo "== Make a throwaway SSH key"
mkdir -p /root/.ssh
ssh-keygen -q -t ed25519 -N "" -f "$SSH_KEY"

echo "== Build the image"
virt-builder debian-13 \
    --size 8G \
    --no-progress-bars \
    --output "$VM_IMAGE" \
    --format qcow2 \
    --hostname vm-test \
    --network \
    --install openssh-server \
    --ssh-inject "root:file:$SSH_KEY.pub" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub-mkconfig -o /boot/grub/grub.cfg" \
    --run-command "echo 'auto eth0' >> /etc/network/interfaces" \
    --run-command "echo 'allow-hotplug eth0' >> /etc/network/interfaces" \
    --run-command "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces" \
    --root-password disabled

echo "== Start libvirt's default network"
virsh net-start default || true

echo "== Boot the VM"
virt-install \
    --name "$VM_NAME" \
    --osinfo detect=on,require=off \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus=2 \
    --ram=2048 \
    --network default \
    --graphics none \
    --noautoconsole

echo "== Did the VM really use KVM?"
virsh dumpxml "$VM_NAME" | grep "<domain type=" | grep "kvm"

echo "== Wait for an IP address"
VM_IP=""
for i in $(seq 1 90); do
    VM_IP=$(virsh -q domifaddr "$VM_NAME" | awk '{print $4}' | sed -E 's|/([0-9]+)?$||')
    if [ -n "$VM_IP" ]; then
        echo "The VM got an address after $i tries."
        break
    fi
    sleep 2
done
if [ -z "$VM_IP" ]; then
    echo "The VM never got an IP address."
    show_state
    exit 1
fi

echo "== Wait for SSH, and run a command in the VM"
for i in $(seq 1 60); do
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
        "root@$VM_IP" "uname -a; . /etc/os-release; echo \$PRETTY_NAME; systemd-detect-virt"; then
        echo "== vm-test passed, after $i SSH tries."
        exit 0
    fi
    sleep 2
done

echo "Couldn't log in to the VM over SSH."
show_state
exit 1
