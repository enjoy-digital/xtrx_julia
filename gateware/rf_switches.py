#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import PulseSynchronizer

from litex.soc.interconnect.csr import *

# RF Switches --------------------------------------------------------------------------------------

class RFSwitches(Module, AutoCSR):
    def __init__(self, pads):
        self.tx = CSRStorage()
        self.rx = CSRStorage(2)

        # # #

        # Drive RF Switches.
        self.sync += [
            pads.tx.eq(self.tx.storage),
            pads.rx.eq(self.rx.storage),
        ]
