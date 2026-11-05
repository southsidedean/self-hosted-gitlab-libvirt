#!/usr/bin/env bash

# Runs the checks every pull request has to pass. GitHub runs this same script,
# so you can run it yourself before you push:
#
#   scripts/check.sh
#
# You need shellcheck, actionlint, and zizmor installed. A missing tool counts
# as a failed check.

# Start from the top of the repository, wherever this was run from.
cd "$(dirname "$0")/.." || exit 1

# Every check runs, even after one fails, so you see all the problems at once.
failed=0

echo "== shellcheck: mistakes in the bash scripts"
if ! shellcheck -x --severity=warning install-libvirt-driver.sh runner-builder.sh opt/libvirt-driver/*.sh scripts/*.sh; then
  failed=1
fi

echo "== actionlint: mistakes in the workflows"
if ! actionlint; then
  failed=1
fi

echo "== zizmor: security problems in the workflows"
if ! zizmor --offline --min-severity medium .github/workflows; then
  failed=1
fi

echo "== config: the 'iconcurrent' typo stays gone"
if grep -n "iconcurrent" config.example.toml README.md; then
  echo "The setting is called 'concurrent'."
  failed=1
fi

echo "== tests: cleanup.sh stops the VM before it deletes the disk"
if ! scripts/test-cleanup.sh; then
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  echo "Some checks FAILED. See above."
  exit 1
fi

echo "All checks passed."
