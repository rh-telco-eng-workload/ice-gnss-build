#!/bin/bash
set -eu

ETH=$(grep 000e /sys/class/net/*/device/subsystem_device | awk -F"/" '{print $5}' | head -n 1)

echo 0 2 > /sys/class/net/$ETH/device/ptp/ptp*/pins/U.FL2
echo 0 1 > /sys/class/net/$ETH/device/ptp/ptp*/pins/U.FL1
echo 0 2 > /sys/class/net/$ETH/device/ptp/ptp*/pins/SMA2
echo 0 1 > /sys/class/net/$ETH/device/ptp/ptp*/pins/SMA1

echo "Disabled all SMA and U.FL Connections"

# Set the following variables only if you want to have a dual-NIC setup
# where one of the NICs receives the GPS signal via GNSS, and transfers
# the 1-PPS signal to the other NIC
# TX_PORT is the port in NIC_WITH_GNSS that will send the 1PPS signal
# RX_PORT is the port in NIC_WITHOUT_GNSS that will receive the 1 PPS signal
# If the variables are undefined, nothing will happen
# Refer to the Intel Ethernet Network Adapter User Guide for details on the
# echo commands

# Example values

# NIC_WITH_GNSS="ens4f0"
# NIC_WITHOUT_GNSS="ens2f0"
# TX_PORT="SMA1"
# RX_PORT="SMA1"

NIC_WITH_GNSS="ens4f0"
NIC_WITHOUT_GNSS="ens2f0"
TX_PORT="SMA1"
RX_PORT="SMA1"

if [ ! -z "${NIC_WITH_GNSS}" ]; then
    echo 2 1 > /sys/class/net/${NIC_WITH_GNSS}/device/ptp/ptp*/pins/${TX_PORT}
fi
if [ ! -z "${NIC_WITHOUT_GNSS}" ]; then
    echo 1 1 > /sys/class/net/${NIC_WITHOUT_GNSS}/device/ptp/ptp*/pins/${RX_PORT}
fi
