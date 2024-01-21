#!/bin/bash

echo "Worker Initiated"

ls -la /
ls -la /models
ls -ls /upscalers
ls -ls /upscalers/ScuNET
ls -la /stable-diffusion-webui
ls -la /stable-diffusion-webui/models
ls -la /stable-diffusion-webui/models/ScuNET
ls -la /stable-diffusion-webui/models/RealESRGAN

echo $MODEL

echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /${MODEL} --lora-dir /runpod-volume/loras --lowram --opt-sdp-no-mem-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check --no-hashing --no-download-sd-model ${HALF}

echo "Starting RunPod Handler"
python -u /rp_handler.py
