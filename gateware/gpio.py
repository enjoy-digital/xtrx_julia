#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.soc.interconnect.csr import *
from litex.soc.interconnect import stream

from litex.soc.cores.spi import SPIMaster

# GPIO ---------------------------------------------------------------------------------------------

class GPIO(Module, AutoCSR):
    def __init__(self, pads):
        # CSRs.
        self.control = CSRStorage(fields=[
            CSRField("gpio0",  size=1, offset=0, reset=0),
            CSRField("gpio1",  size=1, offset=1, reset=0),
            CSRField("gpio2",  size=1, offset=2, reset=0),
            CSRField("gpio3",  size=1, offset=3, reset=0),
            CSRField("gpio4",  size=1, offset=4, reset=0),
            CSRField("gpio5",  size=1, offset=5, reset=0),
            CSRField("gpio6",  size=1, offset=6, reset=0),
        ])

        # # #

        # Drive Control Pins.
        self.comb += [
            pads[0].eq(self.control.fields.gpio0),
            pads[1].eq(self.control.fields.gpio1),
            pads[2].eq(self.control.fields.gpio2),
            pads[3].eq(self.control.fields.gpio3),
            pads[4].eq(self.control.fields.gpio4),
            pads[5].eq(self.control.fields.gpio5),
            pads[6].eq(self.control.fields.gpio6),
        ]
