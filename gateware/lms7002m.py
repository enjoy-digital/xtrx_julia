#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import MultiReg
from migen.genlib.misc import WaitTimer

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
                ("``0b0``", "Disable Generator."),
                ("``0b1``", "Enable Generator.")
            ], reset=0)
        ])

        # # #

        enable = Signal()
        self.specials += MultiReg(self.control.fields.enable, enable, "rfic")

        # Control-Path.
        # -------------
        self.comb      += self.source.valid.eq(enable)
        self.sync.rfic += self.source.last.eq(~self.source.last)

        # Generator.
        # ----------

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

        # Data-Path.
        # ----------
        self.sync.rfic += [
            self.source.data[ 0:16].eq(count),
            self.source.data[16:32].eq(count),
        ]


class RXPatternChecker(Module, AutoCSR):
    def __init__(self):
        self.sink    = stream.Endpoint([("data", 32)])
        self.control = CSRStorage(fields=[
            CSRField("enable", size=1, offset=0, values=[
                ("``0b0``", "Disable Checker."),
                ("``0b1``", "Enable Checker.")
            ], reset=0),
        ])
        self.errors = CSRStatus(32)

        # # #

        enable = Signal()
        self.specials += MultiReg(self.control.fields.enable, enable, "rfic")

        # Control-Path.
        # -------------
        self.comb += self.sink.ready.eq(enable)

        # Checker/Data-Path.
        # -------------------
        count_error = Signal()
        count0      = Signal(12)
        count1      = Signal(12)
        self.sync.rfic += count0.eq(self.sink.data[0:])
        self.sync.rfic += count1.eq(self.sink.data[16:])
        self.comb += If(self.sink.data[ 0:12] != (count0 + 1), count_error.eq(1))
        self.comb += If(self.sink.data[16:28] != (count1 + 1), count_error.eq(1))

        # Errors.
        # -------
        errors = self.errors.status # FIXME: CDC.
        self.sync.rfic += [
            If(~enable,
                errors.eq(0)
            ).Else(
                If(count_error,
                    errors.eq(errors + 1)
                )
            )
        ]

# LMS7002M -----------------------------------------------------------------------------------------

class LMS7002M(Module, AutoCSR):
    def __init__(self, platform, pads, sys_clk_freq, tx_delay_init=0, rx_delay_init=0):
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
        self.status   = CSRStatus(fields=[
            CSRField("rx_clk_active", size=1, offset=0, values=[
                ("``0b0``", "RX Clk from LMS7002M is not detected."),
                ("``0b1``", "RX Clk from LMS7002M is active.")
            ], reset=0),
            CSRField("rx_frame_active", size=1, offset=1, values=[
                ("``0b0``", "RX Frame from LMS7002M is not detected."),
                ("``0b1``", "RX Frame from LMS7002M is active.")
            ], reset=0), # TODO.
            CSRField("rx_frame_aligned", size=1, offset=2, values=[
                ("``0b0``", "RX Frame from LMS7002M is not aligned."),
                ("``0b1``", "RX Frame from LMS7002M is aligned.")
            ], reset=0),
        ])
        self.delay = CSRStorage(fields=[
            CSRField("tx_delay", size=5, offset=0, description="TX Delay Value (0-31)", reset=tx_delay_init),
            CSRField("rx_delay", size=5, offset=8, description="RX Delay Value (0-31)", reset=rx_delay_init),
            ]
        )

        # # #

        # TX/RX Data/Frame.
        # -----------------
        self.tx_frame   = tx_frame   = Signal(2)
        self.tx_data    = tx_data    = Signal(32)
        self.rx_frame   = rx_frame   = Signal(2)
        self.rx_aligned = rx_aligned = Signal()
        self.rx_data    = rx_data    = Signal(32)

        # Drive Control Pins.
        # -------------------
        self.comb += [
            pads.rst_n.eq(   ~self.control.fields.reset),
            pads.pwrdwn_n.eq(~self.control.fields.power_down),
            pads.txen.eq(     self.control.fields.tx_enable),
            pads.rxen.eq(     self.control.fields.rx_enable),
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
        # ---------

        # Use MCLK1 as RX-Clk and constraint it to 245.76MHz (61.44MSPS MIMO)
        self.clock_domains.cd_rfic = ClockDomain("rfic")
        self.comb += self.cd_rfic.clk.eq(pads.mclk1)
        platform.add_period_constraint(pads.mclk1, 1e9/245.76e6)

        # Pass RX-Clk active information to sys_clk.
        clk_active_cdc = stream.ClockDomainCrossing([("active", 1)], cd_from="rfic", cd_to="sys")
        self.submodules += clk_active_cdc
        self.comb += clk_active_cdc.sink.valid.eq(1)

        # Create timer to update RX-Clk active.
        clk_active_timer = WaitTimer(int(1e6))
        self.submodules += clk_active_timer
        self.comb += clk_active_timer.wait.eq(~clk_active_timer.done)

        # Verify if RX-Clk is active.
        clk_active_count = Signal(8)
        self.sync += [
            # Always ack clk_active_cdc.
            clk_active_cdc.source.ready.eq(1),
            # Increment count.
            If(clk_active_count != (2**8 - 1),
                If(clk_active_cdc.source.valid,
                    clk_active_count.eq(clk_active_count + 1)
                )
            ),
            # Update RX-Clk active.
            If(clk_active_timer.done,
                clk_active_count.eq(0),
                self.status.fields.rx_clk_active.eq(clk_active_count != 0),
            )
        ]

        # TX Datapath.
        # ------------
        self.tx_delay_rst = CSR()
        self.tx_delay_inc = CSR()

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
                tx_frame[0].eq(tx_pattern.source.last),
                tx_frame[1].eq(tx_pattern.source.last),
                tx_data.eq(tx_pattern.source.data),
            # ... Else from DMA -> CDC -> DownConverter.
            ).Else(
                tx_conv.source.ready.eq(1),
                tx_frame[0].eq(tx_conv.source.last),
                tx_frame[1].eq(tx_conv.source.last),
                tx_data.eq(tx_conv.source.data),
            )
        ]

        # TX Clk.
        rfic_tx_clk = Signal()
        self.specials += Instance("IDELAYE2",
            p_IDELAY_TYPE      = "VAR_LOAD",
            p_REFCLK_FREQUENCY = 200e6/1e6,
            p_DELAY_SRC        = "DATAIN",
            i_C          = ClockSignal("sys"),
            i_LD         = ResetSignal("sys") | self.delay.re,
            i_CNTVALUEIN = self.delay.fields.tx_delay,
            i_CE         = 0,
            i_LDPIPEEN   = 0,
            i_INC        = 1,
            i_DATAIN     = ClockSignal("rfic"),
            o_DATAOUT    = rfic_tx_clk,
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

        # RX Frame.
        iqsel1_delayed = Signal()
        self.specials += Instance("IDELAYE2",
            p_IDELAY_TYPE      = "VAR_LOAD",
            p_REFCLK_FREQUENCY = 200e6/1e6,
            p_DELAY_SRC        = "IDATAIN",
            i_C          = ClockSignal("sys"),
            i_LD         = ResetSignal("sys") | self.delay.re,
            i_CNTVALUEIN = self.delay.fields.rx_delay,
            i_CE         = 0,
            i_LDPIPEEN   = 0,
            i_INC        = 1,
            i_IDATAIN    = pads.iqsel1,
            o_DATAOUT    = iqsel1_delayed,
        )
        self.specials += Instance("IDDR",
            p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
            i_C  = ClockSignal("rfic"),
            i_CE = 1,
            i_S  = 0,
            i_R  = 0,
            i_D  = iqsel1_delayed,
            o_Q1 = rx_frame[0],
            o_Q2 = rx_frame[1],
        )
        self.comb += rx_aligned.eq((rx_frame == 0b00) | (rx_frame == 0b11))
        self.specials += MultiReg(rx_aligned, self.status.fields.rx_frame_aligned)

        # RX Data.
        rx_data0 = Signal(16)
        rx_data1 = Signal(16)
        for n in range(12):
            diq1_n_delayed = Signal()
            self.specials += Instance("IDELAYE2",
                p_IDELAY_TYPE      = "VAR_LOAD",
                p_REFCLK_FREQUENCY = 200e6/1e6,
                p_DELAY_SRC        = "IDATAIN",
                i_C          = ClockSignal("sys"),
                i_LD         = ResetSignal("sys") | self.delay.re,
                i_CNTVALUEIN = self.delay.fields.rx_delay,
                i_CE         = 0,
                i_LDPIPEEN   = 0,
                i_INC        = 1,
                i_IDATAIN  = pads.diq1[n],
                o_DATAOUT  = diq1_n_delayed,
            )
            self.specials += Instance("IDDR",
                p_DDR_CLK_EDGE = "SAME_EDGE_PIPELINED",
                i_C  = ClockSignal("rfic"),
                i_CE = 1,
                i_S  = 0,
                i_R  = 0,
                i_D  = diq1_n_delayed,
                o_Q1 = rx_data0[n],
                o_Q2 = rx_data1[n],
            )
        rx_data1_d = Signal(16)
        self.sync.rfic += [
            rx_data1_d.eq(rx_data1),
            If(rx_aligned,
                rx_data[:16].eq(rx_data0),
                rx_data[16:].eq(rx_data1),
            ).Else(
                rx_data[:16].eq(rx_data1_d),
                rx_data[16:].eq(rx_data0),
            )
        ]

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
