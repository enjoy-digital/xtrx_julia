REPO_DIR ?= $(shell dirname $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))))

PROGS=litepcie_util litepcie_test
LIBLITEPCIE := liblitepcie/liblitepcie.a
all: $(PROGS)

prefix ?= /usr/local

# If the user wants to use a custom build of cuda, they can override this
CUDA_PREFIX ?= /usr/local/cuda

CFLAGS=-O2 -Wall -g -MMD -fPIC
LDFLAGS=-lm
CC=$(CROSS_COMPILE)gcc
AR=ar
RANLIB=ranlib

CFLAGS += -I./liblitepcie
CFLAGS += -I../litepcie-kernel-module

LDFLAGS += $(LIBLITEPCIE)
LDFLAGS += -L./liblitepcie -llitepcie

ifeq ($(USE_CUDA),true)
	LDFLAGS += -L$(CUDA_PREFIX)/lib -L$(CUDA_PREFIX)/lib64 -L$(CUDA_PREFIX)/lib64/stubs  -lcuda
	CFLAGS += -I$(CUDA_PREFIX)/include -DCUDA
endif

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
	$(RM) $(PROGS) *.o *.a *.d *~ liblitepcie/*.a liblitepcie/*.o liblitepcie/*.d

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

