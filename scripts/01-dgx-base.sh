#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || { echo 'Requires Ubuntu 24.04.' >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo 'Requires Ubuntu ARM64.' >&2; exit 1; }
[[ "$(uname -m)" == aarch64 ]] || { echo 'Requires an ARM64 host.' >&2; exit 1; }

echo "Ubuntu ${VERSION_ID}, kernel $(uname -r), architecture $(dpkg --print-architecture)"
sudo -v

# A previous interrupted run can leave the archive's broken /baseos/8/
# Noble URLs behind. Correct them before the first APT update as well.
fix_noble_repo_urls() {
  local source_file
  for source_file in /etc/apt/sources.list.d/dgx.sources /etc/apt/sources.list.d/nvidia.sources; do
    if [[ -f "$source_file" ]]; then
      sudo sed -i \
        's#https://repo.download.nvidia.com/baseos/8/ubuntu/noble/arm64/#https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/#g' \
        "$source_file"
    fi
  done
}

fix_noble_repo_urls
sudo apt-get update
sudo apt-get install ca-certificates curl

repo_archive="$(mktemp /tmp/dgx-repo-files.XXXXXX.tgz)"
trap 'rm -f "$repo_archive"' EXIT
curl -fsSL https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/dgx-repo-files.tgz -o "$repo_archive"
sudo tar -xzf "$repo_archive" -C /

# The freshly extracted archive reintroduces the broken URLs.
fix_noble_repo_urls

sudo apt-get update
sudo apt-get upgrade
sudo apt-get install \
  nvidia-system-core nvidia-system-utils nvidia-system-extra \
  linux-nvidia-hwe-24.04 linux-tools-nvidia-hwe-24.04 \
  nvidia-peermem-loader

echo
echo 'DGX base packages installed. Reboot the Spark now: sudo reboot'
echo 'After reboot, run: bash 02-gpu-driver.sh'
