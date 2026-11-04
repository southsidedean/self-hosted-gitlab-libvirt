#!/usr/bin/env bash

# /opt/libvirt-driver/cleanup.sh
# Adapted from GitLab's libvirt custom executor example:
# https://docs.gitlab.com/runner/executors/custom_examples/libvirt/
# The original, by GitLab, is licensed CC BY-SA 4.0. This adapted version is
# licensed GPL-3.0; see LICENSE.

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

set -eo pipefail

# Stop the VM, and wait up to 300 seconds for it to stop. "virsh destroy" fails if
# the VM is already off, and that's fine, so "|| true" keeps the script going.
for i in $(seq 1 300); do
    virsh destroy "$VM_ID" >/dev/null 2>&1 || true

    # An empty state means the VM is already gone.
    if [[ "$(virsh domstate "$VM_ID" 2>/dev/null | tr '[:upper:]' '[:lower:]')" =~ shut\ off|destroyed|^$ ]]; then
        break
    fi

    if [ "$i" == "300" ]; then
        echo 'Waited 300 seconds for VM to stop, exiting...'
        # Inform GitLab Runner that this is a system failure. The disk stays,
        # because the VM may still be using it.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done

# Undefine VM, if there is one. GitLab Runner also runs this script when prepare.sh
# failed, and there may be a disk but no VM. A VM with UEFI firmware needs --nvram.
if virsh domstate "$VM_ID" >/dev/null 2>&1; then
    virsh undefine "$VM_ID" || virsh undefine "$VM_ID" --nvram
fi

# Delete VM disk.
if [ -f "$VM_IMAGE" ]; then
    rm "$VM_IMAGE"
fi

