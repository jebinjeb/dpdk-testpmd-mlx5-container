# dpdk-testpmd-mlx5-container

Container image for running `dpdk-testpmd` with Mellanox ConnectX-5 SR-IOV VF bandwidth testing in Kubernetes pods.

## Overview

This image provides a ready-to-use `dpdk-testpmd` environment built on Rocky Linux 8.8 with:
- DPDK 23.11.1 (LTS) compiled with `net/mlx5` PMD
- Mellanox OFED 24.10 userspace libraries (`libibverbs`, `libmlx5`)
- Supports both same-host (intra-node) and cross-host (inter-node) VF bandwidth testing

## Prerequisites

### Host Requirements
- Mellanox ConnectX-5 NIC with SR-IOV enabled
- VFs created and bound to `mlx5_core` (no `vfio-pci` needed)
- Hugepages allocated on host nodes
- `ib_uverbs` kernel module loaded
```bash
# Verify on host
lsmod | grep ib_uverbs
cat /proc/meminfo | grep HugePages_Total
```

## Pull Image

\```bash
docker pull ghcr.io/jebinjeb/dpdk-testpmd-mlx5-container:latest
\```


## Build Locally (requires MLNX OFED tarball)

### Files Required to Build
Download and place in the same directory as the Dockerfile: MLNX_OFED_LINUX-24.10-4.1.4.0-rhel8.8-x86_64.tgz

> OFED is excluded from git (see .gitignore) due to file size. Download from https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/

## Build
```bash
docker build -t dpdk-testpmd-mlx5:latest .
```

## Usage

### Run the container (same-host or cross-host)
```bash
docker run -it --privileged \
  -v /dev/hugepages:/dev/hugepages \
  -v /dev/infiniband:/dev/infiniband \
  -v /sys:/sys \
  dpdk-testpmd-mlx5:latest
```

### Inside the container — receiver pod
```bash
dpdk-testpmd -l 0-3 -n 4 \
  -a 0000:03:02.0 \
  -- --forward-mode=rxonly --stats-period=1
```

### Inside the container — sender pod
```bash
# Same host (no MAC needed)
dpdk-testpmd -l 0-3 -n 4 \
  -a 0000:03:02.0 \
  -- --forward-mode=txonly --stats-period=1

# Different host (dst MAC required)
dpdk-testpmd -l 0-3 -n 4 \
  -a 0000:03:02.0 \
  -- --forward-mode=txonly \
     --eth-peer=0,AA:BB:CC:DD:EE:FF \
     --stats-period=1
```

## Kubernetes Pod Spec
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dpdk-testpmd
spec:
  containers:
  - name: testpmd
    image: dpdk-testpmd-mlx5:latest
    securityContext:
      privileged: true
    resources:
      limits:
        hugepages-2Mi: 1Gi
        memory: 1Gi
        mellanox.com/mlnx_sriov_rdma: 1
    volumeMounts:
    - mountPath: /dev/hugepages
      name: hugepage
    - mountPath: /dev/infiniband
      name: uverbs
    - mountPath: /sys
      name: sys
  volumes:
  - name: hugepage
    emptyDir:
      medium: HugePages
  - name: uverbs
    hostPath:
      path: /dev/infiniband
  - name: sys
    hostPath:
      path: /sys
```

## Architecture

- **Same host**: testpmd generates/receives synthetic L2 frames via ConnectX-5 eSwitch — no IP or MAC needed
- **Different host**: only destination MAC of remote VF required — no IP, no ARP
- **Driver model**: Mellanox bifurcated PMD — VF stays on `mlx5_core`, DPDK uses it via `libibverbs`

## Tested With

| Component | Version |
|---|---|
| Base OS | Rocky Linux 8.8 |
| DPDK | 23.11.1 |
| MLNX OFED | 24.10-4.1.4.0 |
| NIC | Mellanox ConnectX-5 |
