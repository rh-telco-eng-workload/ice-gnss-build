#!/bin/bash
set -eu

# Download the DDP package
rm -rf /var/lib/firmware/intel/ice/ddp || true
mkdir -p /var/lib/firmware/intel/ice/ddp || true
cd /var/lib/firmware/intel/ice/ddp/
cp /ddp/*.pkg . || true
ln -sf ice*.pkg ice.pkg || true

# unload in-tree driver
rmmod irdma || true
rmmod ice || true

# load out-of-tree driver
modprobe -d /opt ice

echo "Loaded out-of-tree ICE"
lsmod | grep ice || true
