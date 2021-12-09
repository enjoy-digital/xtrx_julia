#!/usr/bin/env python3

# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import sys
import time
import argparse

from litex import RemoteClient

# Constants ----------------------------------------------------------------------------------------

LMS7002M_RESET      = (1 << 0)
LMS7002M_POWER_DOWN = (1 << 1)
LMS7002M_TX_ENABLE  = (1 << 8)
LMS7002M_RX_ENABLE  = (1 << 9)

SPI_CS_HIGH = (0 << 0)
SPI_CS_LOW  = (1 << 0)
SPI_START   = (1 << 0)
SPI_DONE    = (1 << 0)
SPI_LENGTH  = (1 << 8)

# LMS7002MSPI --------------------------------------------------------------------------------------

class LMS7002MSPI:
    def __init__(self, bus):
        self.bus = bus

    def write(self, addr, value):
        cmd = (1 << 15) | (addr & (2**15-1))
        dat = (value & (2**16-1))
        self.bus.regs.lms7002m_spi_mosi.write(cmd << 16 | dat)
        self.bus.regs.lms7002m_spi_control.write(32*SPI_LENGTH | SPI_START)
        while (self.bus.regs.lms7002m_spi_status.read() & SPI_DONE) == 0:
            time.sleep(1e-3)

    def read(self, addr):
        cmd = (0 << 15) | (addr & (2**15-1))
        self.bus.regs.lms7002m_spi_mosi.write(cmd << 16)
        self.bus.regs.lms7002m_spi_control.write(32*SPI_LENGTH | SPI_START)
        while (self.bus.regs.lms7002m_spi_status.read() & SPI_DONE) == 0:
            time.sleep(1e-3)
        return self.bus.regs.lms7002m_spi_miso.read() & (2**16-1)

# SPI Test ----------------------------------------------------------------------------------------

def spi_test(csr_csv="csr.csv", port=1234):
    bus = RemoteClient(csr_csv=csr_csv, port=port)
    bus.open()

    # Create LMS7002M SPI
    lms7002m_spi = LMS7002MSPI(bus)

    # Enable LMS7002M.
    bus.regs.lms7002m_control.write(LMS7002M_RESET)
    time.sleep(0.1)

    # Dump LMS7002M SPI Registers.
    print("LMS7002M Reg Dump:")
    for n in range(1024):
        print(f"0x{n:04x}: 0x{lms7002m_spi.read(n):04x}")

    bus.close()

# Run ----------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LMS7002M bringup test utility")
    parser.add_argument("--csr-csv",     default="csr.csv",   help="CSR configuration file")
    parser.add_argument("--port",        default="1234",      help="Host bind port")
    args = parser.parse_args()

    spi_test(
        csr_csv = args.csr_csv,
        port    = int(args.port, 0)
     )

if __name__ == "__main__":
    main()
