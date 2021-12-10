#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.soc.interconnect.csr import *

from litex.soc.cores.spi import SPIMaster

# LMS7002M -----------------------------------------------------------------------------------------

class LMS7002M(Module, AutoCSR):
    def __init__(self, pads, sys_clk_freq):
        self.control = CSRStorage(fields=[
            CSRField("reset", size=1, offset=0, values=[
                ("``0b0``", "LMS7002M Normal Operation."),
                ("``0b1``", "LMS7002M Reset.")
            ], reset=1),
            CSRField("power_down", size=1, offset=1, values=[
                ("``0b0``", "LMS7002M Normal Operation."),
                ("``0b1``", "LMS7002M Power-Down.")
            ], reset=1),
            CSRField("tx_enable", size=1, offset=8, values=[
                ("``0b0``", "LMS7002M TX Disabled."),
                ("``0b1``", "LMS7002M TX Enabled.")
            ]),
            CSRField("rx_enable", size=1, offset=9, values=[
                ("``0b0``", "LMS7002M RX Disabled."),
                ("``0b1``", "LMS7002M RX Enabled.")
            ]),
        ])

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

        # Data-Path.
        # TODO.
