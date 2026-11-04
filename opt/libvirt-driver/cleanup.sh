#!/usr/bin/env bash

# /opt/libvirt-driver/cleanup.sh
# Adapted from GitLab's libvirt custom executor example:
# https://docs.gitlab.com/runner/executors/custom_examples/libvirt/
# The original, by GitLab, is licensed CC BY-SA 4.0. This adapted version is
# licensed GPL-3.0; see LICENSE.

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

set -eo pipefail

# Destroy VM.
virsh shutdown "$VM_ID"

# Undefine VM.
virsh undefine "$VM_ID"

# Delete VM disk.
if [ -f "$VM_IMAGE" ]; then
    rm "$VM_IMAGE"
fi

