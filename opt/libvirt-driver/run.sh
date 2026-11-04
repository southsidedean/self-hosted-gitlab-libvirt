#!/usr/bin/env bash

# /opt/libvirt-driver/run.sh
# Adapted from GitLab's libvirt custom executor example:
# https://docs.gitlab.com/runner/executors/custom_examples/libvirt/
# The original, by GitLab, is licensed CC BY-SA 4.0. This adapted version is
# licensed GPL-3.0; see LICENSE.

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

VM_IP=$(_get_vm_ip)

ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" /bin/bash < "${1}"
if [ $? -ne 0 ]; then
    # Exit using the variable, to make the build as failure in GitLab
    # CI.
    exit "$BUILD_FAILURE_EXIT_CODE"
fi

