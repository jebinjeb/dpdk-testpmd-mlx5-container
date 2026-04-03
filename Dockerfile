# ==============================================
# Dockerfile: dpdk-testpmd with Mellanox mlx5 support
# Base: Rocky Linux 8.8
# ==============================================
FROM rockylinux:8.8

# ----------------------------------------------
# 1. Environment
# ----------------------------------------------
ENV LD_LIBRARY_PATH=/usr/lib64:/usr/local/lib64
ENV DPDK_VER=23.11.1
ENV PATH=/usr/local/bin:$PATH

# ----------------------------------------------
# 2. Install base dependencies
# ----------------------------------------------
RUN dnf clean all && \
    dnf -y install epel-release && \
    dnf -y install 'dnf-command(config-manager)' && \
    dnf config-manager --set-enabled powertools && \
    dnf -y install \
        wget tar xz pciutils pciutils-libs \
        gcc gcc-c++ make python3 python3-pip \
        numactl numactl-devel \
        libibverbs libibverbs-devel libmlx5 \
        rdma-core rdma-core-devel \
        infiniband-diags \
        hwloc hwloc-devel \
        libnl3 libnl3-devel \
        iproute \
        pkgconfig \
        tk tcl \
        perl \
        sudo && \
    dnf clean all && \
    pip3 install --upgrade pip && \
    pip3 install meson ninja pyelftools && \
    ln -sf /usr/local/bin/ninja /usr/bin/ninja && \
    ninja --version

# ----------------------------------------------
# 3. Install Mellanox OFED (user-space only)
# ----------------------------------------------
COPY MLNX_OFED_LINUX-24.10-4.1.4.0-rhel8.8-x86_64.tgz /tmp/mlnxofed.tgz
RUN cd /tmp && \
    tar -xf mlnxofed.tgz && \
    cd MLNX_OFED_LINUX-24.10-4.1.4.0-rhel8.8-x86_64 && \
    ./mlnxofedinstall \
        --dpdk \
        --user-space-only \
        --without-fw-update \
        --without-kernel-modules \
        --without-kmod \
        --force \
        --skip-distro-check && \
    ldconfig && \
    rm -rf /tmp/mlnxofed.tgz /tmp/MLNX_OFED_LINUX-24.10-4.1.4.0-rhel8.8-x86_64

# Verify mlx5 userspace lib
RUN ldconfig -p | grep mlx5 && \
    ldconfig -p | grep ibverbs

# ----------------------------------------------
# 4. Build DPDK with mlx5 PMD
# ----------------------------------------------
RUN wget https://fast.dpdk.org/rel/dpdk-${DPDK_VER}.tar.xz \
        -O /tmp/dpdk.tar.xz && \
    tar -xf /tmp/dpdk.tar.xz -C /tmp && \
    cd /tmp/dpdk-stable-${DPDK_VER} && \
    meson setup build \
        -Dplatform=native \
        -Denable_drivers=bus/auxiliary,common/mlx5,net/mlx5 \
        -Dexamples='' && \
    ninja -C build && \
    ninja -C build install && \
    ldconfig && \
    rm -rf /tmp/dpdk*

# Verify testpmd binary
RUN dpdk-testpmd -v --no-pci -- --help 2>&1 | head -5

# ----------------------------------------------
# 5. Hugepages mount point
# ----------------------------------------------
RUN mkdir -p /mnt/huge

# ----------------------------------------------
# 6. Working directory
# ----------------------------------------------
WORKDIR /root

# ----------------------------------------------
# 7. Entrypoint
# ----------------------------------------------
ENTRYPOINT ["/bin/bash"]

