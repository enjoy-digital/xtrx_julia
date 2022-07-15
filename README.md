                               _  ___________  _  __       __     ___
                              | |/_/_  __/ _ \| |/_/_____ / /_ __/ (_)__ _
                             _>  <  / / / , _/>  </___/ // / // / / / _ `/
                            /_/|_|_/_/ /_/|_/_/|_|    \___/\_,_/_/_/\_,_/
                             / ___/__  __ _  ___  __ __/ /___ _____  ___ _
                            / /__/ _ \/  ' \/ _ \/ // / __/ // / _ \/ _ `/
                            \___/\___/_/_/_/ .__/\_,_/\__/\_,_/_//_/\_, /
                                          /_/                      /___/
                                XTRX LiteX/LitePCIe based FPGA design
                                      for Julia Computing.

[> Intro
--------

This project aims to recreate a FPGA design for the XTRX board with
LiteX/LitePCIe:

![](https://user-images.githubusercontent.com/1450143/147348139-503834af-76d5-4172-8ca0-e323b719fa17.png)


This Julia Computing remote contains support for GPU P2P operations.

[> GPU Setup
------------

For P2P operation the [open source Nvidia drivers](https://github.com/NVIDIA/open-gpu-kernel-modules) are required.
Note that we currently carry [our own patch for resizing the addressable memory space](https://github.com/NVIDIA/open-gpu-kernel-modules/pull/3), and until that is merged, the easiest thing to do is to build our fork of the driver, which can be done via `make -C software nvidia-driver`.


[> Getting started
------------------

### [> Installing LiteX:

LiteX can be installed by following the installation instructions from the LiteX
Wiki: https://github.com/enjoy-digital/litex/wiki/Installation

### [> Installing the RISC-V toolchain for the Soft-CPU:

To get and install a RISC-V toolchain, please install it manually of follow the
LiteX's wiki: https://github.com/enjoy-digital/litex/wiki/Installation:

```
./litex_setup.py --gcc=riscv
```


[> Build and Test the design
----------------------------

Build the design and flash it to the board:

```
./fairwaves_xtrx.py --build --flash
```

Build the Linux kernel driver and load it.
Note that by default, the current live kernel will be built against, but you can cross-compile for a target kernel version by setting `USE_LIVE_KERNEL=false`.

```
make -C software litepcie-kernel-module
sudo software/litepcie-kernel-module/init.sh
```

Note that if a thunderbolt carrier is in use, it may be necessary rescan the pci bus:

```
sudo bash -c 'echo "1" > /sys/bus/pci/rescan'
```

Build the Linux user-space utilities and test them:

```
make -C software litepcie-user-library -j$(nproc)
cd build/litepcie-user-library
./litepcie_util info
./litepcie_util scratch_test
./litepcie_util dma_test
```

If anything goes wrong, reset the device with:

```
sudo bash -c 'echo "1" > /sys/bus/pci/devices/0000\:02\:00.0/reset'
```


[> User-space software
----------------------

To interface with the LMS7002M chip, we provide a SoapySDR driver. This driver
is in turn built on top of [MyriadRF's LMS7002M driver
library](https://github.com/myriadrf/LMS7002M-driver), which is downloaded and
installed automatically when you compile the SoapySDR driver:

```
make -C software soapysdr-xtrx -j$(nproc)
export SOAPY_SDR_PLUGIN_PATH="$(make -sC software print-soapysdr-plugin-path)"
```

The above snippet sets `SOAPY_SDR_PLUGIN_PATH` so that any SoapySDR application
can find the XTRX driver. This can be used to execute the example Julia scripts
in this repository:

```
cd software/scripts
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project test_pattern.jl
```

**NOTE**: sometimes, the SoapySDR driver doesn't properly initialize the SDR
(indicated by `test_pattern.jl` reading only zeros, or `test_loopback.jl` only
reporting under/overflows). This can be worked around by launching
`litepcie_test` (e.g. `litepcie_test record /dev/null 1024`). Afterwards, the
chip should be in a good state.

There is also a modified version of LimeSuite available that makes it possible
to interactively configure the LMS7002M:

```
git clone https://github.com/JuliaComputing/LimeSuite -b tb/xtrx_litepcie
cd LimeSuite
mkdir builddir
cd builddir
export LITEPCIE_ROOT=/path/to/xtrx_julia/software
cmake -DENABLE_XTRX=yes -DCMAKE_BUILD_TYPE=Debug ../
make
sudo make install
```

[> Development
--------------

Both using LimeSuite and SoapySDR it's possible to load LMS7002M register dumps,
e.g., to test specific functionality:

- TX-RX FPGA internal loopback:

  ```
  LimeSuiteGUI (and open/load xtrx_dlb.ini)
  cd software/app
  make
  ./litex_xtrx_util lms_set_tx_rx_loopback 1
  ./litex_xtrx_util dma_test -e -w 12
  ```

- TX Pattern + LMS7002M loopback test:

  ```
  LimeSuiteGUI (and open/load xtrx_dlb.ini)
  cd software/app
  make
  ./litex_xtrx_util lms_set_tx_rx_loopback 0
  ./litex_xtrx_util lms_set_tx_pattern 1
  ../user/litepcie_test record dump.bin 0x100
  ```

- DMA+LMS7002 loopback test:

  ```
  LimeSuiteGUI (and open/load xtrx_dlb.ini)
  cd software/app
  make
  ./litex_xtrx_util lms_set_tx_rx_loopback 0
  ./litex_xtrx_util lms_set_tx_pattern 0
  ./litex_xtrx_util dma_test -e -w 12
  ```

To work with the embedded RISC-V CPU, the firmware (which is normally
automatically compiled and integrated in the SoC during build) can be recompiled
and reloaded with:

```
cd firmware
make
sudo litex_term /dev/ttyLXU0 --kernel=firmware.bin --safe
```

LiteScope:

```
litex_server --jtag --jtag-config=openocd_xc7_ft232.cfg
litescope_cli
```

GLScopeClient (WIP):
https://github.com/juliacomputing/scopehal-apps/tree/sjk/xtrx1


[> Contact
----------

E-mail: florent@enjoy-digital.fr
