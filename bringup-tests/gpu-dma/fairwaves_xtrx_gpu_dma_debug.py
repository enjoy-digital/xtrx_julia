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

        # JTAGBone ---------------------------------------------------------------------------------
        self.add_jtagbone()

        # PCIe -------------------------------------------------------------------------------------
        self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request("pcie_x1"),
            data_width = 64,
            bar0_size  = 0x20000)
        self.add_pcie(phy=self.pcie_phy, ndmas=1, max_pending_requests=2)


        # ICAP (For FPGA reload over PCIe).
        from litex.soc.cores.icap import ICAP
        self.submodules.icap = ICAP()
        self.icap.add_reload()
        self.icap.add_timing_constraints(platform, sys_clk_freq, self.crg.cd_sys.clk)

        # Flash (For SPIFlash update over PCIe).
        from litex.soc.cores.gpio import GPIOOut
        from litex.soc.cores.spi_flash import S7SPIFlash
        self.submodules.flash_cs_n = GPIOOut(platform.request("flash_cs_n"))
        self.submodules.flash      = S7SPIFlash(platform.request("flash"), sys_clk_freq, 25e6)

        # DMA Stub ---------------------------------------------------------------------------------

        # DMA Writer: Send Counter.
        sink_data = Signal(32)
        self.comb += self.pcie_dma0.sink.valid.eq(1)
        self.comb += self.pcie_dma0.sink.data.eq(sink_data)
        self.sync += If(self.pcie_dma0.sink.ready, sink_data.eq(sink_data + 1))

        # DMA Reader: Ack incoming Data.
        self.comb += self.pcie_dma0.source.ready.eq(1)

        # Simple PCIe Read/Write Tester  -----------------------------------------------------------
        from litepcie.frontend.wishbone import LitePCIeWishboneSlave

        pcie_wishbone_slave = LitePCIeWishboneSlave(self.pcie_endpoint)
        self.submodules += pcie_wishbone_slave

        class PCIeTester(Module, AutoCSR):
            def __init__(self, endpoint, wb):
                self.address    = CSRStorage(32)
                self.write      = CSR()
                self.write_data = CSRStorage(32, reset=0x12345678)
                self.read       = CSR()
                self.read_data  = CSRStatus(32)
                self.done       = CSRStatus()
                self.req_id     = CSRStatus(16)

                # # #

                self.comb += self.req_id.status.eq(endpoint.phy.id)

                self.submodules.fsm = fsm = FSM(reset_state="IDLE")
                fsm.act("IDLE",
                    self.done.status.eq(1),
                    If(self.write.re,
                        NextState("WRITE")
                    ).Elif(self.read.re,
                        NextState("READ")
                    )
                )
                fsm.act("WRITE",
                    wb.stb.eq(1),
                    wb.cyc.eq(1),
                    wb.we.eq(1),
                    wb.adr.eq(self.address.storage[2:]),
                    wb.dat_w.eq(self.write_data.storage),
                    If(wb.ack,
                        NextState("IDLE")
                    )
                )
                fsm.act("READ",
                    wb.stb.eq(1),
                    wb.cyc.eq(1),
                    wb.adr.eq(self.address.storage[2:]),
                    If(wb.ack,
                        NextValue(self.read_data.status, wb.dat_r),
                        NextState("IDLE")
                    )
                )
        self.submodules.pcie_tester = PCIeTester(self.pcie_endpoint, pcie_wishbone_slave.wishbone)

        # Analyzer ---------------------------------------------------------------------------------
        from litescope import LiteScopeAnalyzer
        analyzer_signals = [
            self.pcie_endpoint.depacketizer.cmp_source
        ]
        self.submodules.analyzer = LiteScopeAnalyzer(analyzer_signals,
            depth        = 256,
            clock_domain = "sys",
            csr_csv      = "analyzer.csv")

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
    builder  = Builder(soc, csr_csv="csr.csv")
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
