REPO_DIR ?= $(shell dirname $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))))

PROGS=litepcie_util litepcie_test litepcie_dma_minimal_example
LIBLITEPCIE := liblitepcie/liblitepcie.a
all: $(PROGS)

prefix ?= /usr/local

# If the user wants to use a custom build of cuda, they can override this
CUDA_PATH ?= $(REPO_DIR)/software/nvidia-cuda

# If they didn't though, allow auto-downloading of the CUDA toolkit from a JLL:
ifeq ($(CUDA_PATH),$(REPO_DIR)/software/nvidia-cuda)
CUDA_VERSION=11.7.0
CUDA_JLL_BUILD=$(CUDA_VERSION)+0
CUDA_URL ?= https://github.com/JuliaBinaryWrappers/CUDA_jll.jl/releases/download/CUDA-v$(CUDA_JLL_BUILD)/CUDA.v$(CUDA_VERSION).$(shell gcc -dumpmachine).tar.gz
CUDA_COMPAT_URL ?= https://github.com/JuliaBinaryWrappers/CUDA_compat_jll.jl/releases/download/CUDA_compat-v$(CUDA_JLL_BUILD)/CUDA_compat.v$(CUDA_VERSION).$(shell gcc -dumpmachine).tar.gz
$(CUDA_PATH):
	@mkdir -p $@
	curl -# -f -L "$(CUDA_URL)" | tar -C $@ -zx
	curl -# -f -L "$(CUDA_COMPAT_URL)" | tar -C $@ -zx

download-cuda: $(CUDA_PATH)
liblitepcie/liblitepcie.a: | $(CUDA_PATH)
endif


CFLAGS=-O2 -Wall -g -MMD -fPIC
LDFLAGS=-lm
CC=$(CROSS_COMPILE)gcc
AR=ar
RANLIB=ranlib

CFLAGS += -I./liblitepcie
CFLAGS += -I../litepcie-kernel-module
CFLAGS += -I$(CUDA_PATH)/include

LDFLAGS += $(LIBLITEPCIE)
LDFLAGS += -L$(CUDA_PATH)/lib -lcuda
LDFLAGS += -L./liblitepcie -llitepcie

$(LIBLITEPCIE): liblitepcie/litepcie_dma.o liblitepcie/litepcie_flash.o liblitepcie/litepcie_helpers.o
	$(AR) rcs $@ $+
	$(RANLIB) $@

litepcie_util: litepcie_util.o $(LIBLITEPCIE)
	$(CC) -o $@ $< $(LDFLAGS)

litepcie_test: litepcie_test.o $(LIBLITEPCIE)
	$(CC) -o $@ $< $(LDFLAGS)

litepcie_dma_minimal_example: litepcie_dma_minimal_example.o $(LIBLITEPCIE)
	$(CC) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(PROGS) *.o *.a *.d *~ liblitepcie/*.a liblitepcie/*.o liblitepcie/*.d

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

liblitepcie/%.o: liblitepcie/%.c
	$(CC) -c $(CFLAGS) -o $@ $<

install: $(PROGS)
	mkdir -p $(prefix)/bin
	cp -a $(PROGS) $(prefix)/bin/
	mkdir -p $(prefix)/include/liblitepcie
	cp -a liblitepcie/*.h $(prefix)/include/liblitepcie/
	mkdir -p $(prefix)/lib
	cp -a $(LIBLITEPCIE) $(prefix)/lib/

