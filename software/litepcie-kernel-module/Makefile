# Export `REPO_DIR` so that when the kernel's byzantine makefile system re-includes us,
# it's already set properly and doesn't get re-set with the wrong path.
REPO_DIR ?= $(shell dirname $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))))
export REPO_DIR

# Link to the other checkouts in this repository by default
# Override these if you want to do a "local" build
KERNEL_PATH ?= $(REPO_DIR)/software/kernel
NVIDIA_PATH ?= $(REPO_DIR)/software/nvidia-driver

# We will always assume that we're doing a native build
ARCH ?= $(shell uname -m)

obj-m = litepcie.o liteuart.o
litepcie-objs = main.o
ccflags-y += -I$(NVIDIA_PATH)/kernel-open/nvidia

# don't warn about missing NVIDIA symbols; they'll be available
# TODO: create our own Module.symvers,
#       https://github.com/NVIDIA/gds-nvidia-fs/blob/af3f7de96b4e500abf30e3034e5827749953bd68/src/Makefile#L108-L112
KBUILD_MODPOST_WARN=1

all: litepcie.ko liteuart.ko

litepcie.ko: main.c
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

litepcie.ko: litepcie.h config.h flags.h csr.h soc.h

liteuart.ko: liteuart.c
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

clean:
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) clean
	rm -f *~

uninstall:
	rmmod litepcie
	rmmod liteuart

print-%  : ; @echo $* = $($*)
