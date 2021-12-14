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

This project aims to recreate a FPGA design for the XTRX board with LiteX/LitePCIe.

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

````
./fairwaves_xtrx.py --build --flash --driver
````

[> Contact
-------------
E-mail: florent@enjoy-digital.fr