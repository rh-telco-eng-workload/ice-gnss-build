#!/bin/bash

set -eu

exit_on_error () {
  local rc="$1"

  if [[ $rc -ne 0 ]]; then
    echo "ERROR: $rc"
    exit $rc
  fi
}

print_usage () {
cat <<- END_OF_HELP
    usage: $(basename $0) [-h] <ice_vers>

    The environment variable REGISTRY must be set.
    This is the registry that the driver container has been pushed to.

    Create the MachineConfig resource for the Intel out of tree ice driver and GNSS module for Redhat OCP
      -h: Print this help.

END_OF_HELP
}

generate_machine_config () {

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  local service=$(base64 -w 0 service.sh)
  local ptp_config=$(base64 -w 0 ptp-config.sh)
elif [[ "$OSTYPE" == "darwin"* ]]; then
  local service=$(base64 -i service.sh)
  local ptp_config=$(base64 -i ptp-config.sh)
fi

cat <<- END_OF_MACHINE_CONFIG > mc-oot-ice-gnss.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 10-oot-ice-gnss
spec:
  config:
    ignition:
     version: 3.2.0
    storage:
      files:
        - contents:
            source: 'data:text/plain;charset=us-ascii;base64,$service'
          filesystem: root
          mode: 493
          path: /usr/local/bin/oot-ice
        - contents:
            source: 'data:text/plain;charset=us-ascii;base64,$ptp_config'
          filesystem: root
          mode: 493
          path: /usr/local/bin/ptp-config
    systemd:
      units:
      - contents: |
          [Unit]
          Description=out-of-tree driver loader
          # Start after the network is up
          After=NetworkManager-wait-online.service openvswitch.service network.service nodeip-configuration.service
          # Also after docker.service (no effect on systems without docker)
          After=docker.service
          # Before kubelet.service (no effect on systems without kubernetes)
          Before=kubelet.service ovs-configuration.service

          [Service]
          Type=oneshot
          RemainAfterExit=true
          # Use bash to workaround https://github.com/coreos/rpm-ostree/issues/1936
          ExecStart=/usr/bin/bash -c "/usr/local/bin/oot-ice load  ${REGISTRY}/${DRIVER_IMAGE}"
          ExecStop=/usr/bin/bash -c "/usr/local/bin/oot-ice unload ${REGISTRY}/${DRIVER_IMAGE}"
          ExecStartPost=/usr/bin/bash -c "/usr/local/bin/ptp-config"
          StandardOutput=journal+console

          [Install]
          WantedBy=default.target
        enabled: true
        name: "oot-ice.service"
  kernelArguments:
    - firmware_class.path=/var/lib/firmware
END_OF_MACHINE_CONFIG
}

# Default values

REGISTRY=${REGISTRY:-""}
if [ -z ${REGISTRY} ]; then
   echo "The environment variable REGISTRY must be set."
   exit 1
fi

while getopts h ARG ; do
  case $ARG in
    h ) print_usage ; exit 0 ;;
    ? ) print_usage ; exit 1 ;;
  esac
done
shift $(($OPTIND - 1))

if [ $# -lt 1 ]; then
  print_usage
  exit 1
fi
DRIVER_VER=$1; shift

DRIVER_IMAGE="ice-gnss-${DRIVER_VER}"

generate_machine_config
