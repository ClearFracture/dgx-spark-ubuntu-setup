#!/usr/bin/env bash
set -euo pipefail

base_url=http://127.0.0.1:8000
model_ckpt=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4

if ! curl -fsS "$base_url/health" >/dev/null; then
  echo 'vLLM is not healthy yet. Check: sudo docker logs --tail 100 nemotron-lightning' >&2
  exit 1
fi
echo 'vLLM health: OK'
curl -fsS "$base_url/v1/models"
echo
curl -fsS "$base_url/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$model_ckpt\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in one sentence.\"}],\"max_tokens\":512,\"chat_template_kwargs\":{\"enable_thinking\":false}}"
echo
