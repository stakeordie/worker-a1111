#!/bin/bash

echo "Worker Initiated"

echo "MODEL $MODEL"
echo "HALF: $HALF"
echo "LORA: $LORA"
echo "LOCAL: $LOCAL"
echo "PORT: $LOCAL_PORT"
echo "UPSCALER: $UPSCALER"

echo "Starting WebUI API"

python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /${MODEL} $LORA --opt-sdp-no-mem-attention --disable-safe-unpickle --port 3000 --api --listen --lowram --skip-version-check --no-download-sd-model ${HALF} &

echo "Starting RunPod Handler"

if [ "$LOCAL" == "true" ]; then
  mkdir logs
  python -u local_handler.py --rp_serve_api --rp_api_host '0.0.0.0' --rp_api_port $LOCAL_PORT
else
  if [ "$UPSCALER" == "true" ]; then
    python -u rp_handler_upscaler.py
  else
    python -u rp_handler.py
  fi
fi