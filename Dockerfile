# =============================================================================
# Zisk Docker Image with GPU Support
# =============================================================================
# This Dockerfile builds a custom ZisK build with GPU support.
# =============================================================================

FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

# -----------------------------------------------------------------------------
# Build Arguments
# -----------------------------------------------------------------------------
ARG DEBIAN_FRONTEND=noninteractive
# Currently at 7bfb2fbb8e3bb888a9dce5509f5f5bf75bf79d79.
ARG CUSTOM_ZISK_BRANCH=v0.14.0
ARG CUDA_ARCH=sm_89
ARG ZISK_PROVINGKEY_VERSION=0.14.0

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
ENV PATH=/root/.cargo/bin:/root/.zisk/bin:$PATH \
    CUDA_ARCH=${CUDA_ARCH} \
    RUST_VERSION=stable

# -----------------------------------------------------------------------------
# System Dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    clang \
    libclang-dev \
    nasm \
    # Development tools
    curl \
    git \
    jq \
    xz-utils \
    # Zisk dependencies
    qemu-system \
    libomp-dev \
    libgmp-dev \
    nlohmann-json3-dev \
    protobuf-compiler \
    libprotobuf-dev \
    uuid-dev \
    libgrpc++-dev \
    libsecp256k1-dev \
    libsodium-dev \
    libpqxx-dev \
    # MPI support
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Rust Installation
# -----------------------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal


# -----------------------------------------------------------------------------
# Custom Zisk Build with GPU Support
# -----------------------------------------------------------------------------
WORKDIR /build

# Clone Zisk repository at specific version
RUN git clone --depth 1 --branch ${CUSTOM_ZISK_BRANCH} \
    https://github.com/0xPolygonHermez/zisk.git

WORKDIR /build/zisk

# Increase witness size from 4GB to 6GB.
# NOTE: This is a workaround for large programs, like proving Ethereum block 23,592,050.
RUN sed -i 's/#define INITIAL_TRACE_SIZE (uint64_t)0x100000000/#define INITIAL_TRACE_SIZE (uint64_t)0x180000000/' emulator-asm/src/main.c

# Fix flaky build.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc-riscv64-unknown-elf

# Build Zisk with GPU features enabled
RUN ulimit -n 65536 && \
    cargo build --release --features gpu && \
    rm -rf target/release/build target/release/deps target/release/.fingerprint

# -----------------------------------------------------------------------------
# Install Zisk Binaries and Assets
# -----------------------------------------------------------------------------
# Install compiled binaries
RUN mkdir -p /root/.zisk/bin && \
    cp -t /root/.zisk/bin \
    target/release/cargo-zisk \
    target/release/ziskemu \
    target/release/riscv2zisk \
    target/release/zisk-coordinator \
    target/release/zisk-worker \
    target/release/libzisk_witness.so \
    target/release/libziskclib.a

# Install assembly ROM and library files
RUN mkdir -p /root/.zisk/zisk/emulator-asm && \
    cp -r emulator-asm/src /root/.zisk/zisk/emulator-asm/ && \
    cp emulator-asm/Makefile /root/.zisk/zisk/emulator-asm/ && \
    cp -r lib-c /root/.zisk/zisk/

# -----------------------------------------------------------------------------
# Install SDK Toolchain and Proving Key
# -----------------------------------------------------------------------------
# Install SDK toolchain using the compiled cargo-zisk binary
RUN cargo-zisk sdk install-toolchain

# Verify Zisk toolchain installation (includes riscv64ima-zisk-zkvm target)
RUN rustup toolchain list && \
    rustup toolchain list | grep -q zisk || \
    (echo "ERROR: zisk toolchain not found after installation" && exit 1)

# Download and extract proving key
ARG ZISK_PROVINGKEY_VERSION
RUN curl -L "https://storage.googleapis.com/zisk-setup/zisk-provingkey-${ZISK_PROVINGKEY_VERSION}.tar.gz" | \
    tar -xz -C /root/.zisk

# Clean up build artifacts to reduce image size
WORKDIR /
RUN rm -rf /build

# -----------------------------------------------------------------------------
# Runtime Configuration
# -----------------------------------------------------------------------------
# Override NVIDIA CUDA entrypoint to allow direct command execution
ENTRYPOINT []

# Default command displays Zisk version
CMD ["cargo-zisk", "--version"]
