#!/usr/bin/env python3

#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import argparse
import sys

from migen import *
from migen.fhdl.specials import Tristate

import fairwaves_xtrx_platform as fairwaves_xtrx

from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litex.soc.cores.clock import *
from litex.soc.cores.led import LedChaser
from litex.soc.cores.icap import ICAP
from litex.soc.cores.gpio import GPIOOut
from litex.soc.cores.spi_flash import S7SPIFlash
from litex.soc.cores.bitbang import I2CMaster

from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.software import generate_litepcie_software

from litescope import LiteScopeAnalyzer

from tcxo import TCXO
from lms7002m import LMS7002M

# CRG ----------------------------------------------------------------------------------------------

class CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.clock_domains.cd_sys  = ClockDomain()

        # # #

        assert sys_clk_freq == int(125e6)
        self.comb += [
            self.cd_sys.clk.eq(ClockSignal("pcie")),
            self.cd_sys.rst.eq(ResetSignal("pcie")),
        ]

# BaseSoC -----------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=int(125e6), with_cpu=True, with_jtagbone=False, with_analyzer=False):
        platform = fairwaves_xtrx.Platform()

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, sys_clk_freq,
            ident                    = "LiteX SoC on Fairwaves XTRX",
            ident_version            = True,
            cpu_type                 = "vexriscv" if with_cpu else None,
            integrated_rom_size      = 0x8000  if with_cpu else 0,
            integrated_main_ram_size = 0x10000 if with_cpu else 0,
            uart_name                = "crossover",
        )

        # Clocking ---------------------------------------------------------------------------------
        self.submodules.crg = CRG(platform, sys_clk_freq)

        # JTAGBone ---------------------------------------------------------------------------------
        if with_jtagbone:
            self.add_jtagbone()

        # Leds -------------------------------------------------------------------------------------
        self.submodules.leds = LedChaser(
            pads         = platform.request_all("user_led"),
            sys_clk_freq = sys_clk_freq)

        # ICAP -------------------------------------------------------------------------------------
        self.submodules.icap = ICAP()
        self.icap.add_reload()
        self.icap.add_timing_constraints(platform, sys_clk_freq, self.crg.cd_sys.clk)

        # SPIFlash ---------------------------------------------------------------------------------
        self.submodules.flash_cs_n = GPIOOut(platform.request("flash_cs_n"))
        self.submodules.flash      = S7SPIFlash(platform.request("flash"), sys_clk_freq, 25e6)

        # PCIe -------------------------------------------------------------------------------------
        self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request(f"pcie_x2"),
            data_width = 64,
            bar0_size  = 0x20000,
            cd         = "pcie")
        self.add_pcie(phy=self.pcie_phy, ndmas=1,
            with_dma_buffering = True, dma_buffering_depth=1024,
            with_dma_loopback  = True,
            with_msi           = True
        )

        # I2C --------------------------------------------------------------------------------------
        i2c_busy  = Signal()
        i2c_ok    = Signal()
        i2c_sda0t = Signal()
        i2c_scl0t = Signal()
        i2c_sda0i = Signal()
        i2c_scl0i = Signal()
        i2c_sda1t = Signal()
        i2c_scl1t = Signal()
        i2c_sda1i = Signal()
        i2c_scl1i = Signal()
        if True:
            self.submodules.i2c0 = I2CMaster(platform.request("i2c", 0))
            self.submodules.i2c1 = I2CMaster(platform.request("i2c", 1))
        else:
            self.specials += Instance("xtrxinit",
                p_CLKFREQ = 65000000,
                p_I2CFREQ = 1000000,

                i_CLK  = ClockSignal("sys"),
                i_RST  = ResetSignal("sys"),
                o_BUSY = i2c_busy,
                o_OK   = i2c_ok,

                o_SDA0T = i2c_sda0t,
                o_SCL0T = i2c_scl0t,
                i_SDA0I = i2c_sda0i,
                i_SCL0I = i2c_scl0i,

                o_SDA1T = i2c_sda1t,
                o_SCL1T = i2c_scl1t,
                i_SDA1I = i2c_sda1i,
                i_SCL1I = i2c_scl1i,
            )
            i2c0_pads = platform.request("i2c", 0)
            i2c1_pads = platform.request("i2c", 1)
            self.specials += Tristate(i2c0_pads.scl, 0, ~i2c_scl0t, i2c_scl0i)
            self.specials += Tristate(i2c0_pads.sda, 0, ~i2c_sda0t, i2c_sda0i)
            self.specials += Tristate(i2c1_pads.scl, 0, ~i2c_scl1t, i2c_scl1i)
            self.specials += Tristate(i2c1_pads.sda, 0, ~i2c_sda1t, i2c_sda1i)
            platform.add_source("xtrxinit.vhd")
            platform.add_source("xtrxinitrom.vhd")

        # TCXO -------------------------------------------------------------------------------------
        self.submodules.tcxo = TCXO(platform.request("tcxo"))

        # LMS7002M ---------------------------------------------------------------------------------
        self.submodules.lms7002m = LMS7002M(platform.request("lms7002m"), sys_clk_freq)

        # Analyzer ---------------------------------------------------------------------------------
        if with_analyzer:
            analyzer_signals = [
                platform.lookup_request("tcxo").enable,
                platform.lookup_request("tcxo").sel,
                platform.lookup_request("tcxo").clk,
                i2c_busy,
                i2c_ok,
                i2c_sda0t,
                i2c_scl0t,
                i2c_sda0i,
                i2c_scl0i,
                i2c_sda1t,
                i2c_scl1t,
                i2c_sda1i,
                i2c_scl1i,
            ]
            self.submodules.analyzer = LiteScopeAnalyzer(analyzer_signals,
                depth        = 512,
                clock_domain = "sys",
                csr_csv      = "analyzer.csv"
            )

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on Fairwaves XTRX")
    parser.add_argument("--build",           action="store_true", help="Build bitstream")
    parser.add_argument("--load",            action="store_true", help="Load bitstream")
    parser.add_argument("--flash",           action="store_true", help="Flash bitstream")
    parser.add_argument("--driver",          action="store_true", help="Generate PCIe driver")
    args = parser.parse_args()

    soc = BaseSoC()
    builder = Builder(soc, csr_csv="csr.csv")
    builder.build(run=args.build)

    if args.driver:
        generate_litepcie_software(soc, "software")

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

    if args.flash:
        prog = soc.platform.create_programmer()
        prog.flash(0, os.path.join(builder.gateware_dir, soc.build_name + ".bin"))

if __name__ == "__main__":
    main()
