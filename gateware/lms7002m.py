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
    def __init__(self, pads, sys_clk_freq, with_fake_datapath=True):
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
            ]),
            CSRField("rx_enable", size=1, offset=9, values=[
                ("``0b0``", "LMS7002M RX Disabled."),
                ("``0b1``", "LMS7002M RX Enabled.")
            ]),
        ])
        self.cycles_latch = CSR()
        self.cycles       = CSRStatus(32)

        # # #

        # Drive Control Pins.
        self.comb += [
            pads.rst_n.eq(~self.control.fields.reset),
            pads.pwrdwn_n.eq(~self.control.fields.power_down), # FIXME: Check polarity.
            pads.txen.eq(self.control.fields.tx_enable),       # FIXME: Check polarity.
            pads.rxen.eq(self.control.fields.rx_enable),       # FIXME: Check polarity.
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
        self.comb += self.cd_rfic.clk.eq(pads.mclk2)

        cycles = Signal(32)
        self.sync.rfic += cycles.eq(cycles + 1)
        self.sync += If(self.cycles_latch.re, self.cycles.status.eq(cycles))

        # Data-Path.
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
