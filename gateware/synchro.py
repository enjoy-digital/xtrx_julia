#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import MultiReg

from litex.build.io import DDROutput

from litex.soc.interconnect.csr import *

# Synchro ------------------------------------------------------------------------------------------

class Synchro(Module, AutoCSR):
    def __init__(self, pads):
        self.control = CSRStorage(fields=[
            CSRField("int_source", offset=0, size=4, values=[
                ("``0b0000``", "PPS Disabled."),
                ("``0b0001``", "PPS GPS."),
                ("``0b0010``", "PPS In (Ext)."),
            ], reset=0b0000),
            CSRField("out_source", offset=4, size=4, values=[
                ("``0b0000``", "PPS Disabled."),
                ("``0b0001``", "PPS GPS."),
                ("``0b0010``", "PPS In (Ext)."),
            ], reset=0b0000),
        ])
        self.status  = CSRStorage()

        # PPS Sources.
        self.pps_gps = Signal()

        # PPS Selected.
        self.pps = Signal()

        # # #

        # PPS GPS (Already resynchronized in GPS Module).
        _pps_gps = self.pps_gps

        # PPS In (From IO, has to be resynchronized).
        _pps_in = Signal()
        self.specials += MultiReg(pads.pps_in, _pps_in)

        # PPS Internal Selection.
        self.comb += Case(self.control.fields.int_source, {
            0b0000 : self.pps.eq(0),
            0b0001 : self.pps.eq(_pps_gps),
            0b0010 : self.pps.eq(_pps_in)
            }
        )

        # PPS Output Selection/Generation.
        _pps_out = Signal()
        self.comb += Case(self.control.fields.out_source, {
            0b0000 : _pps_out.eq(0),
            0b0001 : _pps_out.eq(_pps_gps),
            0b0010 : _pps_out.eq(_pps_in)
            }
        )
        self.specials += DDROutput(
            i1 = _pps_out,
            i2 = 0,
            o  = pads.pps_out
        )
