#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import PulseSynchronizer

from litex.soc.interconnect.csr import *

# VCTCXO --------------------------------------------------------------------------------------------

class VCTCXO(Module, AutoCSR):
    def __init__(self, pads):
        self.control = CSRStorage(fields=[
            CSRField("sel", size=1, offset=0, values=[
                ("``0b0``", "Use VCTCXO Clk."),
                ("``0b1``", "Use External Clk.")
            ], reset=0),
            CSRField("en", size=1, offset=1, values=[
                ("``0b0``", "Disable VCTCXO"),
                ("``0b1``", "Enable VCTCXO")
            ], reset=1),
        ])
        self.cycles_latch = CSR()
        self.cycles       = CSRStatus(32, reset=0)

        # # #

        # Drive Control Pins.
        self.comb += [
            pads.sel.eq(self.control.fields.sel),
            pads.en.eq(1)
            # TODO:
            # The stock firmware has the above pin on a CSR.
            # Uncommenting the line below leads to the VCTCXO counter
            # failing to initialize.
            # Oddly, the reset value for 'en' does not seem to be respected either, though
            # the generated Verilog code has the correct value.
            # This also leads to X values on all values probed via litescope
            #pads.en.eq(self.control.fields.en)
        ]

        # Clock Input.
        self.clock_domains.cd_txco = ClockDomain("vctcxo")
        self.comb += self.cd_txco.clk.eq(pads.clk)

        # Cycles Count.
        self.cycles_count = Signal(32)
        self.sync.vctcxo += self.cycles_count.eq(self.cycles_count + 1)
        self.sync += If(self.cycles_latch.re, self.cycles.status.eq(self.cycles_count))
