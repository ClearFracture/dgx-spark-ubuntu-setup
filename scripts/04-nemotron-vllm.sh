#!/usr/bin/env bash
set -euo pipefail

model_ckpt=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
dspark_ckpt=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-DSpark
vllm_image=vllm/vllm-openai:v0.27.1
container_name=nemotron-lightning

sudo docker info >/dev/null
command -v nvidia-smi >/dev/null || { echo 'NVIDIA driver is missing.' >&2; exit 1; }
nvidia-smi >/dev/null
if sudo docker container inspect "$container_name" >/dev/null 2>&1; then
  echo "Container $container_name already exists. Inspect it with: sudo docker ps -a --filter name=$container_name" >&2
  exit 1
fi

mkdir -p "$HOME/.cache/huggingface"
sudo docker pull "$vllm_image"
sudo docker run -d \
  --name "$container_name" \
  --gpus all --ipc host \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  --entrypoint '' \
  -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  "$vllm_image" \
  vllm serve --model "$model_ckpt" \
    --moe-backend marlin \
    --kv-cache-dtype fp8 \
    --enable-prefix-caching \
    --gpu-memory-utilization 0.85 \
    --speculative_config.num_speculative_tokens 3 \
    --mamba-backend flashinfer \
    --mamba-cache-mode align \
    --reasoning-parser nemotron_v3 \
    --speculative_config.model "$dspark_ckpt" \
    --tool-call-parser qwen3_coder \
    --enable-auto-tool-choice

echo
echo 'Container started. Model download and loading can take a while.'
echo "Watch progress: sudo docker logs -f $container_name"
echo 'When startup completes, run: bash 05-check-vllm.sh'
