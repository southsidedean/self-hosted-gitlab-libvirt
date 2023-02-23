#!/usr/bin/bash

# Script to install the libvirt-driver scripts for the GitLab runner
# Tom Dean
# 2/22/23

echo "Installing libvirt-driver scripts in /opt/libvirt-driver..."
mkdir -p /opt/libvirt-driver
cp opt/libvirt-driver/* /opt/libvirt-driver
chown -R root:root /opt/libvirt-driver
chmod 755 /opt/libvirt-driver/*.sh
exit 0
