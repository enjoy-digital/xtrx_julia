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
    def __init__(self, pads, sys_clk_freq, with_fake_datapath=False):
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
        ])
        self.cycles_latch   = CSR()
        self.cycles         = CSRStatus(32)

        # # #

        # TX/RX Data/Frame.
        self.tx_frame = tx_frame = Signal()
        self.tx_data  = tx_data  = Signal(32)
        self.rx_frame = rx_frame = Signal()
        self.rx_data  = rx_data  = Signal(32)

        # Drive Control Pins.
        self.comb += [
            pads.rst_n.eq(~self.control.fields.reset),
            pads.pwrdwn_n.eq(~self.control.fields.power_down),
            pads.txen.eq(self.control.fields.tx_enable),
            pads.rxen.eq(self.control.fields.rx_enable),
        ]

        # SPI.
        self.submodules.spi = SPIMaster(
            pads         = pads,
            data_width   = 32,
            sys_clk_freq = sys_clk_freq,
            spi_clk_freq = 1e6
        )

        # Clk-Measurement.
        self.clock_domains.cd_rfic = ClockDomain("rfic")
        self.comb += self.cd_rfic.clk.eq(pads.mclk1)

        cycles = Signal(32)
        self.sync.rfic += cycles.eq(cycles + 1)
        self.sync += If(self.cycles_latch.re, self.cycles.status.eq(cycles))

        # Data-Path.
        self.pattern_enable = CSRStorage(reset=0) # Quick Test, Remove or intergrate correctly.
        if with_fake_datapath:
            conv_64_to_16 = stream.Converter(64, 16)
            conv_16_to_64 = stream.Converter(16, 64)
            self.submodules += conv_64_to_16, conv_16_to_64
            self.comb += [
                self.sink.connect(conv_64_to_16.sink, keep={"valid", "ready", "data"}),
                conv_64_to_16.source.connect(conv_16_to_64.sink,  keep={"valid", "ready"}),
                conv_16_to_64.sink.data.eq(conv_64_to_16.source.data[:12]), # Only keep 12-bit.
                conv_16_to_64.source.connect(self.source, keep={"valid", "ready", "data"}),
            ]
        else:
            # TX Datapath --------------------------------------------------------------------------
            # FIXME: Add proper Clk Phase support/calibration without ODELAYE2.
            self.submodules.tx_cdc  = tx_cdc  = stream.ClockDomainCrossing([("data", 64)], cd_from="sys", cd_to="rfic")
            self.submodules.tx_conv = tx_conv = ClockDomainsRenamer("rfic")(stream.Converter(64, 32))
            self.comb += self.sink.connect(tx_cdc.sink)
            self.comb += tx_cdc.source.connect(tx_conv.sink)

            # Pattern/Data Mux.
            self.comb += tx_conv.source.ready.eq(1)
            self.sync.rfic += [
                If(self.pattern_enable.storage,
                    tx_data.eq(tx_data + 1),
                ).Else(
                    tx_data.eq(tx_conv.source.data)
                )
            ]

            # TX Clk.
            self.specials += Instance("ODDR",
                p_DDR_CLK_EDGE = "SAME_EDGE",
                i_C  = ClockSignal("rfic"),
                i_CE = 1,
                i_S  = 0,
                i_R  = 0,
                i_D1 = 1,
                i_D2 = 0,
                o_Q  = pads.fclk2
            )

            # TX Frame.
            self.sync.rfic += tx_frame.eq(~tx_frame)
            self.specials += Instance("ODDR",
                p_DDR_CLK_EDGE = "SAME_EDGE",
                i_C  = ClockSignal("rfic"),
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
                    i_C  = ClockSignal("rfic"),
                    i_CE = 1,
                    i_S  = 0,
                    i_R  = 0,
                    i_D1 = tx_data[n +  0],
                    i_D2 = tx_data[n + 16],
                    o_Q  = pads.diq2[n]
                )

            # RX Datapath --------------------------------------------------------------------------
            # FIXME: Add proper Clk Phase support/calibration.
            self.submodules.rx_cdc  = rx_cdc  = stream.ClockDomainCrossing([("data", 64)], cd_from="rfic", cd_to="sys")
            self.submodules.rx_conv = rx_conv = ClockDomainsRenamer("rfic")(stream.Converter(32, 64))
            self.comb += rx_conv.source.connect(rx_cdc.sink)
            self.comb += rx_cdc.source.connect(self.source)

            # Pattern/Data Mux.
            self.comb += rx_conv.sink.valid.eq(1)
            self.comb += rx_conv.sink.data.eq(rx_data)
            self.comb += If(self.pattern_enable.storage, rx_cdc.source.ready.eq(1))

            # RX Frame.
            self.specials += Instance("IDDR",
                p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
                i_C  = ClockSignal("rfic"),
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
                    i_C  = ClockSignal("rfic"),
                    i_CE = 1,
                    i_S  = 0,
                    i_R  = 0,
                    i_D  = pads.diq1[n],
                    o_Q1 = rx_data[n + 16],
                    o_Q2 = rx_data[n + 0],
                )
