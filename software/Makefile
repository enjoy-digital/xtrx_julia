REPO_DIR ?= $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))))

KERNEL_URL := https://github.com/torvalds/linux.git
KERNEL_VERSION := 5.15
kernel/.git/HEAD:
	@echo "Downloading kernel v$(KERNEL_VERSION)"
	git clone --depth=1 -b v$(KERNEL_VERSION) $(KERNEL_URL) kernel
get-kernel: kernel/.git/HEAD

# Running `make kernel` builds this file
$(REPO_DIR)/build/kernel/bzImage: kernel/.git/HEAD
	$(MAKE) -C kernel defconfig
	$(MAKE) -C kernel
	mkdir -p $(dir $@)
	cp -L kernel/arch/$(shell uname -m)/boot/bzImage $@
kernel: $(REPO_DIR)/build/kernel/bzImage
.PHONY: kernel

# Use our own fork until this PR is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/3
NV_DRIVER_URL := https://github.com/JuliaComputing/open-gpu-kernel-modules.git
NV_DRIVER_VERSION := sjk/rebar2
nvidia-driver/.git/HEAD:
	@echo "Downloading nvidia-driver $(NV_DRIVER_VERSION)"
	git clone --depth=1 -b $(NV_DRIVER_VERSION) $(NV_DRIVER_URL) nvidia-driver
get-nvidia-driver: nvidia-driver/.git/HEAD

NVIDIA_DRIVER_MODPATH ?= /lib/modules/$(shell uname -r)
$(NVIDIA_DRIVER_MODPATH)/kernel/drivers/video/nvidia.ko: nvidia-driver/.git/HEAD $(REPO_DIR)/build/kernel/bzImage
	$(MAKE) -C nvidia-driver SYSSRC="$(REPO_DIR)/software/kernel" INSTALL_MOD_PATH="$(NVIDIA_DRIVER_MODPATH)"
	@# Ignore the error here, depmod 
	-$(MAKE) -C nvidia-driver SYSSRC="$(REPO_DIR)/software/kernel" INSTALL_MOD_PATH="$(NVIDIA_DRIVER_MODPATH)" modules_install
nvidia-driver: $(NVIDIA_DRIVER_MODPATH)/kernel/drivers/video/nvidia.ko

NV_CUDA_VERSION := 11.7.0
CUDA_URL ?= https://github.com/JuliaBinaryWrappers/CUDA_full_jll.jl/releases/download/CUDA_full-v$(NV_CUDA_VERSION)+0/CUDA_full.v$(NV_CUDA_VERSION).$(shell gcc -dumpmachine).tar.gz
CUDA_PREFIX ?= $(REPO_DIR)/software/nvidia-cuda
nvidia-cuda/bin/nvcc:
	@echo "Downloading nvidia-cuda v$(NV_CUDA_VERSION)"
	@mkdir -p nvidia-cuda
	curl -# -f -L "$(CUDA_URL)" | tar -C nvidia-cuda -zx --strip-components=1 cuda
nvidia-cuda: nvidia-cuda/bin/nvcc
.PHONY: nvidia-cuda

LITEPCIE_MODPATH ?= /lib/modules/$(shell uname -r)
$(LITEPCIE_MODPATH)/liteuart.ko: $(REPO_DIR)/build/kernel/bzImage nvidia-driver/.git/HEAD
	# Explicitly don't parallelize this, makefile is apparently not correctly written
	make -C litepcie-kernel-module
	mkdir -p $(dir $@)
	cp -L litepcie-kernel-module/*.ko $(dir $@)
litepcie-kernel-module: $(LITEPCIE_MODPATH)/liteuart.ko
.PHONY: litepcie-kernel-module

LITEPCIE_PREFIX ?= $(REPO_DIR)/build/litepcie-user-library
$(LITEPCIE_PREFIX)/lib/liblitepcie.a: nvidia-cuda/bin/nvcc
	$(MAKE) -C litepcie-user-library CUDA_PREFIX=$(CUDA_PREFIX) prefix=$(LITEPCIE_PREFIX) install
litepcie-user-library: $(LITEPCIE_PREFIX)/lib/liblitepcie.a
.PHONY: litepcie-user-library

SOAPYSDR_VERSION := 0.8.1
SOAPYSDR_MAJMIN := $(basename $(SOAPYSDR_VERSION))
SOAPYSDR_PREFIX ?= $(REPO_DIR)/build/soapysdr
$(SOAPYSDR_PREFIX)/lib/libSoapySDR.so:
	@echo "Downloading and building SoapySDR v$(SOAPYSDR_VERSION)"
	git clone --depth=1 -b soapy-sdr-$(SOAPYSDR_VERSION) https://github.com/pothosware/SoapySDR soapysdr
	mkdir -p soapysdr/build
	cmake -DCMAKE_INSTALL_PREFIX=$(SOAPYSDR_PREFIX) \
		  -S soapysdr \
		  -B soapysdr/build
	$(MAKE) -C soapysdr/build install
soapysdr: $(SOAPYSDR_PREFIX)/lib/libSoapySDR.so

SOAPYSDR_XTRX_PREFIX ?= $(REPO_DIR)/build/soapysdr-xtrx
soapysdr-xtrx: $(SOAPYSDR_PREFIX)/lib/libSoapySDR.so $(LITEPCIE_PREFIX)/lib/liblitepcie.a
	mkdir -p soapysdr-xtrx/build
	cmake -DCUDAToolkit_ROOT=$(CUDA_PREFIX) \
		  -DSoapySDR_ROOT=$(SOAPYSDR_PREFIX) \
		  -DCMAKE_INSTALL_PREFIX=$(SOAPYSDR_XTRX_PREFIX) \
		  -S soapysdr-xtrx \
		  -B soapysdr-xtrx/build
	make -C soapysdr-xtrx/build -j$$(nproc) install
#soapysdr-xtrx:
