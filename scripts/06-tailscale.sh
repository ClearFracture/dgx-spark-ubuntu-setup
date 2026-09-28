#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || { echo 'Requires Ubuntu 24.04.' >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo 'Requires Ubuntu ARM64.' >&2; exit 1; }

sudo -v
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg |
  sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list |
  sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt-get update
sudo apt-get install -y tailscale
sudo systemctl enable --now tailscaled
tailscale version

echo
echo 'Tailscale is installed. Join the approved tailnet with: sudo tailscale up'
echo 'Authenticate using the URL it prints, then check: tailscale status'
