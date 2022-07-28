REPO_DIR ?= $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))))

KERNEL_URL := https://github.com/torvalds/linux.git
KERNEL_VERSION ?= v5.15
kernel/.git/HEAD:
	git clone --depth=1 -b $(KERNEL_VERSION) $(KERNEL_URL) kernel
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
	git clone --depth=1 -b $(NV_DRIVER_VERSION) $(NV_DRIVER_URL) nvidia-driver
get-nvidia-driver: nvidia-driver/.git/HEAD

NVIDIA_DRIVER_MODPATH ?= /lib/modules/$(shell uname -r)
NVIDIA_DRIVER_KO := $(NVIDIA_DRIVER_MODPATH)/kernel/drivers/video/nvidia.ko
$(NVIDIA_DRIVER_KO): nvidia-driver/.git/HEAD
	$(MAKE) -C nvidia-driver SYSSRC="$(KERNEL_PATH)" INSTALL_MOD_PATH="$(NVIDIA_DRIVER_MODPATH)"
	@# Ignore the error here, depmod 
	-$(MAKE) -C nvidia-driver SYSSRC="$(KERNEL_PATH)" INSTALL_MOD_PATH="$(NVIDIA_DRIVER_MODPATH)" modules_install
nvidia-driver: $(NVIDIA_DRIVER_KO)

NV_CUDA_VERSION := v11.7.0
CUDA_URL ?= https://github.com/JuliaBinaryWrappers/CUDA_full_jll.jl/releases/download/CUDA_full-$(NV_CUDA_VERSION)+0/CUDA_full.$(NV_CUDA_VERSION).$(shell gcc -dumpmachine).tar.gz
CUDA_PREFIX ?= $(REPO_DIR)/software/nvidia-cuda
nvidia-cuda/bin/nvcc:
	@mkdir -p nvidia-cuda
	curl -# -f -L "$(CUDA_URL)" | tar -C nvidia-cuda -zx --strip-components=1 cuda
nvidia-cuda: nvidia-cuda/bin/nvcc
.PHONY: nvidia-cuda

LITEPCIE_MODPATH ?= /lib/modules/$(shell uname -r)
LITEPCIE_KO ?= $(LITEPCIE_MODPATH)/liteuart.ko
$(LITEPCIE_KO): nvidia-driver/.git/HEAD
	# Explicitly don't parallelize this, makefile is apparently not correctly written
	make -C litepcie-kernel-module KERNEL_PATH="$(KERNEL_PATH)"
	mkdir -p $(dir $@)
	cp -L litepcie-kernel-module/*.ko $(dir $@)
litepcie-kernel-module: $(LITEPCIE_KO)
.PHONY: litepcie-kernel-module


# By default we use the live kernel, but if we're for instance cross-compilng (as we do on CI)
# then we need to download the right kernel and use it when compiling the kernel modules.
USE_LIVE_KERNEL ?= true
ifeq ($(USE_LIVE_KERNEL),true)
KERNEL_PATH ?= /lib/modules/$(shell uname -r)/build
else
KERNEL_PATH ?= $(REPO_DIR)/software/kernel
$(NVIDIA_DRIVER_KO): $(REPO_DIR)/build/kernel/bzImage
$(LITEPCIE_KO): $(REPO_DIR)/build/kernel/bzImage
endif

LITEPCIE_PREFIX ?= $(REPO_DIR)/build/litepcie-user-library
$(LITEPCIE_PREFIX)/lib/liblitepcie.a: nvidia-cuda/bin/nvcc
	$(MAKE) -C litepcie-user-library CUDA_PREFIX=$(CUDA_PREFIX) prefix=$(LITEPCIE_PREFIX) install
litepcie-user-library: $(LITEPCIE_PREFIX)/lib/liblitepcie.a
.PHONY: litepcie-user-library

SOAPYSDR_VERSION := 0.8.1
SOAPYSDR_MAJMIN := $(basename $(SOAPYSDR_VERSION))
soapysdr/.git/HEAD:
	git clone --depth=1 -b soapy-sdr-$(SOAPYSDR_VERSION) https://github.com/pothosware/SoapySDR soapysdr

SOAPYSDR_PREFIX ?= $(REPO_DIR)/build/soapysdr
SOAPYSDR_LIB := $(SOAPYSDR_PREFIX)/lib/libSoapySDR.so
$(SOAPYSDR_LIB): soapysdr/.git/HEAD
	rm -rf soapysdr/build
	mkdir -p soapysdr/build
	cmake -DCMAKE_INSTALL_PREFIX=$(SOAPYSDR_PREFIX) \
		  -S soapysdr \
		  -B soapysdr/build
	$(MAKE) -C soapysdr/build install
soapysdr: $(SOAPYSDR_LIB)

SOAPYSDR_XTRX_PREFIX ?= $(REPO_DIR)/build/soapysdr-xtrx
SOAPYSDR_XTRX_LIB := $(SOAPYSDR_XTRX_PREFIX)/lib/SoapySDR/modules$(SOAPYSDR_MAJMIN)/libSoapyXTRX.so
$(SOAPYSDR_XTRX_LIB): $(SOAPYSDR_LIB) $(LITEPCIE_PREFIX)/lib/liblitepcie.a
	rm -rf soapysdr-xtrx/build
	mkdir -p soapysdr-xtrx/build
	cmake -DCUDAToolkit_ROOT=$(CUDA_PREFIX) \
		  -DSoapySDR_ROOT=$(SOAPYSDR_PREFIX) \
		  -DCMAKE_INSTALL_PREFIX=$(SOAPYSDR_XTRX_PREFIX) \
		  -S soapysdr-xtrx \
		  -B soapysdr-xtrx/build
	$(MAKE) -C soapysdr-xtrx/build install
soapysdr-xtrx: $(SOAPYSDR_XTRX_LIB)


# Helper to build libusb, so LimeSuite can properly link
LIBUSB_URL := https://github.com/libusb/libusb
LIBUSB_VERSION ?= v1.0.26
LIBUSB_MAJMIN := $(subst v,,$(basename $(LIBUSB_VERSION)))
LIBUSB_PREFIX ?= $(REPO_DIR)/build/libusb
LIBUSB_LIB := $(LIBUSB_PREFIX)/lib/libusb-$(LIBUSB_MAJMIN).so

libusb/.git/HEAD:
	git clone --depth=1 -b $(LIBUSB_VERSION) $(LIBUSB_URL) libusb
get-libusb: libusb/.git/HEAD

libusb/Makefile: libusb/.git/HEAD
	cd libusb && ./bootstrap.sh
	cd libusb && ./configure --prefix=$(LIBUSB_PREFIX)

$(LIBUSB_LIB): libusb/Makefile
	$(MAKE) -C libusb install
libusb: $(LIBUSB_LIB)

# Helper to build LimeSuite's SoapyLMS7 driver against our SoapySDR:
LIMESUITE_URL := https://github.com/myriadrf/LimeSuite
LIMESUITE_VERSION ?= v20.10.0
limesuite/.git/HEAD:
	git clone --depth=1 -b $(LIMESUITE_VERSION) $(LIMESUITE_URL) limesuite
get-limesuite: limesuite/.git/HEAD

LIMESUITE_PREFIX ?= $(REPO_DIR)/build/limesuite
SOAPYLMS7_LIB := $(LIMESUITE_PREFIX)/lib/SoapySDR/modules$(SOAPYSDR_MAJMIN)/libLMS7Support.so
$(SOAPYLMS7_LIB): $(SOAPYSDR_LIB) $(LIBUSB_LIB) limesuite/.git/HEAD
	rm -rf limesuite/_build
	mkdir -p limesuite/_build
	cmake -DCMAKE_PREFIX_PATH=$(SOAPYSDR_PREFIX) \
		  -DLIBUSB_1_INCLUDE_DIRS=$(LIBUSB_PREFIX)/include/libusb-$(LIBUSB_MAJMIN) \
		  -DLIBUSB_1_LIBRARIES=$(LIBUSB_LIB) \
		  -DLIBUSB_1_FOUND=TRUE \
		  -DCMAKE_BUILD_TYPE=Debug \
		  -DCMAKE_INSTALL_PREFIX=$(LIMESUITE_PREFIX) \
		  -S limesuite \
		  -B limesuite/_build
	$(MAKE) -C limesuite/_build VERBOSE=1 install

limesuite: $(SOAPYLMS7_LIB)

SOAPYSDR_JL_URL := https://github.com/JuliaTelecom/SoapySDR.jl.git
SOAPYSDR_JL_VERSION ?= main
SoapySDR.jl/.git/HEAD:
	git clone --depth=1 -b $(SOAPYSDR_JL_VERSION) $(SOAPYSDR_JL_URL) SoapySDR.jl

SoapySDR.jl: SoapySDR.jl/.git/HEAD
	julia --project -e 'import Pkg; Pkg.develop(path="SoapySDR.jl")'

print-soapysdr-plugin-path:
	@echo $(dir $(SOAPYSDR_XTRX_LIB))

print-%:
	-echo $*=$($*)
