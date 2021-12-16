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

This project aims to recreate a FPGA design for the XTRX board with LiteX/LitePCIe:

![](https://user-images.githubusercontent.com/1450143/146242608-4d128301-eeb5-49e9-be19-43874e32e811.png)

[> Getting started
------------------
### [> Installing LiteX:

LiteX can be installed by following the installation instructions from the LiteX Wiki: https://github.com/enjoy-digital/litex/wiki/Installation

### [> Installing the RISC-V toolchain for the Soft-CPU:

To get and install a RISC-V toolchain, please install it manually of follow the LiteX's wiki: https://github.com/enjoy-digital/litex/wiki/Installation:
````
./litex_setup.py --gcc=riscv
````

[> Build and Test the design(s)
---------------------------------

Build the design and flash it to the board:
````
./fairwaves_xtrx.py --build --flash --driver
````

Build the Linux kernel and load it:
````
cd software/kernel
make
sudo ./init.sh
````

Build the Linux user-space utilities and test them:
````
cd software/user
make
./litepcie_util info
./litepcie_util scratch_test
./litepcie_util dma_test
````

The firmware is automatically integrated in the SoC during the build and can be executed with:
````
sudo litex_term /dev/ttyLXU0
````

For development, firmware can be recompiled and reloaded with:
````
cd firmware
make
sudo litex_term /dev/ttyLXU0 --kernel=firmware.bin --safe
````

Get/Use modified LimeSuite:
````
git clone https://github.com/JuliaComputing/LimeSuite
cd LimeSuite
git checkout tb/xtrx_litepcie
mkdir builddir
cd builddir
LITEPCIE_ROOT=/path/to/xtrx_julia/software cmake -DENABLE_XTRX=yes -DCMAKE_BUILD_TYPE=Debug ../
make
sudo make install
````

Get/Use modified LMS7002M-driver:
````
git clone https://github.com/JuliaComputing/LMS7002M-driver
cd LMS7002M-driver
git checkout tb/xtrx
mkdir build
cd build
LITEPCIE_ROOT=/path/to/xtrx_julia/software cmake -DCMAKE_BUILD_TYPE=Debug ../
make
sudo make install
````

[> Contact
-------------
E-mail: florent@enjoy-digital.fr