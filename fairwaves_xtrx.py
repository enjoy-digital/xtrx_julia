#!/usr/bin/env python3

#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# Build/Use ----------------------------------------------------------------------------------------
# Build/Flash bitstream:
# ./fairwaves_xtrx.py --build --driver --flash
#
#.Build the kernel and load it:
# cd build/<platform>/driver/kernel
# make
# sudo ./init.sh
#
# Test userspace utilities:
# cd build/<platform>/driver/user
# make
# ./litepcie_util info
# ./litepcie_util scratch_test
# ./litepcie_util dma_test

import os
import argparse
import sys

from migen import *

import fairwaves_xtrx_platform as fairwaves_xtrx

from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litex.soc.cores.led import LedChaser
from litex.soc.cores.clock import *

from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.software import generate_litepcie_software

# CRG ----------------------------------------------------------------------------------------------

class CRG(Module):
    def __init__(self, platform, sys_clk_freq, with_pcie=False):
        self.clock_domains.cd_sys = ClockDomain()

        # # #

        if with_pcie:
            assert sys_clk_freq == int(125e6)
            self.comb += [
                self.cd_sys.clk.eq(ClockSignal("pcie")),
                self.cd_sys.rst.eq(ResetSignal("pcie")),
            ]
        else:
            cfgmclk = Signal()
            self.specials += Instance("STARTUPE2",
                i_CLK       = 0,
                i_GSR       = 0,
                i_GTS       = 0,
                i_KEYCLEARB = 1,
                i_PACK      = 0,
                i_USRCCLKO  = cfgmclk,
                i_USRCCLKTS = 0,
                i_USRDONEO  = 1,
                i_USRDONETS = 1,
                o_CFGMCLK   = cfgmclk
            )
            self.comb += self.cd_sys.clk.eq(cfgmclk)
            self.submodules.pll = pll = S7PLL(speedgrade=-2)
            pll.register_clkin(cfgmclk, 65e6)
            pll.create_clkout(self.cd_sys, sys_clk_freq)

# BaseSoC -----------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=int(125e6), with_pcie=True, pcie_lanes=2, with_led_chaser=True):
        platform = fairwaves_xtrx.Platform()

        # SoCMini ----------------------------------------------------------------------------------
        SoCMini.__init__(self, platform, sys_clk_freq,
            ident          = "LiteX SoC on Fairwaves XTRX",
            ident_version  = True
        )

        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = CRG(platform, sys_clk_freq, with_pcie)

        # JTAGBone ---------------------------------------------------------------------------------
        self.add_jtagbone()

        # PCIe -------------------------------------------------------------------------------------
        if with_pcie:
            self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request(f"pcie_x{pcie_lanes}"),
                data_width = 64,
                bar0_size  = 0x20000)
            self.add_pcie(phy=self.pcie_phy, ndmas=1)

            # ICAP (For FPGA reload over PCIe).
            from litex.soc.cores.icap import ICAP
            self.submodules.icap = ICAP()
            self.icap.add_reload()
            self.icap.add_timing_constraints(platform, sys_clk_freq, self.crg.cd_sys.clk)

            # Flash (For SPIFlash update over PCIe). FIXME: Should probably be updated to use SpiFlashSingle/SpiFlashDualQuad (so MMAPed and do the update with bit-banging)
            from litex.soc.cores.gpio import GPIOOut
            from litex.soc.cores.spi_flash import S7SPIFlash
            self.submodules.flash_cs_n = GPIOOut(platform.request("flash_cs_n"))
            self.submodules.flash      = S7SPIFlash(platform.request("flash"), sys_clk_freq, 25e6)


        # Leds -------------------------------------------------------------------------------------
        if with_led_chaser:
            self.submodules.leds = LedChaser(
                pads         = platform.request_all("user_led"),
                sys_clk_freq = sys_clk_freq)

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on Fairwaves XTRX")
    parser.add_argument("--build",           action="store_true", help="Build bitstream")
    parser.add_argument("--load",            action="store_true", help="Load bitstream")
    parser.add_argument("--flash",           action="store_true", help="Flash bitstream")
    parser.add_argument("--sys-clk-freq",    default=125e6,       help="System clock frequency (default: 125MHz)")
    parser.add_argument("--driver",          action="store_true", help="Generate PCIe driver")
    builder_args(parser)
    args = parser.parse_args()

    soc = BaseSoC(sys_clk_freq = int(float(args.sys_clk_freq)))
    builder  = Builder(soc, **builder_argdict(args))
    builder.build(run=args.build)

    if args.driver:
        generate_litepcie_software(soc, os.path.join(builder.output_dir, "driver"))

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

    if args.flash:
        prog = soc.platform.create_programmer()
        prog.flash(0, os.path.join(builder.gateware_dir, soc.build_name + ".bin"))

if __name__ == "__main__":
    main()
