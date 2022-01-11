#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect.csr import *
from litex.soc.interconnect import stream
from litex.soc.cores.prbs import PRBS7Generator, PRBS7Checker

from litex.soc.cores.spi import SPIMaster

# TX/RX Pattern Generator/Checker ------------------------------------------------------------------

class TXPatternGenerator(Module, AutoCSR):
    def __init__(self):
        self.source  = stream.Endpoint([("data", 32)])
        self.control = CSRStorage(fields=[
            CSRField("enable", size=1, offset=0, values=[
                ("``0b0``", "Disable module."),
                ("``0b1``", "Enable module.")
            ], reset=0),
            CSRField("mode", size=1, offset=1, values=[
                ("``0b0``", "Count mode."),
                ("``0b1``", "PRBS31 mode.")
            ], reset=0),
        ])

        # # #

        enable = Signal()
        mode   = Signal()
        self.specials += MultiReg(self.control.fields.enable, enable, "rfic")
        self.specials += MultiReg(self.control.fields.mode,   mode,   "rfic")

        # Control-Path.
        # -------------
        self.comb      += self.source.valid.eq(enable)
        self.sync.rfic += self.source.last.eq(~self.source.last)

        # Generators.
        # -----------

        # Counter.
        count = Signal(12)
        self.sync.rfic += [
            # Reset Count when disabled.
            If(~enable,
                count.eq(0)
            # Increment Count when enabled.
            ).Else(
                count.eq(count + 1)
            )
        ]

        # PRBS.
        gen = PRBS7Generator(32)
        gen = ClockDomainsRenamer("rfic")(gen)
        gen = ResetInserter()(gen)
        self.submodules += gen
        # Reset PRBS when disabled.
        self.comb += gen.reset.eq(~enable)

        # Data-Path.
        # ----------
        self.sync.rfic += [
            If(mode,
                self.source.data.eq(gen.o)
            ).Else(
                self.source.data[ 0:16].eq(count),
                self.source.data[16:32].eq(count),
            )
        ]


class RXPatternChecker(Module, AutoCSR):
    def __init__(self):
        self.sink    = stream.Endpoint([("data", 32)])
        self.control = CSRStorage(fields=[
            CSRField("enable", size=1, offset=0, values=[
                ("``0b0``", "Disable module."),
                ("``0b1``", "Enable module.")
            ], reset=0),
            CSRField("mode", size=1, offset=1, values=[
                ("``0b0``", "Count mode."),
                ("``0b1``", "PRBS31 mode.")
            ], reset=0),
        ])
        self.errors = CSRStatus(32)

        # # #

        enable = Signal()
        mode   = Signal()
        self.specials += MultiReg(self.control.fields.enable, enable, "rfic")
        self.specials += MultiReg(self.control.fields.mode,   mode,   "rfic")

        count_error = Signal()
        prbs_error  = Signal()

        # Control-Path.
        # -------------
        self.comb += self.sink.ready.eq(enable)

        # Checkers/Data-Path.
        # -------------------

        # Counter.
        count = Signal(12)
        self.sync.rfic += count.eq(self.sink.data[0:12])
        self.comb += If(self.sink.data[0:12]  != (count + 1), count_error.eq(1))
        #self.comb += If(self.sink.data[16:28] != (count + 1), count_error.eq(1))

        # PRBS. FIXME: Add 12-bit masking.
        check = PRBS7Checker(32)
        check = ClockDomainsRenamer("rfic")(check)
        self.submodules += check
        self.comb += check.i.eq(self.sink.data)
        self.comb += prbs_error.eq(check.errors)

        # Errors.
        # -------
        errors = self.errors.status # FIXME: CDC.
        self.sync.rfic += [
            If(~enable,
                errors.eq(0)
            ).Else(
                If(( self.control.fields.mode &  prbs_error) |
                   (~self.control.fields.mode & count_error),
                    errors.eq(errors + 1),
                )
            )
        ]

# LMS7002M -----------------------------------------------------------------------------------------

class LMS7002M(Module, AutoCSR):
    def __init__(self, platform, pads, sys_clk_freq):
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
            CSRField("tx_rx_loopback_enable", size=1, offset=16, values=[
                ("``0b0``", "TX-RX FPGA Loopback Disable."),
                ("``0b1``", "TX-RX FPGA Loopback Enable.")
            ], reset=0),

        ])
        self.cycles_latch   = CSR()
        self.cycles         = CSRStatus(32)

        # # #

        # TX/RX Data/Frame.
        # -----------------
        self.tx_frame = tx_frame = Signal(2)
        self.tx_data  = tx_data  = Signal(32)
        self.rx_frame = rx_frame = Signal(2)
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
        self.clock_domains.cd_rfic = ClockDomain("rfic")
        self.comb += self.cd_rfic.clk.eq(pads.mclk1)

        cycles = Signal(32)
        self.sync.rfic += cycles.eq(cycles + 1)
        self.sync += If(self.cycles_latch.re, self.cycles.status.eq(cycles))

        # TX Datapath.
        # ------------
        self.submodules.tx_cdc     = tx_cdc     = stream.ClockDomainCrossing([("data", 64)], cd_from="sys", cd_to="rfic")
        self.submodules.tx_conv    = tx_conv    = ClockDomainsRenamer("rfic")(stream.Converter(64, 32))
        self.submodules.tx_pattern = tx_pattern = TXPatternGenerator()
        self.comb += self.sink.connect(tx_cdc.sink)
        self.comb += tx_cdc.sink.last.eq(1)
        self.comb += tx_cdc.source.connect(tx_conv.sink)

        # TX Pattern/Data Mux.
        self.comb += [
            # Get Data from TX Pattern when valid...
            If(tx_pattern.source.valid,
                tx_frame.eq(Replicate(tx_pattern.source.last, 2)),
                tx_data.eq(tx_pattern.source.data),
            # ... Else from DMA -> CDC -> DownConverter.
            ).Else(
                tx_conv.source.ready.eq(1),
                tx_frame.eq(Replicate(tx_conv.source.last, 2)),
                tx_data.eq(tx_conv.source.data),
            )
        ]

        # TX Clk.
        self.tx_clk_rst = CSR()
        self.tx_clk_inc = CSR()
        rfic_tx_clk = Signal()
        self.specials += Instance("IDELAYE2",
            p_IDELAY_TYPE      = "VARIABLE",
            p_IDELAY_VALUE     = 0,
            p_REFCLK_FREQUENCY = 200e6/1e6,
            p_DELAY_SRC        = "DATAIN",
            i_C        = ClockSignal("sys"),
            i_LD       = self.tx_clk_rst.re,
            i_CE       = self.tx_clk_inc.re,
            i_LDPIPEEN = 0,
            i_INC      = 1,
            i_DATAIN   = ClockSignal("rfic"),
            o_DATAOUT  = rfic_tx_clk,
        )
        self.specials += Instance("ODDR",
            p_DDR_CLK_EDGE = "SAME_EDGE",
            i_C  = rfic_tx_clk,
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D1 = 0,
            i_D2 = 1,
            o_Q  = pads.fclk2
        )

        # TX Frame.
        self.specials += Instance("ODDR",
            p_DDR_CLK_EDGE = "SAME_EDGE",
            i_C  = ClockSignal("rfic"),
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D1 = tx_frame[0],
            i_D2 = tx_frame[1],
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

        # RX Datapath.
        # ------------
        self.submodules.rx_conv    = rx_conv    = ClockDomainsRenamer("rfic")(stream.Converter(32, 64))
        self.submodules.rx_pattern = rx_pattern = RXPatternChecker()
        self.submodules.rx_cdc     = rx_cdc     = stream.ClockDomainCrossing([("data", 64)], cd_from="rfic", cd_to="sys")
        self.comb += rx_conv.source.connect(rx_cdc.sink)
        self.comb += rx_cdc.source.connect(self.source)

        # RX Frame. FIXME: Add IDELAYE2.
        self.specials += Instance("IDDR",
            p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
            i_C  = ClockSignal("rfic"),
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D  = pads.iqsel1,
            o_Q1 = rx_frame[0],
            o_Q2 = rx_frame[1],
        )

        # RX Data. FIXME: Add IDELAYE2.
        for n in range(12):
            self.specials += Instance("IDDR",
                p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
                i_C  = ClockSignal("rfic"),
                i_CE = 1,
                i_S  = 0,
                i_R  = 0,
                i_D  = pads.diq1[n],
                o_Q1 = rx_data[n + 0],
                o_Q2 = rx_data[n + 16],
            )

        # TX-RX Loopback/RX Pattern/Data Mux.
        self.comb += [
            # Redirect Data to RX Pattern when ready...
            If(rx_pattern.sink.ready,
                rx_pattern.sink.valid.eq(1),
                rx_pattern.sink.data.eq(rx_data)
            # ...Else...
            ).Else(
                rx_conv.sink.valid.eq(1),
                # Do a TX-RX Loopback with 12-bit masking when enabled (to match LMS7002M behaviour)...
                If(self.control.fields.tx_rx_loopback_enable,
                    rx_conv.sink.data.eq(tx_data & 0x0fff0fff)
                # ... Or do RX -> UpConverter --> CDC --> DMA.
                ).Else(
                    rx_conv.sink.data.eq(rx_data)
                )
            )
        ]