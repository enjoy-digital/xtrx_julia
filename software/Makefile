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

print-%:
	@-echo $*=$($*)
