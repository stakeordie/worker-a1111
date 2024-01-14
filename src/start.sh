#!/bin/bash

echo "Worker Initiated"

echo ls -la /

while getopts ":m" flag > /dev/null 2>&1
do
    case ${flag} in
        m) model="${OPTARG}" ;;
        *) break;; 
    esac
done

echo "Starting WebUI API"
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /${model} --lora-dir /runpod-volume/loras --lowram --opt-sdp-no-mem-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &

echo "Starting RunPod Handler"
python -u /rp_handler.py