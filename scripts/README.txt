DGX SPARK / STOCK UBUNTU 24.04 ARM64 / NVIDIA STACK / VLLM
Reviewed against NVIDIA documentation on 2026-09-27.

The scripts require network access to approved Ubuntu, NVIDIA, Docker, and
Hugging Face endpoints. They do not contain the OS installer, packages,
container image, model weights, or credentials. Do not store secrets on this USB.

On the Spark's Ubuntu Server terminal, the USB may auto-mount at
/media/$USER/DGXSETUP. If it does not, mount it by its DGXSETUP label.
Copy this folder to your home directory, then unmount it. Run the scripts
from the copy. The USB filesystem does not provide Linux executable bits.

  lsblk -f
  sudo mkdir -p /mnt/dgxsetup
  sudo mount -L DGXSETUP /mnt/dgxsetup  # Skip if already mounted under /media/$USER/DGXSETUP
  cp -a /mnt/dgxsetup/dgx-spark-setup "$HOME/"  # Use /media/$USER/DGXSETUP if auto-mounted
  sudo umount /mnt/dgxsetup  # Skip if auto-mounted
  cd "$HOME/dgx-spark-setup"

If mounting fails, check that the USB is present with: lsblk -f

Run in this order, as your regular login user (not a root shell):

  bash 01-dgx-base.sh
  sudo reboot
  cd "$HOME/dgx-spark-setup" && bash 02-gpu-driver.sh
  sudo reboot
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

If Ubuntu allocated only 100 GiB to / on a 4 TB LVM partition, inspect
`lsblk` and `df -hT /`. If the client wants the whole LVM volume group for
the root filesystem, expand it before pulling model weights:

  sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
  df -hT /

Check the LV name and client storage policy before using that command.

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
