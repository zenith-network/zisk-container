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
