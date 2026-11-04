#!/usr/bin/env bash

# /opt/libvirt-driver/prepare.sh
# Adapted from GitLab's libvirt custom executor example:
# https://docs.gitlab.com/runner/executors/custom_examples/libvirt/
# The original, by GitLab, is licensed CC BY-SA 4.0. This adapted version is
# licensed GPL-3.0; see LICENSE.

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap 'exit $SYSTEM_FAILURE_EXIT_CODE' ERR

# We log in to the VM with this key, so stop now if it's missing.
if [ ! -f /root/.ssh/id_rsa ]; then
    echo 'The SSH key /root/.ssh/id_rsa is missing. Create it with:'
    echo '  sudo ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""'
    echo 'Then build the base image again with runner-builder.sh, so the image has the new key.'
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi

# Copy base disk to use for Job.
qemu-img create -f qcow2 -b "$BASE_VM_IMAGE" "$VM_IMAGE" -F qcow2

# Install the VM
virt-install \
    --name "$VM_ID" \
    --os-variant debian13 \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus=2 \
    --ram=2048 \
    --network default \
    --graphics none \
    --noautoconsole

# Wait for VM to get IP
echo 'Waiting for VM to get IP'
for i in $(seq 1 300); do
    VM_IP=$(_get_vm_ip)

    if [ -n "$VM_IP" ]; then
        echo "VM got IP: $VM_IP"
        break
    fi

    if [ "$i" == "300" ]; then
        echo 'Waited 300 seconds for VM to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done

# Wait for ssh to become available
echo "Waiting for sshd to be available"
for i in $(seq 1 300); do
    if ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" >/dev/null 2>/dev/null; then
        break
    fi

    if [ "$i" == "300" ]; then
        echo 'Waited 300 seconds for sshd to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done
