#!/bin/bash
set -e

ETH=$(grep -e 000e -e 000f /sys/class/net/*/device/subsystem_device | awk -F"/" '{print $5}')

for DEV in $ETH; do
  if [ -f /sys/class/net/$DEV/device/ptp/ptp*/pins/U.FL2 ]; then
    echo 0 2 > /sys/class/net/$DEV/device/ptp/ptp*/pins/U.FL2
    echo 0 1 > /sys/class/net/$DEV/device/ptp/ptp*/pins/U.FL1
    echo 0 2 > /sys/class/net/$DEV/device/ptp/ptp*/pins/SMA2
    echo 0 1 > /sys/class/net/$DEV/device/ptp/ptp*/pins/SMA1
  fi
done

echo "Disabled all SMA and U.FL Connections"

sleep 3

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

NIC_WITH_GNSS=""
NIC_WITHOUT_GNSS=""
TX_PORT=""
RX_PORT=""

if [ ! -z "${NIC_WITH_GNSS}" ]; then
    # Using the last character from the TX_PORT string allows us to have a single line for
    # both SMA1 and SMA2
    echo "2 ${TX_PORT: -1}" > /sys/class/net/${NIC_WITH_GNSS}/device/ptp/ptp*/pins/${TX_PORT}
fi
if [ ! -z "${NIC_WITHOUT_GNSS}" ]; then
    # Using the last character from the RX_PORT string allows us to have a single line for
    # both SMA1 and SMA2
    echo "1 ${RX_PORT: -1}" > /sys/class/net/${NIC_WITHOUT_GNSS}/device/ptp/ptp*/pins/${RX_PORT}
fi

# If you have a VLAN interface created via NMState or nmcli, and that interface
# is OVN's main interface, the configure-ovs.sh script may not find the main IP
# unless we manually start the interface after loading the out-of-tree driver
# Set the ICE_VLAN_INTERFACES environment variable with the VLAN interfaces you
# have defined (separated by blanks), so the script can ensure all of them are
# enabled

# Example values
# ICE_VLAN_INTERFACES=""
# ICE_VLAN_INTERFACES="ens1f1.100"
# ICE_VLAN_INTERFACES="ens1f1.100 ens1f1.200"

ICE_VLAN_INTERFACES=""

if [ ! -z "${ICE_VLAN_INTERFACES}" ]; then
    # Give some time after the driver has initialized all cards before reloading NetworkManager
    sleep 60
    nmcli connection reload
    for INTERFACE in ${ICE_VLAN_INTERFACES}; do
        echo "Re-enabling VLAN interface $INTERFACE"
        nmcli conn up $INTERFACE
    done
fi
