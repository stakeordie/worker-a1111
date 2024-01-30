# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
ARG added_stuff=other
ARG model
ARG cnet="false"
ARG upscaler="false"

FROM alpine/git:2.36.2 as download

COPY builder/clone.sh /clone.sh

# Clone the repos and clean unnecessary files
RUN . /clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 && \
    rm -rf data assets **/*.ipynb

RUN . /clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git 47b6b607fdd31875c9279cd2f4f16b92e4ea958e && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN . /clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af && \
    rm -rf assets inputs

RUN . /clone.sh BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9 && \
    . /clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec && \
    . /clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8 && \
    . /clone.sh generative-models https://github.com/Stability-AI/generative-models 45c443b316737a4ab6e40413d7794a7f5657c19f


# ---------------------------------------------------------------------------- #
#                        Stage 3: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.6-slim as build_final_image_stage_1

#ARG SHA=5ef669de080814067961f28357256e8fe27544f4
ARG model
ARG half="--no-half-vae"
ARG lora="--lora-dir /runpod-volume/loras"
ARG local="false"
ARG local_port=8080
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    LD_PRELOAD=libtcmalloc.so \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1 \
    MODEL=${model} \
    HALF=${half} \
    LORA=${lora} \
    LOCAL=${local} \
    LOCAL_PORT=${local_port}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN export COMMANDLINE_ARGS="--skip-torch-cuda-test --precision full --no-half"
RUN export TORCH_COMMAND='pip install --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/rocm5.6'

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y


RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118


## imports?

#refiner
FROM build_final_image_stage_1 as build_final_image_stage_2-refiner
COPY lib/sub_models /sub_models
COPY lib/refiner /refiner
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cp -a /sub_models/. ${ROOT}/models/ && \
    cp -a /refiner/. ${ROOT}/models/
ENV UPSCALER="false"

#upscaler
FROM build_final_image_stage_1 as build_final_image_stage_2-upscaler
COPY lib/sub_models /sub_models
COPY lib/upscalers /upscalers
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cp -a /sub_models/. ${ROOT}/models/ && \
    cp -a /upscalers/. ${ROOT}/models/
ENV UPSCALER="true"

#other
FROM build_final_image_stage_1 as build_final_image_stage_2-other
COPY lib/sub_models /sub_models
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cp -a /sub_models/. ${ROOT}/models/
ENV UPSCALER="false"

FROM build_final_image_stage_2-${added_stuff} as build_final_image

#test
##FROM build_final_image_stage_2-${added_stuff} as build_final_image_stage_2

## controlnet?

## true
##FROM build_final_image_stage_2 as build_final_image_stage_3-true
##COPY lib/extensions/. ${ROOT}/extensions/
##COPY lib/ControlNetModels/. ${ROOT}/extensions/sd-webui-controlnet/models/

## flase
##FROM build_final_image_stage_2 as build_final_image_stage_3-false

## controlnet test
##FROM build_final_image_stage_3-${cnet} as build_final_image

#    git reset --hard ${SHA}
#&& \ pip install -r requirements_versions.txt

COPY --from=download /repositories/ ${ROOT}/repositories/

COPY lib/models/${model} /${model}

RUN mkdir ${ROOT}/interrogate && cp ${ROOT}/repositories/clip-interrogator/data/* ${ROOT}/interrogate
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

ADD src .

COPY builder/cache.py /stable-diffusion-webui/cache.py
RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /${model} --no-half-vae

# Cleanup section (Worker Template)
RUN apt-get update -y && \
    apt-get install nano curl -y && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh