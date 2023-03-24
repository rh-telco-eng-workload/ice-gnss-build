# ice-gnss-build

> ❗ _Red Hat does not provide commercial support for the content of this repo.
Any assistance is purely on a best-effort basis, as resource permits._

```bash
#############################################################################
DISCLAIMER: THE CONTENT OF THIS REPO IS EXPERIMENTAL AND PROVIDED **"AS-IS"**

THE CONTENT IS PROVIDED AS REFERENCE WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#############################################################################
```

Scripts to build an out of tree Intel ICE driver with GNSS support on OCP 4.12.

It builds the driver inside the Driver Toolkit image and pushes an image containing the kernel module to a registry.

This is based on the work originally done on https://github.com/RHsyseng/oot-ice, with changes to enable GNSS support
on ICE drivers starting from version 1.11.16.

### Prereq
- Set `REGISTRY` in your env. This is the registry the driver container will be pushed to and that the OCP cluster will pull the driver container from.
  In this sense, your default pull secret should be able to allow you to push to this registry on the build machine.
  Your cluster should also have the pull secret of this registry so that it can pull images from this registry.
- Set `KUBECONFIG` in your env.
  The OCP version of your `KUBECONFIG` cluster will be used to build the driver and it will be used to apply the generated MachineConfig


### SMA and U.FL ports

By default, the SMA and U.FL ports in any Intel Westport Channel or Logan Beach cards are disabled. If you want to change the configuration
of any port, edit file `ptp-config.sh` before running the script, and set the following environment variables:

- `NIC_WITH_GNSS`
- `NIC_WITHOUT_GNSS`
- `TX_PORT`
- `RX_PORT`

Read the script comments for more information on the required values.

### Build
The script supports building the ice driver against different kernels.

To build against the standard kernel of the OCP version of the cluster in `KUBECONFIG`
```bash
./oot-ice.sh <ice-driver-version>
```

To build against the real time kernel of the OCP version of the cluster in `KUBECONFIG`
```bash
./oot-ice.sh -r <ice-driver-version>
```

You can use the `-f filename.tar.gz` option to specify a local tarball to be used for the driver build, instead of
downloading it from SourceForge. Note that the file must be present in the local directory.

### Deploy

Once the build finishes successfully, a `MachineConfig` to deploy the driver container to the cluster is generated.
We can now apply this `MachineConfig` to deploy the driver.

```bash
oc apply -f mc-oot-ice-gnss.yaml
```
