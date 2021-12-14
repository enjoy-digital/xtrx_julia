#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import PulseSynchronizer

from litex.soc.interconnect.csr import *

# TCXO ---------------------------------------------------------------------------------------------

class TCXO(Module, AutoCSR):
    def __init__(self, pads):
        self.control = CSRStorage(fields=[
            CSRField("sel", size=1, offset=0, values=[
                ("``0b0``", "Use TCXO Clk."),
                ("``0b1``", "Use External Clk.")
            ], reset=0),
        ])
        self.cycles_latch = CSR()
        self.cycles       = CSRStatus(32)

        # # #

        # Drive Control Pins.
        self.comb += pads.sel.eq(self.control.fields.sel)

        # Clock Input.
        self.clock_domains.cd_txco = ClockDomain("tcxo")
        self.comb += self.cd_txco.clk.eq(pads.clk)

        # Cycles Count.
        cycles = Signal(32)
        self.sync.tcxo += cycles.eq(cycles + 1)
        self.sync += If(self.cycles_latch.re, self.cycles.status.eq(cycles))
