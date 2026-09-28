#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || { echo 'Requires Ubuntu 24.04.' >&2; exit 1; }
[[ "$(uname -r)" == *-nvidia ]] || { echo 'Boot the NVIDIA kernel before continuing.' >&2; exit 1; }
command -v nvidia-smi >/dev/null || { echo 'NVIDIA driver is missing; run 02-gpu-driver.sh.' >&2; exit 1; }
nvidia-smi

sudo -v
sudo apt-get update
sudo apt-get install docker-ce nvidia-container-toolkit nv-docker-options
sudo systemctl restart docker
sudo docker version
sudo docker run --rm --gpus all nvcr.io/nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi

echo
echo 'Docker GPU access works. Next: bash 04-nemotron-vllm.sh'
