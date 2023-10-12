#!/usr/bin/env bash

# /opt/libvirt-driver/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

# Copy base disk to use for Job.
qemu-img create -f qcow2 -b "$BASE_VM_IMAGE" "$VM_IMAGE" -F qcow2

# Install the VM
virt-install \
    --name "$VM_ID" \
    --os-variant debian11 \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus=2 \
    --ram=2048 \
    --network default \
    --graphics none \
    --noautoconsole \
    --cpu numa.cell0.memory=2,numa.cell0.cpus=0-1,numa.cell0.id=0,numa.cell0.unit=GiB,numa.cell0.memAccess=shared \
    --memorybacking access.mode=shared \
    --filesystem type=mount,mode=passthrough,driver.type=virtiofs,source=/opt/tf-state,target=tf-state-dir

# Wait for VM to get IP
echo 'Waiting for VM to get IP'
for i in $(seq 1 30); do
    VM_IP=$(_get_vm_ip)

    if [ -n "$VM_IP" ]; then
        echo "VM got IP: $VM_IP"
        break
    fi

    if [ "$i" == "30" ]; then
        echo 'Waited 30 seconds for VM to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done

# Wait for ssh to become available
echo "Waiting for sshd to be available"
for i in $(seq 1 30); do
    if ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" >/dev/null 2>/dev/null; then
        break
    fi

    if [ "$i" == "30" ]; then
        echo 'Waited 30 seconds for sshd to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done

# Mount state directory

echo "Mounting tf-state-dir at /opt/tf-state"
ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" "/usr/bin/sudo mount -t virtiofs tf-state-dir /opt/tf-state"

