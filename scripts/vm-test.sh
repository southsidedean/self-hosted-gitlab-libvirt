#!/usr/bin/env bash

# Runs the tutorial's real scripts against a real VM, the same way GitLab Runner
# does: build the base image, install the driver, then prepare a job VM, run one
# job that passes and one that fails, and clean up.
#
# Run it as root from the top of the repository, on a test machine only. It writes
# to libvirt's images folder and /opt/libvirt-driver, and it needs a machine with
# no base image yet:
#
#   sudo scripts/vm-test.sh

set -euo pipefail

# The variables GitLab Runner gives the scripts. The two exit codes are different
# from each other, so we can tell which one a script used.
export CUSTOM_ENV_CI_RUNNER_ID=1
export CUSTOM_ENV_CI_PROJECT_ID=2
export CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID=3
export CUSTOM_ENV_CI_JOB_ID=4
export SYSTEM_FAILURE_EXIT_CODE=70
export BUILD_FAILURE_EXIT_CODE=80

# The same names base.sh builds from those variables.
VM_ID="runner-1-project-2-concurrent-3-job-4"
IMAGES="/var/lib/libvirt/images"

# If anything fails, show what libvirt knows about the VM and its network.
show_state() {
    echo "== vm-test FAILED. What libvirt can see:"
    virsh list --all || true
    virsh net-dhcp-leases default || true
    virsh domifaddr "$VM_ID" || true
    echo "== The VM's own log, for SSH:"
    virt-log -d "$VM_ID" | grep -i "ssh" | tail -20 || true
}
trap show_state ERR

echo "== Is KVM available?"
ls -l /dev/kvm

echo "== Make the SSH key the scripts expect, if it's missing"
mkdir -p /root/.ssh
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ""
fi

echo "== Build the base image: runner-builder.sh"
./runner-builder.sh

echo "== Install the driver: install-libvirt-driver.sh"
./install-libvirt-driver.sh

echo "== Start libvirt's default network, if it isn't already running"
if [ "$(virsh net-info default | awk '/^Active:/ {print $2}')" != "yes" ]; then
    virsh net-start default
fi

echo "== Start a job VM: prepare.sh"
/opt/libvirt-driver/prepare.sh < /dev/null

echo "== Did the VM really use KVM?"
virsh dumpxml "$VM_ID" | grep "<domain type=" | grep "kvm"

echo "== Run a job that should pass: run.sh"
passing_job=$(mktemp)
cat > "$passing_job" <<'EOF'
set -e
[ "$(whoami)" = "gitlab-runner" ]
[ "$(systemd-detect-virt)" = "kvm" ]
. /etc/os-release
echo "$PRETTY_NAME"
[ "$VERSION_CODENAME" = "trixie" ]
sudo -n true
terraform version
gitlab-runner --version
git --version
git lfs version
EOF
/opt/libvirt-driver/run.sh "$passing_job"

echo "== Run a job that should fail: run.sh"
failing_job=$(mktemp)
echo "exit 3" > "$failing_job"
exit_code=0
/opt/libvirt-driver/run.sh "$failing_job" || exit_code=$?
if [ "$exit_code" -ne "$BUILD_FAILURE_EXIT_CODE" ]; then
    echo "Expected exit code $BUILD_FAILURE_EXIT_CODE from the failing job, got $exit_code."
    show_state
    exit 1
fi

echo "== Remove the job VM: cleanup.sh"
/opt/libvirt-driver/cleanup.sh

echo "== Is everything gone, except the base image?"
if virsh dominfo "$VM_ID" >/dev/null 2>&1; then
    echo "The job VM is still there."
    show_state
    exit 1
fi
if [ -f "$IMAGES/$VM_ID.qcow2" ]; then
    echo "The job VM's disk is still there."
    exit 1
fi
if [ ! -f "$IMAGES/gitlab-runner-base.qcow2" ]; then
    echo "The base image is gone."
    exit 1
fi

echo "== vm-test passed."
