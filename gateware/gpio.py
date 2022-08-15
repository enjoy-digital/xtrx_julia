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
            #CSRField("iovcc_sel",  size=1, offset=0, reset=0),
            #CSRField("en_smsigio", size=1, offset=1, reset=0),
        ])

        # # #

        # Drive Control Pins.
        self.comb += [
            #pads.iovcc_sel.eq(self.control.fields.iovcc_sel),   # FIXME: Check polarity.
            #pads.en_smsigio.eq(self.control.fields.en_smsigio), # FIXME: Check polarity.
        ]
