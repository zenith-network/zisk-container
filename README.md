# Zisk Docker

Docker image for Zisk pre-release v0.13 with GPU support, enhanced with input distribution over gRPC.

## Build

```bash
docker build -t zisk-docker .
```

## Run

```bash
# Check version
docker run --rm zisk-docker

# Run worker
docker run -it zisk-docker zisk-worker

# Run coordinator
docker run -it zisk-docker zisk-coordinator

# Interactive shell
docker run -it zisk-docker bash

# With GPU support
docker run --gpus all -it zisk-docker zisk-worker
```

## Proving Example

Firstly download test files:

```bash
wget https://github.com/0xPolygonHermez/zisk-ethproofs/raw/refs/heads/develop/bin/ethproofs-client/elf/zec-keccakf-k256-sha2-bn254.elf
wget https://github.com/0xPolygonHermez/zisk-eth-client/raw/refs/heads/main/inputs/22767493_185_14.bin
```

Then setup ROM and generate proof in the same container instance:

```bash
docker run --gpus all -v $(pwd):/data zisk-docker bash -c \
  "cargo-zisk rom-setup -e /data/zec-keccakf-k256-sha2-bn254.elf && \
   cargo-zisk prove -e /data/zec-keccakf-k256-sha2-bn254.elf -i /data/22767493_185_14.bin -o /tmp/out -a -u"
```
