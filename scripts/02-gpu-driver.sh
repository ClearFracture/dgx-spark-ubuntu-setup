#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || { echo 'Requires Ubuntu 24.04.' >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo 'Requires Ubuntu ARM64.' >&2; exit 1; }
[[ "$(uname -r)" == *-nvidia ]] || { echo "Boot the NVIDIA kernel before continuing. Current: $(uname -r)" >&2; exit 1; }

echo "Installing the Spark GPU driver on $(uname -r)"
sudo -v
sudo apt-get update
sudo apt-get install nvidia-driver-pinning-580
sudo apt-get install \
  nvidia-driver-580-open libnvidia-nscq nvidia-modprobe \
  nvidia-system-station datacenter-gpu-manager-4-cuda13 nv-persistence-mode
sudo systemctl enable nvidia-persistenced nvidia-dcgm

kernel="$(uname -r)"
[[ -d "/usr/src/linux-headers-${kernel}" ]] || { echo "Missing headers for ${kernel}. Do not reboot." >&2; exit 1; }
modinfo -k "$kernel" nvidia >/dev/null || { echo "NVIDIA module is missing for ${kernel}. Do not reboot." >&2; exit 1; }
[[ -s "/boot/initrd.img-${kernel}" ]] || { echo "Initramfs is missing for ${kernel}. Do not reboot." >&2; exit 1; }
echo "Verified NVIDIA module and initramfs for ${kernel}."

echo
echo 'GPU driver installed. Reboot the Spark now: sudo reboot'
echo 'After reboot, run: bash 03-docker-gpu.sh'
