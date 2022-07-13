KERNEL_URL := https://github.com/torvalds/linux.git
KERNEL_VERSION := v5.15
kernel:
	@echo "Downloading kernel $(KERNEL_VERSION)"
	git clone --depth=1 -b $(KERNEL_VERSION) $(KERNEL_URL) $@

# Use our own fork until this PR is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/3
NV_DRIVER_URL := https://github.com/JuliaComputing/open-gpu-kernel-modules.git
NV_DRIVER_VERSION := sjk/rebar2
nvidia-driver:
	@echo "Downloading nvidia-driver $(NV_DRIVER_VERSION)"
	git clone --depth=1 -b $(NV_DRIVER_VERSION) $(NV_DRIVER_URL) $@

NV_CUDA_VERSION=11.7.0
CUDA_URL ?= https://github.com/JuliaBinaryWrappers/CUDA_jll.jl/releases/download/CUDA-v$(NV_CUDA_VERSION)+0/CUDA.v$(NV_CUDA_VERSION).$(shell gcc -dumpmachine).tar.gz
CUDA_COMPAT_URL ?= https://github.com/JuliaBinaryWrappers/CUDA_compat_jll.jl/releases/download/CUDA_compat-v$(NV_CUDA_VERSION)+0/CUDA_compat.v$(NV_CUDA_VERSION).$(shell gcc -dumpmachine).tar.gz
nvidia-cuda:
	@echo "Downloading nvidia-cuda $(NV_CUDA_VERSION)"
	@mkdir -p $@
	curl -# -f -L "$(CUDA_URL)" | tar -C $@ -zx
	curl -# -f -L "$(CUDA_COMPAT_URL)" | tar -C $@ -zx
