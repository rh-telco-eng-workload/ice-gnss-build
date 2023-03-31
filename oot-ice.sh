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
    usage: $(basename $0) [-h] [-o] [-r] [-f <filename>] <ice_vers>

    The environment variable REGISTRY must be set.
    This is the registry that the driver container will be pushed to.

    Build the Intel out of tree ice driver for Redhat OCP
      -h: Print this help.
      -o: Use this specific OCP version.
          This option must be given if the KUBECONFIG env variable is not set
          or an OCP version other than the KUBECONFIG cluster version is desired.
      -r: Build the RT version of the OCP kernel.
      -f: Specify a local path to the ice driver tarball, instead of downloading
          it from a public location. The file must be present in this directory.
END_OF_HELP
}

build_image () {
  BASE_IMAGE='registry.access.redhat.com/ubi8-minimal:latest'
  TAG=${KERNEL_VER}
  DTK_IMAGE=$(oc adm release info --image-for=driver-toolkit quay.io/openshift-release-dev/ocp-release:${OCP_VER}-x86_64)
  echo "Building for kernel:${KERNEL_VER} on OCP:${OCP_VER}"
  echo "DTKI for OCP:${OCP_VER} : ${DTK_IMAGE}"

  if [ -z $DRIVER_TARBALL ]; then
    DOCKERFILE=Dockerfile
  else
    DOCKERFILE=Dockerfile.local
  fi

  podman build -f $DOCKERFILE --no-cache . \
    --build-arg IMAGE=${BASE_IMAGE} \
    --build-arg BUILD_IMAGE=${DTK_IMAGE} \
    --build-arg DRIVER_VER=${DRIVER_VER} \
    --build-arg DRIVER_TARBALL=${DRIVER_TARBALL} \
    --build-arg KERNEL_VERSION=${KERNEL_VER} \
    -t ${REGISTRY}/${DRIVER_IMAGE}:${TAG}
  exit_on_error $?

}

push_image () {
  podman push --tls-verify=false ${REGISTRY}/${DRIVER_IMAGE}:${TAG}
  exit_on_error $?
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
          Wants=network-online.target
          After=network-online.target
          # Also after docker.service (no effect on systems without docker)
          After=docker.service
          # Before kubelet.service (no effect on systems without kubernetes)
          Before=kubelet.service

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
KERNEL_VER=""
BUILD_RT="no"
OCP_VER=""
DRIVER_TARBALL=""
KUBECONFIG=${KUBECONFIG:-""}

REGISTRY=${REGISTRY:-""}
if [ -z ${REGISTRY} ]; then
   echo "The environment variable REGISTRY must be set."
   exit 1
fi

while getopts hro:f: ARG ; do
  case $ARG in
    o ) OCP_VER=$OPTARG ;;
    r ) BUILD_RT="yes" ;;
    f ) DRIVER_TARBALL=$OPTARG ;;
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

# Try to get the OCP version from the cluster in KUBECONFIG
if [ -z ${OCP_VER} ]; then
  if [ -z ${KUBECONFIG} ]; then
    echo "Please specify -o or properly set your KUBECONFIG env variable"
    exit 1
  fi
  OCP_VER=$(oc get clusterversions/version -o json  | jq -r ".status.desired.version")
  exit_on_error $?
fi


DRIVER_IMAGE="ice-gnss-${DRIVER_VER}"

# Building for an OCP kernel.
if [ ${BUILD_RT} == "yes" ]; then
    MACHINE_OS=$(oc adm release info --image-for=machine-os-content quay.io/openshift-release-dev/ocp-release:${OCP_VER}-x86_64)
    KERNEL_VER=$(oc image info -o json ${MACHINE_OS}  | jq -r ".config.config.Labels[\"com.coreos.rpm.kernel-rt-core\"]")
else
    # We need different command lines for pre-4.12 and 4.12.x
    if [ $(echo -e "4.12.0\n${OCP_VER}" | sort -V | head -n 1 ) == "4.12.0" ]; then
        MACHINE_OS=$(oc adm release info --image-for=rhel-coreos-8 quay.io/openshift-release-dev/ocp-release:${OCP_VER}-x86_64)
        KERNEL_VER=$(oc image info -o json ${MACHINE_OS}  | jq -r ".config.config.Labels[\"ostree.linux\"]")
    else
        MACHINE_OS=$(oc adm release info --image-for=machine-os-content quay.io/openshift-release-dev/ocp-release:${OCP_VER}-x86_64)
        KERNEL_VER=$(oc image info -o json ${MACHINE_OS}  | jq -r ".config.config.Labels[\"com.coreos.rpm.kernel\"]")
    fi
fi

build_image

generate_machine_config

push_image
