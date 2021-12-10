#!/usr/bin/env python3

# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# Build/Use ----------------------------------------------------------------------------------------
# ./fairwaves_xtrx.py --no-pcie --build --flash
# litex_server --jtag --jtag-config=openocd_xc7_ft232.cfg
# litex_cli --regs
# ./test_tcxo.py

import sys
import time
import argparse

from litex import RemoteClient

# TCXO ---------------------------------------------------------------------------------------------

class TCXO:
    def __init__(self, bus):
        self.bus = bus

    def enable(self):
        self.bus.regs.tcxo_control.write(0b11)

    def cycles(self):
        self.bus.regs.tcxo_cycles_latch.write(1)
        return self.bus.regs.tcxo_cycles.read()

# TCXO Test ----------------------------------------------------------------------------------------

def tcxo_test(csr_csv="csr.csv", port=1234):
    bus = RemoteClient(csr_csv=csr_csv, port=port)
    bus.open()

    # Create TCXO
    tcxo = TCXO(bus)
    tcxo.enable()

    # Monitor TCXO cycles.
    print("Monitor TCXO cycles...")
    for i in range(10):
        print(f"{i*100:4d}ms : {tcxo.cycles()}")
        time.sleep(0.1)

    bus.close()

# Run ----------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="TCXO test utility")
    parser.add_argument("--csr-csv",     default="csr.csv",   help="CSR configuration file")
    parser.add_argument("--port",        default="1234",      help="Host bind port")
    args = parser.parse_args()

    tcxo_test(
        csr_csv = args.csr_csv,
        port    = int(args.port, 0)
     )

if __name__ == "__main__":
    main()
