REGISTRY                ?= steven-cr.axolotl-tone.ts.net
REPO                    ?= edera

DOCKER_IMAGE_NAME       := $(REGISTRY)/$(REPO)/edera-benchmarks:latest
DOCKER_DEV_IMAGE_NAME   := $(REGISTRY)/$(REPO)/edera-benchmarks-dev:latest

DOCKER_ARGS_COMMON      := --rm -v ${PWD}/results:/opt/pts-results -it
DOCKER_ARGS_NVIDIA      := --runtime nvidia --gpus all --device=/dev/dri:/dev/dri -v /etc/OpenCL/vendors/nvidia.icd:/etc/OpenCL/vendors/nvidia.icd
DOCKER_ARGS_MESA        := --device=/dev/dri:/dev/dri
DOCKER_ARGS_SHELL       := --entrypoint=/usr/bin/bash

PTS_CPU_TEST            := pts/compress-zstd-1.6.0
PTS_GPU_TEST            := pts/vkpeak-1.3.0

# Shorthand variable for the run-* and test-* targets
IMAGE                   := $(DOCKER_IMAGE_NAME)

all: build

build:
	docker buildx build --load --target edera-benchmarks -t $(DOCKER_IMAGE_NAME) -f Dockerfile .
	docker buildx build --load --target edera-benchmarks-dev -t $(DOCKER_DEV_IMAGE_NAME) -f Dockerfile .

publish:
	docker buildx build \
	  --target edera-benchmarks \
	  --output type=image,name=$(DOCKER_IMAGE_NAME),push=true,compression=zstd,oci-mediatypes=true,force-compression=true \
	  -f Dockerfile .
	docker buildx build \
	  --target edera-benchmarks-dev \
	  --output type=image,name=$(DOCKER_DEV_IMAGE_NAME),push=true,compression=zstd,oci-mediatypes=true,force-compression=true \
	  -f Dockerfile .


#
# Note: the following targets can be invoked directly, e.g.:
#   $ make run-shell
# or with an override for which image to run, e.g.:
#   $ make run-shell IMAGE=edera-benchmarks-dev:latest
#

run-shell:
	docker run $(DOCKER_ARGS_COMMON) $(DOCKER_ARGS_SHELL) $(IMAGE)

run-nvidia-shell:
	docker run $(DOCKER_ARGS_COMMON) $(DOCKER_ARGS_NVIDIA) $(DOCKER_ARGS_SHELL) $(IMAGE)

run-mesa-shell:
	docker run $(DOCKER_ARGS_COMMON) $(DOCKER_ARGS_MESA) $(DOCKER_ARGS_SHELL) $(IMAGE)

# Run compress-zstd
test-cpu:
	docker run $(DOCKER_ARGS_COMMON) $(IMAGE) batch-run $(PTS_CPU_TEST)

# Run vkpeak on an NVIDIA GPU, requires that you have nvidia-container-runtime
test-nvidia:
	docker run $(DOCKER_ARGS_COMMON) $(DOCKER_ARGS_NVIDIA) $(IMAGE) batch-run $(PTS_GPU_TEST)

# Run vkpeak on Mesa (e.g. amdgpu)
test-mesa:
	docker run $(DOCKER_ARGS_COMMON) $(DOCKER_ARGS_MESA) $(IMAGE) batch-run $(PTS_GPU_TEST)
