#!/usr/bin/env bash

# Tests opt/libvirt-driver/cleanup.sh without a real VM. A fake "virsh" writes down
# every command it's given, so we can check that the script stops the VM before it
# deletes the disk.
#
#   scripts/test-cleanup.sh

cd "$(dirname "$0")/.." || exit 1

# Everything happens in a temporary folder, which is removed at the end.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/driver" "$work/images"

# Use copies of the real scripts, with the disk's folder pointed at the temporary one.
cp opt/libvirt-driver/cleanup.sh "$work/driver/"
sed "s|/var/lib/libvirt/images|$work/images|" opt/libvirt-driver/base.sh > "$work/driver/base.sh"

# The fake virsh. These settings change how it behaves in each test:
#   DESTROY_EXIT  the exit code of "virsh destroy"
#   STOP_AFTER    how many times "virsh domstate" says "running" before "shut off"
#   NO_VM         if set, "virsh domstate" prints nothing, because the VM is gone
#   NEEDS_NVRAM   if set, "virsh undefine" fails without --nvram
cat > "$work/bin/virsh" <<'EOF'
#!/usr/bin/env bash
echo "virsh $*" >> "$LOG"
if [ ! -f "$DISK" ]; then
    echo "THE DISK WAS DELETED BEFORE THIS COMMAND" >> "$LOG"
fi
case "$1" in
    destroy)
        exit "${DESTROY_EXIT:-0}"
        ;;
    domstate)
        if [ -n "$NO_VM" ]; then
            exit 1
        fi
        if [ "$(grep -c domstate "$LOG")" -le "${STOP_AFTER:-0}" ]; then
            echo "running"
        else
            echo "shut off"
        fi
        ;;
    undefine)
        if [ -n "$NO_VM" ]; then
            exit 1
        fi
        if [ -n "$NEEDS_NVRAM" ] && [ "$3" != "--nvram" ]; then
            exit 1
        fi
        ;;
esac
EOF

# A fake sleep, so the test that waits 300 times finishes right away.
printf '#!/usr/bin/env bash\n' > "$work/bin/sleep"
chmod +x "$work/bin/virsh" "$work/bin/sleep"

# The names cleanup.sh builds from GitLab's variables, and where the fakes look for them.
vm="runner-1-project-2-concurrent-3-job-4"
export CUSTOM_ENV_CI_RUNNER_ID=1 CUSTOM_ENV_CI_PROJECT_ID=2 CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID=3 CUSTOM_ENV_CI_JOB_ID=4
export SYSTEM_FAILURE_EXIT_CODE=42
export LOG="$work/virsh.log"
export DISK="$work/images/$vm.qcow2"

failed=0

# Each test starts with a disk and an empty log, then runs cleanup.sh.
run_cleanup() {
    echo "== $1"
    : > "$LOG"
    touch "$DISK"
    PATH="$work/bin:$PATH" "$work/driver/cleanup.sh" >/dev/null 2>&1
    exit_code=$?
}

problem() {
    echo "  FAILED: $1"
    echo "  virsh was asked to run:"
    sed 's/^/    /' "$LOG"
    failed=1
}

expect_exit_code() {
    if [ "$exit_code" -ne "$1" ]; then
        problem "expected exit code $1, got $exit_code"
    fi
}

expect_in_log() {
    if ! grep -q -- "$1" "$LOG"; then
        problem "expected '$1'"
    fi
}

expect_not_in_log() {
    if grep -q -- "$1" "$LOG"; then
        problem "didn't expect '$1'"
    fi
}

expect_disk_deleted() {
    if [ -f "$DISK" ]; then
        problem "expected the disk to be deleted"
    fi
}

expect_disk_kept() {
    if [ ! -f "$DISK" ]; then
        problem "expected the disk to be kept"
    fi
}

run_cleanup "A VM that stops right away"
expect_exit_code 0
expect_in_log "virsh destroy $vm"
expect_in_log "virsh undefine $vm"
expect_not_in_log "THE DISK WAS DELETED"
expect_disk_deleted

STOP_AFTER=3
export STOP_AFTER
run_cleanup "A VM that takes a while to stop"
expect_exit_code 0
expect_in_log "virsh undefine $vm"
expect_not_in_log "THE DISK WAS DELETED"
expect_disk_deleted
unset STOP_AFTER

STOP_AFTER=1000
export STOP_AFTER
run_cleanup "A VM that never stops: fail, and keep the disk"
expect_exit_code 42
expect_not_in_log "virsh undefine"
expect_disk_kept
unset STOP_AFTER

DESTROY_EXIT=1
export DESTROY_EXIT
run_cleanup "A VM that's already off: destroy fails, and cleanup carries on"
expect_exit_code 0
expect_in_log "virsh undefine $vm"
expect_disk_deleted
unset DESTROY_EXIT

DESTROY_EXIT=1 NO_VM=yes
export DESTROY_EXIT NO_VM
run_cleanup "No VM at all, only a disk, as when prepare.sh fails early"
expect_exit_code 0
expect_not_in_log "virsh undefine"
expect_disk_deleted
unset DESTROY_EXIT NO_VM

NEEDS_NVRAM=yes
export NEEDS_NVRAM
run_cleanup "A VM with UEFI firmware: undefine needs --nvram"
expect_exit_code 0
expect_in_log "virsh undefine $vm --nvram"
expect_disk_deleted
unset NEEDS_NVRAM

if [ "$failed" -ne 0 ]; then
    echo "The cleanup tests FAILED."
    exit 1
fi

echo "The cleanup tests passed."
