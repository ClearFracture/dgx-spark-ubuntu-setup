DGX SPARK / STOCK UBUNTU 24.04 ARM64 / NVIDIA STACK / VLLM
Reviewed against NVIDIA documentation on 2026-09-28.

The scripts require network access to approved Ubuntu, NVIDIA, Docker, and
Hugging Face endpoints. They do not contain the OS installer, packages,
container image, model weights, or credentials. Do not store secrets on this USB.

After Ubuntu is installed, place the six shell scripts from this repository in
$HOME/dgx-spark-setup. The repository files are not the bootable Ubuntu
installer. Choose one transfer method:

GitHub, if approved network access and Git are available on the Spark:

  git clone https://github.com/ClearFracture/dgx-spark-ubuntu-setup.git "$HOME/dgx-spark-source"
  mkdir -p "$HOME/dgx-spark-setup"
  cp -a "$HOME/dgx-spark-source/scripts/." "$HOME/dgx-spark-setup/"

Data USB, after copying this repository's scripts directory to a USB labeled
DGXSETUP on another computer. Use a separate USB or reformat the installer
USB after Ubuntu is installed; formatting erases the installer image. Run
scripts with `bash` because data USB filesystems may not preserve executable
bits.

  lsblk -f
  usb_root="/media/$USER/DGXSETUP"
  if [[ ! -d "$usb_root/scripts" ]]; then
    sudo mkdir -p /mnt/dgxsetup
    sudo mount -L DGXSETUP /mnt/dgxsetup
    usb_root=/mnt/dgxsetup
  fi
  mkdir -p "$HOME/dgx-spark-setup"
  cp -a "$usb_root/scripts/." "$HOME/dgx-spark-setup/"
  if [[ "$usb_root" == /mnt/dgxsetup ]]; then sudo umount /mnt/dgxsetup; fi

If Git is missing and the client permits installing it, run
`sudo apt-get update && sudo apt-get install -y git` before cloning. If
mounting fails, check the USB label and mount point with `lsblk -f`.

  cd "$HOME/dgx-spark-setup"

Run the base and driver stages as your regular login user (not a root shell):

  bash 01-dgx-base.sh
  sudo reboot
  cd "$HOME/dgx-spark-setup" && bash 02-gpu-driver.sh
  sudo reboot

Before Docker and model downloads, inspect the root filesystem and LVM layout:

  lsblk -f
  df -hT /
  sudo lvs

On the lab Spark, Ubuntu allocated only 100 GiB to / on a 4 TB LVM
partition. If the client wants the whole volume group for /, and the LV
name and ext4 filesystem match, expand it before pulling model weights:

  sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
  df -hT /

Do not use that LV path without checking the new system's layout and
client storage policy. Continue with Docker and vLLM:

  cd "$HOME/dgx-spark-setup" && bash 03-docker-gpu.sh
  bash 04-nemotron-vllm.sh
  sudo docker logs -f nemotron-lightning
  bash 05-check-vllm.sh

If the client approved Tailscale, install it after validating the base
stack, then sign the Spark into the intended tailnet in a browser:

  bash 06-tailscale.sh
  sudo tailscale up
  tailscale status

The Tailscale installer does not contain login credentials. If the first
login URL fails and the host remains in NeedsLogin, stop the waiting command
with Ctrl+C and run `sudo tailscale up --force-reauth` for a fresh URL.
See the full runbook for account provisioning and STIG assessment steps.

Use Ctrl+C to leave docker logs; that does not stop the container.
The model API listens on 127.0.0.1:8000 only.
To stop: sudo docker stop nemotron-lightning
To restart: sudo docker start nemotron-lightning

The model and DSpark draft weights use the OpenMDW 1.1 license. Have the
client review it before downloading or deploying them:
https://openmdw.ai/license/1-1/

01 changes APT repositories, updates packages, installs the NVIDIA kernel
and DGX packages. 02 installs the release 580 open driver and Spark desktop
packages. 03 installs and validates Docker GPU access. 04 pulls a vLLM image
and downloads model weights on first start. Review package prompts before
accepting them. The scripts do not reformat the Spark's internal SSD.

Observed on the local stock Ubuntu 24.04.5 Spark: the NVIDIA repository
archive supplied BaseOS /8/ URLs for Noble that returned HTTP 404. Script
01 corrects those two source files to NVIDIA's working unversioned Noble
repository path before updating APT. The NVIDIA driver, Docker GPU test,
vLLM health endpoint, and a short Nemotron completion all passed locally.
The first vLLM start took about 14 minutes and downloaded about 22 GB of
checkpoints. Revalidate repository paths when repeating the installation;
see the full runbook for evidence and later findings.

Official references:
https://docs.nvidia.com/dgx/dgx-os-7-user-guide/installing_on_ubuntu.html
https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
https://build.nvidia.com/spark/vllm/instructions
