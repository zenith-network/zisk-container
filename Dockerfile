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
ARG ZISK_VERSION=0.12.0
ARG CUDA_ARCH=sm_89
ARG CACHE_BUSTER=123

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
# Zisk Installation via ziskup
# -----------------------------------------------------------------------------
# NOTE: Cache buster can be incremented to force Zisk update
RUN echo "cache-buster-${CACHE_BUSTER}" && \
    curl -sSf https://raw.githubusercontent.com/0xPolygonHermez/zisk/main/ziskup/install.sh | \
    SETUP_KEY=proving bash -s -- --nokey

# Verify Zisk toolchain installation (includes riscv64ima-zisk-zkvm target)
RUN rustup toolchain list && \
    rustup toolchain list | grep -q zisk || \
    (echo "ERROR: zisk toolchain not found after installation" && exit 1)

# -----------------------------------------------------------------------------
# Custom Zisk Build with GPU Support
# -----------------------------------------------------------------------------
WORKDIR /build

# Clone Zisk source code.
RUN git clone --depth 1 --branch v${ZISK_VERSION} \
    https://github.com/0xPolygonHermez/zisk.git

WORKDIR /build/zisk

# Copy and apply custom patch
COPY distributed-input.patch .
RUN git apply distributed-input.patch && \
    echo "Applied distributed-input.patch successfully"

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
