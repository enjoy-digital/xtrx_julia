#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.soc.interconnect.csr import *
from litex.soc.interconnect import stream

from litex.soc.cores.spi import SPIMaster

# LMS7002M -----------------------------------------------------------------------------------------

class LMS7002M(Module, AutoCSR):
    def __init__(self, pads, sys_clk_freq):
        # Endpoints.
        self.sink   = stream.Endpoint([("data", 64)])
        self.source = stream.Endpoint([("data", 64)])

        # CSRs.
        self.control = CSRStorage(fields=[
            CSRField("reset", size=1, offset=0, values=[
                ("``0b0``", "LMS7002M Normal Operation."),
                ("``0b1``", "LMS7002M Reset.")
            ], reset=0),
            CSRField("power_down", size=1, offset=1, values=[
                ("``0b0``", "LMS7002M Normal Operation."),
                ("``0b1``", "LMS7002M Power-Down.")
            ], reset=0),
            CSRField("tx_enable", size=1, offset=8, values=[
                ("``0b0``", "LMS7002M TX Disabled."),
                ("``0b1``", "LMS7002M TX Enabled.")
            ], reset=1),
            CSRField("rx_enable", size=1, offset=9, values=[
                ("``0b0``", "LMS7002M RX Disabled."),
                ("``0b1``", "LMS7002M RX Enabled.")
            ], reset=1),
            CSRField("tx_pattern_enable", size=1, offset=16, values=[
                ("``0b0``", "TX FPGA->LMS7002M Pattern Generator Disable."),
                ("``0b1``", "TX FPGA->LMS7002M Pattern Generator Enable.")
            ], reset=0),
            CSRField("tx_rx_loopback_enable", size=1, offset=17, values=[
                ("``0b0``", "TX-RX FPGA Loopback Disable."),
                ("``0b1``", "TX-RX FPGA Loopback Enable.")
            ], reset=0),

        ])
        self.cycles_latch   = CSR()
        self.cycles         = CSRStatus(32)

        # # #

        # TX/RX Data/Frame.
        # -----------------
        self.tx_frame = tx_frame = Signal()
        self.tx_data  = tx_data  = Signal(32)
        self.rx_frame = rx_frame = Signal()
        self.rx_data  = rx_data  = Signal(32)

        # Drive Control Pins.
        # -------------------
        self.comb += [
            pads.rst_n.eq(~self.control.fields.reset),
            pads.pwrdwn_n.eq(~self.control.fields.power_down),
            pads.txen.eq(self.control.fields.tx_enable),
            pads.rxen.eq(self.control.fields.rx_enable),
        ]

        # SPI.
        # ----
        self.submodules.spi = SPIMaster(
            pads         = pads,
            data_width   = 32,
            sys_clk_freq = sys_clk_freq,
            spi_clk_freq = 1e6
        )

        # Clocking.
        # ----------------
        self.clock_domains.cd_rfic_rx = ClockDomain("rfic_rx")
        self.clock_domains.cd_rfic_tx = ClockDomain("rfic_tx")

        # RX & Measurement.
        self.comb += self.cd_rfic_rx.clk.eq(pads.mclk1)
        cycles = Signal(32)
        self.sync.rfic_rx += cycles.eq(cycles + 1)
        self.sync += If(self.cycles_latch.re, self.cycles.status.eq(cycles))

        # TX.
        self.comb += self.cd_rfic_tx.clk.eq(pads.mclk1)

        # TX Datapath.
        # ------------

        # FIXME: Add proper Clk Phase support/calibration without ODELAYE2.
        self.submodules.tx_cdc  = tx_cdc  = stream.ClockDomainCrossing([("data", 64)], cd_from="sys", cd_to="rfic_tx")
        self.submodules.tx_conv = tx_conv = ClockDomainsRenamer("rfic_tx")(stream.Converter(64, 32))
        self.comb += self.sink.connect(tx_cdc.sink)
        self.comb += tx_cdc.source.connect(tx_conv.sink)

        # TX Pattern (Counter).
        tx_pattern = Signal(32)
        self.sync.rfic_tx += tx_pattern.eq(tx_pattern + 1)

        # Pattern/Data Mux.
        self.comb += [
            If(self.control.fields.tx_pattern_enable,
                tx_data.eq(tx_pattern),
            ).Else(
                tx_conv.source.ready.eq(1),
                tx_data.eq(tx_conv.source.data)
            )
        ]

        # TX Clk.
        self.specials += Instance("ODDR",
            p_DDR_CLK_EDGE = "SAME_EDGE",
            i_C  = ClockSignal("rfic_tx"),
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D1 = 1,
            i_D2 = 0,
            o_Q  = pads.fclk2
        )

        # TX Frame.
        self.sync.rfic_tx += tx_frame.eq(~tx_frame)
        self.specials += Instance("ODDR",
            p_DDR_CLK_EDGE = "SAME_EDGE",
            i_C  = ClockSignal("rfic_tx"),
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D1 = tx_frame,
            i_D2 = tx_frame,
            o_Q  = pads.iqsel2
        )

        # TX Data.
        for n in range(12):
            self.specials += Instance("ODDR",
                p_DDR_CLK_EDGE = "SAME_EDGE",
                i_C  = ClockSignal("rfic_tx"),
                i_CE = 1,
                i_S  = 0,
                i_R  = 0,
                i_D1 = tx_data[n +  0],
                i_D2 = tx_data[n + 16],
                o_Q  = pads.diq2[n]
            )

        # RX Datapath.
        # ------------
        # FIXME: Add proper Clk Phase support/calibration.
        self.submodules.rx_cdc  = rx_cdc  = stream.ClockDomainCrossing([("data", 64)], cd_from="rfic_rx", cd_to="sys")
        self.submodules.rx_conv = rx_conv = ClockDomainsRenamer("rfic_rx")(stream.Converter(32, 64))
        self.comb += rx_conv.source.connect(rx_cdc.sink)
        self.comb += rx_cdc.source.connect(self.source)

        # TX-RX Loopback/Data Mux.
        self.comb += [
            rx_conv.sink.valid.eq(1),
            If(self.control.fields.tx_rx_loopback_enable,
                rx_conv.sink.data.eq(tx_data & 0x0fff0fff) # 12-bit masking, similar to LMS7002M internalloopback.
            ).Else(
                rx_conv.sink.data.eq(rx_data)
            )
        ]

        # RX Frame.
        self.specials += Instance("IDDR",
            p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
            i_C  = ClockSignal("rfic_rx"),
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D  = pads.iqsel1,
            o_Q1 = rx_frame,
            o_Q2 = Signal(),
        )

        # RX Data.
        for n in range(12):
            self.specials += Instance("IDDR",
                p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
                i_C  = ClockSignal("rfic_rx"),
                i_CE = 1,
                i_S  = 0,
                i_R  = 0,
                i_D  = pads.diq1[n],
                o_Q1 = rx_data[n + 16],
                o_Q2 = rx_data[n + 0],
            )
