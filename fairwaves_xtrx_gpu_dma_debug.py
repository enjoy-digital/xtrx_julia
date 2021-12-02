#!/usr/bin/env python3

#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# Build/Use ----------------------------------------------------------------------------------------
# Build/Flash bitstream:
# ./fairwaves_xtrx.py --build --driver --flash


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
    def __init__(self, platform, sys_clk_freq):
        self.clock_domains.cd_sys = ClockDomain()

        # # #

        assert sys_clk_freq == int(125e6)
        self.comb += [
            self.cd_sys.clk.eq(ClockSignal("pcie")),
            self.cd_sys.rst.eq(ResetSignal("pcie")),
        ]

# BaseSoC -----------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=int(125e6), with_pcie=True, with_led_chaser=True, **kwargs):
        platform = fairwaves_xtrx.Platform()

        # SoCCore ----------------------------------------------------------------------------------
        if kwargs["uart_name"] == "serial":
            kwargs["uart_name"] = "crossover"
        SoCCore.__init__(self, platform, sys_clk_freq,
            ident          = "LiteX SoC on Fairwaves XTRX GPU/DMA Debug",
            ident_version  = True,
            **kwargs)

        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = CRG(platform, sys_clk_freq)

        # PCIe -------------------------------------------------------------------------------------
        self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request("pcie_x1"),
            data_width = 64,
            bar0_size  = 0x20000)
        self.add_pcie(phy=self.pcie_phy, ndmas=1, max_pending_requests=2)

        # DMA Stub ---------------------------------------------------------------------------------

        # DMA Writer: Send Counter.
        sink_data = Signal(32)
        self.comb += self.pcie_dma0.sink.valid.eq(1)
        self.comb += self.pcie_dma0.sink.data.eq(sink_data)
        self.sync += If(self.pcie_dma0.sink.ready, sink_data.eq(sink_data + 1))

        # DMA Reader: Ack incoming Data.
        self.comb += self.pcie_dma0.source.ready.eq(1)

        # Leds -------------------------------------------------------------------------------------
        if with_led_chaser:
            self.submodules.leds = LedChaser(
                pads         = platform.request_all("user_led"),
                sys_clk_freq = sys_clk_freq)

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on Fairwaves XTRX / GPU/DMA Debug")
    parser.add_argument("--build",           action="store_true", help="Build bitstream")
    parser.add_argument("--load",            action="store_true", help="Load bitstream")
    parser.add_argument("--flash",           action="store_true", help="Flash bitstream")
    parser.add_argument("--sys-clk-freq",    default=125e6,       help="System clock frequency (default: 125MHz)")
    parser.add_argument("--driver",          action="store_true", help="Generate PCIe driver")
    builder_args(parser)
    soc_core_args(parser)
    args = parser.parse_args()

    soc = BaseSoC(
        sys_clk_freq = int(float(args.sys_clk_freq)),
        **soc_core_argdict(args)
    )
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
