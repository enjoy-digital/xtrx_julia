REPO_DIR ?= $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))))

# By default we compile against the live kernel, but if we're cross-compilng (as we do on CI)
# then we need to download the right kernel and use it when compiling the kernel modules.
USE_LIVE_KERNEL ?= true

# We're going to install all our outputs here
PREFIX ?= $(REPO_DIR)/build

# Our makefiles are split up here, for easier management
include Makefile.kernel
include Makefile.nvidia
include Makefile.litepcie
include Makefile.soapysdr
include Makefile.limesuite
include Makefile.fairwaves

# Helper target to unload all of our kernel modules, install the new ones, and reload them:
reload-modules: $(LITEPCIE_KO) $(NVIDIA_DRIVER_KO)
	-# Unload in-memory kernel modules
	sudo modprobe -r litepcie
	sudo modprobe -r liteuart
	-# We may have just installed new kernel modules on-disk, so let's run `depmod`
	sudo depmod
	-# re-load the new kernel modules
	sudo modprobe litepcie
	sudo modprobe liteuart


# Debug target to print out a makefile variable.  Use as `make print-FOO`
print-%:
	@-echo $*=$($*)
