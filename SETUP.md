# DGX Spark: Ubuntu 24.04, Docker, vLLM, and Nemotron 3.5 Lightning

Checked against Canonical and NVIDIA documentation on 2026-09-27. This runbook is for installing **Canonical Ubuntu 24.04 ARM64 Server first**, then NVIDIA's DGX software stack, Docker, and vLLM on an NVIDIA DGX Spark (GB10). It assumes an approved network connection to Ubuntu/NVIDIA repositories. For a disconnected client network, arrange an approved mirror and container/model transfer using NVIDIA's [air-gapped guidance](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/appendix_e_air_gapped_installations.html).

**Local validation completed.** The Ubuntu `24.04.5` ARM64 Server ISO came from [Canonical's release directory](https://cdimages.ubuntu.com/ubuntu/releases/24.04/release/), SHA-256 `f12484464c7d4d73e2167e0a7dbda1e669f8fae9bcf778dc0944937034b320cb` (matching [Canonical's SHA256SUMS](https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/SHA256SUMS)). The Spark failed to find the live filesystem with the default GRUB entry; selecting **Ubuntu Server with the HWE kernel** allowed the stock Ubuntu install. The DGX stack, Docker GPU test, and Nemotron vLLM sample completion then succeeded. The numbered scripts are in [scripts](scripts/README.txt) and were copied to the Spark's home directory.

NVIDIA's [custom Ubuntu + DGX stack guide](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/installing_on_ubuntu.html) describes this installation sequence and lists Spark-specific packages. Its generic prerequisites say Ubuntu 24.04 and kernel 6.8, while recent Spark releases use an NVIDIA kernel. If the installer cannot boot, see the internal SSD, or access a network, stop before changing partitions and check the exact image/kernel path with NVIDIA support. The client's compliance team must assess the final configuration against its actual controls; installing Ubuntu by itself does not prove FIPS, STIG, or other compliance.

## 1. Boot and install Ubuntu from confirmed compatible media

1. Back up data on the Spark. The Ubuntu install can erase the internal SSD. Disconnect other external storage, insert this USB, and connect a wired keyboard and display directly to the Spark.
2. Power on and press **Esc** or **Del** immediately for UEFI. Under **Save & Exit → Boot Override**, select the USB for a one-time boot. NVIDIA documents this [USB boot path](https://docs.nvidia.com/dgx/dgx-spark/uefi-settings.html#boot-from-a-usb-device). In the Ubuntu GRUB menu, press **Down once** to select **Ubuntu Server with the HWE kernel**, then press **Enter**. The default **Try or Install Ubuntu Server** entry already failed to locate the live filesystem on this Spark. If HWE also fails, stop before changing the internal SSD and report the error.
3. In the installer, confirm you are installing Ubuntu 24.04 on the **internal SSD**, identified by its model and capacity. Apply the client's encryption, partitioning, user, and network requirements. If the disk or network is missing, stop rather than guessing. Do not select Docker in the Featured Server Snaps screen; NVIDIA's DGX packages install Docker CE.
4. Reboot without the USB. Confirm `cat /etc/os-release` shows Ubuntu 24.04, `uname -m` is `aarch64`, and network connectivity to approved repositories works. The plain installer does not yet provide full GB10 GPU capability; install the DGX software below before testing `nvidia-smi`.

## 2. Install the DGX software stack

Follow the Spark-relevant sections of NVIDIA's [custom installation guide](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/installing_on_ubuntu.html) in order. As of this review, the core commands shown there are:

```bash
# On the newly installed Ubuntu ARM64 system; requires approved repository access.
test "$(dpkg --print-architecture)" = arm64
grep -q 'VERSION_ID="24.04"' /etc/os-release
curl -fsSL https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/dgx-repo-files.tgz -o /tmp/dgx-repo-files.tgz
sudo tar xzf /tmp/dgx-repo-files.tgz -C /
# On 2026-09-27 the archive pointed Noble at an HTTP 404 /baseos/8/ path.
# Correct both generated source files to NVIDIA's working unversioned Noble path.
sudo sed -i 's#https://repo.download.nvidia.com/baseos/8/ubuntu/noble/arm64/#https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/#g' \
  /etc/apt/sources.list.d/dgx.sources /etc/apt/sources.list.d/nvidia.sources
sudo apt update
sudo apt upgrade
sudo apt install nvidia-system-core nvidia-system-utils nvidia-system-extra
sudo apt install linux-nvidia-hwe-24.04 linux-tools-nvidia-hwe-24.04 nvidia-peermem-loader
sudo reboot
```

After reboot, confirm `uname -r` ends in `-nvidia` before installing the driver:

```bash
uname -r
sudo apt install nvidia-driver-pinning-580
sudo apt install nvidia-driver-580-open libnvidia-nscq nvidia-modprobe \
  nvidia-system-station datacenter-gpu-manager-4-cuda13 nv-persistence-mode
sudo systemctl enable nvidia-persistenced nvidia-dcgm
sudo reboot
```

The `linux-nvidia-hwe-24.04` package is [Canonical's non-64K NVIDIA kernel metapackage for Ubuntu 24.04 ARM64](https://packages.ubuntu.com/linux-nvidia-hwe-24.04). NVIDIA's generic ARM64 driver section instead shows a `linux-nvidia-64k-hwe-24.04` command for GB200/GB300; current [release notes](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html) distinguish Spark's `-nvidia` kernel from their `-nvidia-64k` kernel. Do not apply the generic 64K command to Spark. Do not install Fabric Manager or DOCA-OFED for a single Spark; NVIDIA's Spark-specific package selections omit them. The guide recommends disabling unattended upgrades, but use the client's patch policy instead of applying that recommendation automatically.

### Observed corrections on the local Spark

| Stage | Observed result | Reusable correction | Verification |
| --- | --- | --- | --- |
| Installer boot | The default `Try or Install Ubuntu Server` entry ended with `Unable to find a medium containing a live file system`. | Choose `Ubuntu Server with the HWE kernel` in Canonical's installer menu. | User completed the stock Ubuntu 24.04.5 installation; SSH shows `ID=ubuntu`, `VERSION_ID=24.04`, `arm64`. |
| DGX repository setup | NVIDIA's repository archive generated `dgx.sources` and `nvidia.sources` using `https://repo.download.nvidia.com/baseos/8/ubuntu/noble/arm64/`. Its Noble `Release` URL returned HTTP 404, leaving `nvidia-system-core` without an APT candidate. The first rerun also failed because those source files were already present before the script's initial APT update. | Replace that exact `/8/` URL in both generated source files **before the first APT update and again after extracting the archive**, then run `sudo apt update`. The numbered script does this so it also works after an interrupted run. | The unversioned Noble and Noble-updates `Release` URLs returned HTTP 200. Stage 01 then installed the DGX metapackages and Canonical's `7.0.0-1019-nvidia` kernel successfully. |
| DGX package prompt | During stage 01, `dgx-repo` asked whether to replace `/etc/apt/preferences.d/nvidia-dgx`. | Keep the current file by pressing **Enter** (default `N`) when the current file has the CUDA, DOCA, and HPC pinning rules from the repository archive; the proposed file observed here had only two Base OS rules. Reinspect both versions if NVIDIA changes the archive. | APT completed, `dpkg --audit` was empty, and `nvidia-system-core`, `nvidia-system-utils`, `nvidia-system-extra`, `linux-nvidia-hwe-24.04`, and `nvidia-peermem-loader` were installed. |
| Pre-reboot check | The NVIDIA kernel image appeared before its initramfs while APT was still running. | Wait for APT to finish; confirm both `/boot/vmlinuz-$(version)` and `/boot/initrd.img-$(version)` are nonempty before rebooting. | After stage 01 completed, `/boot/vmlinuz-7.0.0-1019-nvidia` was 21 MB and `/boot/initrd.img-7.0.0-1019-nvidia` was 76 MB. The Spark rebooted successfully into `7.0.0-1019-nvidia`. |
| Driver package selection | On 2026-09-27, APT selected NVIDIA's `nvidia-driver-580-open` and `nvidia-dkms-580-open` version `580.178.04-1ubuntu1` from the CUDA repository. Canonical's prebuilt `linux-modules-nvidia-580-open-nvidia-hwe-24.04` required a lower `nvidia-kernel-common-580` package version, so mixing those packages in one transaction failed. | Follow NVIDIA's documented R580 driver path in stage 02. The script verifies the built module for the running kernel and its initramfs before reboot. Stop if either check fails. | Stage 02 completed with no `dpkg --audit` findings. DKMS installed NVIDIA module `580.178.04` for `7.0.0-1019-nvidia` and `7.0.0-31-generic`; `modinfo` located the module for the running kernel, the 83 MB initramfs exists, and `nvidia-persistenced`/`nvidia-dcgm` are enabled. After reboot, `nvidia-smi` identified `NVIDIA GB10` with driver `580.178.04`. |
| Ubuntu storage allocation | The 4 TB Samsung NVMe (`nvme0n1`, 3.7 TiB in Linux) contains a 3.7 TiB LVM partition, but the installer made `ubuntu-vg/ubuntu-lv` only 100 GiB. `/` had 70 GiB available after stage 02. | For this installation, expand the root LV and ext4 filesystem online with `sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv`. Reconfirm the LV name, filesystem, and client storage policy before applying on another Spark. | `df -hT /` then showed ext4 `/` at 3.7 TiB with 3.5 TiB available, and `lsblk` showed `ubuntu--vg-ubuntu--lv` at 3.7 TiB. |
| SSH after reboot | The DHCP address changed after reboot. | Resolve the hostname or check the DHCP lease. Verify the SSH host key against the deployment record before accepting a new address. | SSH returned after reconnecting to the same verified host. |
| Docker GPU access | Docker CE `29.6.2`, NVIDIA Container Toolkit `1.20.1-1`, and `nv-docker-options` `25.05-1` were installed after stage 02; stage 03 confirmed the Docker service was active. | Run stage 03's CUDA container test and inspect its `nvidia-smi` output before deploying vLLM. | `nvcr.io/nvidia/cuda:12.6.2-base-ubuntu24.04` (digest `sha256:631ec7090c36ab846cf021073ff4a64fb9cffa90b4f9f0083799288c607073ce`) ran with `--gpus all` and reported NVIDIA GB10, driver `580.178.04`, CUDA `13.0`. |
| vLLM image and model startup | Stage 04 pulled `vllm/vllm-openai:v0.27.1` and created the `nemotron-lightning` container. The first start downloaded about 22 GB of checkpoint data, loaded 52 target shards and the DSpark draft, and compiled/tuned kernels; `/health` reset connections during this work. The log warned that FP4 uses weight-only Marlin on this GPU and that FP8 attention scaling may need quality validation. | Keep the image digest and model revisions in the handoff record. Wait for `/health` and a sample completion before claiming model readiness; inspect `sudo docker logs nemotron-lightning` if startup takes longer than expected. Validate output quality and latency on the client's workloads before production use. | Image digest: `sha256:0a51ea5b4ae2dc5d81890e5173f54203d2a3ae0cfffe51b8fd2afd4391bfd967`. After about 14 minutes from container start, `/health` returned HTTP 200. Stage 05 listed the target with `max_model_len` 1,048,576 and returned a complete greeting (`finish_reason: stop`). |

Recheck repository URLs and package candidates on the day of each client deployment; this workaround reflects the NVIDIA archive and endpoints observed on 2026-09-27.

## 3. Verify the host

On the Spark terminal after stages 01 and 02 and their reboots:

```bash
cat /etc/os-release
uname -m
uname -r
nvidia-smi
df -hT /
```

Expected: Ubuntu 24.04, `aarch64`/`arm64`, an `-nvidia` kernel, an NVIDIA GB10 visible in `nvidia-smi`, and the approved root filesystem size. Record OS, kernel, driver, and firmware versions. NVIDIA's Spark update guide targets DGX OS; check its applicability before using it on a customized Ubuntu installation.

## 4. Install/verify Docker GPU access

The NVIDIA system metapackages may already supply Docker CE and the container toolkit. Run the documented package command to ensure all three are present:

```bash
sudo apt install -y docker-ce nvidia-container-toolkit nv-docker-options
sudo systemctl restart docker
sudo docker version
sudo docker run --rm --gpus all nvcr.io/nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi
```

The final command downloads a validation image. Verify the GPU appears inside the container. If `docker-ce` has no candidate or the container fails, stop and check the configured NVIDIA repositories and [Docker/toolkit section](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/installing_on_ubuntu.html#installing-docker-and-the-nvidia-container-toolkit); do not install Docker Snap alongside it. Use `sudo docker` below so Docker group membership is unnecessary. Treat any user in the `docker` group as having root-equivalent host access.

## 5. Run Nemotron 3.5 Lightning with vLLM

NVIDIA's [model card](https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4) specifies the **NVFP4** target checkpoint, the **DSpark** draft checkpoint, a Spark-specific vLLM recipe, and image `vllm/vllm-openai:v0.27.1`. Review the [OpenMDW 1.1 model license](https://openmdw.ai/license/1-1/) for the client's intended use. The first start downloads both checkpoints and may take considerable time and disk space. Use an approved Hugging Face token only if required; do not store tokens on the USB or in shell history.

```bash
export MODEL_CKPT=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
export DSPARK_CKPT=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-DSpark
export VLLM_IMAGE=vllm/vllm-openai:v0.27.1
mkdir -p "$HOME/.cache/huggingface"
sudo docker pull "$VLLM_IMAGE"

sudo docker run -d \
  --name nemotron-lightning \
  --gpus all --ipc host \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  --entrypoint "" \
  -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  "$VLLM_IMAGE" \
  vllm serve --model "$MODEL_CKPT" \
    --moe-backend marlin \
    --kv-cache-dtype fp8 \
    --enable-prefix-caching \
    --gpu-memory-utilization 0.85 \
    --speculative_config.num_speculative_tokens 3 \
    --mamba-backend flashinfer \
    --mamba-cache-mode align \
    --reasoning-parser nemotron_v3 \
    --speculative_config.model "$DSPARK_CKPT" \
    --tool-call-parser qwen3_coder \
    --enable-auto-tool-choice

sudo docker logs -f nemotron-lightning
```

The port binds to localhost to avoid exposing an unauthenticated model API on the client network. For remote access, use an approved authenticated gateway or SSH tunnel. The model card says the recipe was validated up to 1M context on Spark; practical latency and concurrency still depend on the workload. If memory pressure prevents startup, lower context with `--max-model-len` after recording the failure and consult the model card before changing its other tuned flags. NVIDIA's [vLLM Spark guide](https://build.nvidia.com/spark/vllm/instructions) describes the Docker launch and health checks.

In another terminal, test readiness and a short answer:

```bash
curl -fsS http://127.0.0.1:8000/health
curl -fsS http://127.0.0.1:8000/v1/models
curl -fsS http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":512,"chat_template_kwargs":{"enable_thinking":false}}'
```

Check `choices[0].message.content` and `finish_reason`. The model can spend tokens on reasoning, so a response that ends at `max_tokens` needs a larger output budget or disabled thinking, as shown. Stop with `sudo docker stop nemotron-lightning`; restart with `sudo docker start nemotron-lightning`. The model cache remains under the launching user's `~/.cache/huggingface`.

## 6. Join an approved Tailscale network (optional)

On the local Spark, the [Tailscale Ubuntu 24.04 repository](https://pkgs.tailscale.com/stable/ubuntu/) installed Tailscale `1.102.4` using `06-tailscale.sh`. Run it from the copied setup directory, then authenticate the device with the intended organization's account:

```bash
cd "$HOME/dgx-spark-setup"
bash 06-tailscale.sh
sudo tailscale up
# Open the URL printed by tailscale up and approve the device in the correct tailnet.
tailscale status
tailscale ip -4
```

Confirm `tailscale status` lists the Spark as connected and verify it in the tailnet's Machines list. On this Spark, the first browser approval appeared in Machines, but the host stayed in `NeedsLogin` and the daemon logged `HTTP 410: auth path not found`. Pressing Ctrl+C in the waiting terminal and running `sudo tailscale up --force-reauth` generated a new login URL; approval of that URL brought the host to `Running`. Record the device's MagicDNS name and Tailscale IP from `tailscale status` after each reinstall. The vLLM API remains bound to `127.0.0.1:8000`; joining Tailscale does not publish that API.

## 7. Create client-approved accounts

Create each approved username without default sudo or Docker group membership. Set a separate random temporary password interactively, then expire it to require a change at first login. Do not put passwords in shell commands, the USB, or this repository.

```bash
new_user=replace_with_approved_username
sudo adduser --disabled-password --gecos '' "$new_user"
sudo passwd "$new_user"  # Enter the temporary password twice at hidden prompts.
sudo passwd --expire "$new_user"
sudo passwd -S "$new_user"
id -nG "$new_user"
```

Repeat for each user. Test first login before handoff. If using SSH, verify the approved authentication policy permits password login and password changes. Grant sudo access only when the client authorizes it with `sudo usermod -aG sudo "$new_user"`; the membership takes effect at the user's next login.

### Team access to the running model

The existing Docker container is named `nemotron-lightning`. After a reboot or manual stop, an operator on the Spark can run `sudo docker start nemotron-lightning`, then wait for `curl -fsS http://127.0.0.1:8000/health` to succeed. Do not rerun `04-nemotron-vllm.sh` while that named container exists. On the lab Spark, Docker was active, `/health` returned HTTP 200, the model appeared in `/v1/models`, and `05-check-vllm.sh` completed a sample reply with `finish_reason: stop`.

The container publishes port 8000 only on the Spark's loopback interface. A team member connected to the approved tailnet should first log in normally and change their expired temporary password. On subsequent connections, they can keep an SSH tunnel open in one terminal:

```bash
ssh -N -L 18000:127.0.0.1:8000 user@SPARK_TAILSCALE_IP
```

On that team member's computer, use `http://127.0.0.1:18000/v1` as the OpenAI-compatible API base URL, or verify with `curl -fsS http://127.0.0.1:18000/health`. Their device must be in the tailnet, and tailnet policy must allow SSH to the Spark.

## Security assessment

The [local Ubuntu 24.04 STIG baseline assessment](report/ASSESSMENT.md) was run before Tailscale and these accounts were added. OpenSCAP reported 85 failed rules, 59 passed, 91 not applicable, and 4 not checked. That scan is a gap assessment, not a compliance certification; rerun it after approved hardening changes and review applicable controls manually.

## Handoff record

Record the Spark serial/OEM, media image name and checksum, OS/kernel/driver versions, container image tag or digest, target and draft model revisions, license approval, and the `/health` and sample completion results. On this local Spark, target revision was `bee7596271d1495f6992ae224aefde4410e816b8` and DSpark revision was `8a0177116d138011e63103110f136ec0ca09ebbf`. The exact combination above passed a short local inference test; client compliance approval and workload validation are separate decisions.
