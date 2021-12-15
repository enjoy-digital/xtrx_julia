#!/usr/bin/env python3

#
# This file is part of XTRX-Julia.
#
# Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import argparse
import sys

from migen import *
from migen.fhdl.specials import Tristate

import fairwaves_xtrx_platform as fairwaves_xtrx

from litex.soc.interconnect.csr import *
from litex.soc.interconnect import stream
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litex.soc.cores.clock import *
from litex.soc.cores.led import LedChaser
from litex.soc.cores.icap import ICAP
from litex.soc.cores.gpio import GPIOOut
from litex.soc.cores.spi_flash import S7SPIFlash
from litex.soc.cores.bitbang import I2CMaster

from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.software import generate_litepcie_software

from litescope import LiteScopeAnalyzer

from gateware.vctxo import VCTXO
from gateware.rf_switches import RFSwitches
from gateware.lms7002m import LMS7002M

# CRG ----------------------------------------------------------------------------------------------

class CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.clock_domains.cd_sys  = ClockDomain()

        # # #

        assert sys_clk_freq == int(125e6)
        self.comb += [
            self.cd_sys.clk.eq(ClockSignal("pcie")),
            self.cd_sys.rst.eq(ResetSignal("pcie")),
        ]

# BaseSoC -----------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=int(125e6), with_cpu=True, cpu_firmware=None, with_jtagbone=False, with_analyzer=False):
        platform = fairwaves_xtrx.Platform()

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, sys_clk_freq,
            ident                    = "LiteX SoC on Fairwaves XTRX",
            ident_version            = True,
            cpu_type                 = "vexriscv" if with_cpu else None,
            cpu_variant              = "minimal",
            integrated_rom_size      = 0x8000 if with_cpu else 0,
            integrated_sram_ram_size = 0x1000 if with_cpu else 0,
            integrated_main_ram_size = 0x4000 if with_cpu else 0,
            integrated_main_ram_init = [] if cpu_firmware is None else get_mem_data(cpu_firmware, "little"),
            uart_name                = "crossover",
        )
        # Automatically jump to pre-initialized firmware.
        self.add_constant("ROM_BOOT_ADDRESS", self.mem_map["main_ram"])
        # Avoid stalling CPU at startup.
        #self.uart.add_auto_tx_flush(sys_clk_freq=sys_clk_freq, timeout=1, interval=128) # FIXME: Present Flashing when executed automatically.

        # Clocking ---------------------------------------------------------------------------------
        self.submodules.crg = CRG(platform, sys_clk_freq)

        # JTAGBone ---------------------------------------------------------------------------------
        if with_jtagbone:
            self.add_jtagbone()

        # Leds -------------------------------------------------------------------------------------
        self.submodules.leds = LedChaser(
            pads         = platform.request_all("user_led"),
            sys_clk_freq = sys_clk_freq
        )

        # ICAP -------------------------------------------------------------------------------------
        self.submodules.icap = ICAP()
        self.icap.add_reload()
        self.icap.add_timing_constraints(platform, sys_clk_freq, self.crg.cd_sys.clk)

        # SPIFlash ---------------------------------------------------------------------------------
        self.submodules.flash_cs_n = GPIOOut(platform.request("flash_cs_n"))
        self.submodules.flash      = S7SPIFlash(platform.request("flash"), sys_clk_freq, 25e6)

        # PCIe -------------------------------------------------------------------------------------
        self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request(f"pcie_x2"),
            data_width = 64,
            bar0_size  = 0x20000,
            cd         = "pcie"
        )
        self.add_pcie(phy=self.pcie_phy, ndmas=1,
            with_dma_buffering = True, dma_buffering_depth=1024,
            with_dma_loopback  = True,
            with_msi           = True
        )

        # I2C Peripherals --------------------------------------------------------------------------
        self.comb += platform.request("pwrdwn_n").eq(1) # Enable.

        # I2C Bus0:
        # - Temperature Sensor (TMP108  @ 0x4a).
        # - PMIC-LMS           (LP8758  @ 0x60).
        # - VCTXO DAC          (LTC26x6 @ 0x62).
        self.submodules.i2c0 = I2CMaster(platform.request("i2c", 0))

        # I2C Bus1:
        # PMIC-FPGA (LP8758 @ 0x60).
        self.submodules.i2c1 = I2CMaster(platform.request("i2c", 1))

        # VCTXO ------------------------------------------------------------------------------------
        self.submodules.vctxo = VCTXO(platform.request("vctxo"))

        # RF Switches ------------------------------------------------------------------------------
        self.submodules.rf_switches = RFSwitches(platform.request("rf_switches"))

        # LMS7002M ---------------------------------------------------------------------------------
        self.submodules.lms7002m = LMS7002M(platform.request("lms7002m"), sys_clk_freq)
        self.comb += self.pcie_dma0.source.connect(self.lms7002m.sink)
        self.comb += self.lms7002m.source.connect(self.pcie_dma0.sink)

        # Analyzer ---------------------------------------------------------------------------------
        if with_analyzer:
            analyzer_signals = [
                platform.lookup_request("vctxo").enable,
                platform.lookup_request("vctxo").sel,
                platform.lookup_request("vctxo").clk,
                i2c_busy,
                i2c_ok,
                i2c_sda0t,
                i2c_scl0t,
                i2c_sda0i,
                i2c_scl0i,
                i2c_sda1t,
                i2c_scl1t,
                i2c_sda1i,
                i2c_scl1i,
            ]
            self.submodules.analyzer = LiteScopeAnalyzer(analyzer_signals,
                depth        = 512,
                clock_domain = "sys",
                csr_csv      = "analyzer.csv"
            )

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on Fairwaves XTRX")
    parser.add_argument("--build", action="store_true", help="Build bitstream")
    parser.add_argument("--load",  action="store_true", help="Load bitstream")
    parser.add_argument("--flash", action="store_true", help="Flash bitstream")
    args = parser.parse_args()

    # Build SoC.
    for run in range(2):
        prepare = (run == 0)
        build   = ((run == 1) & args.build)
        soc = BaseSoC(cpu_firmware=None if prepare else "firmware/firmware.bin")
        builder = Builder(soc, csr_csv="csr.csv")
        builder.build(run=build)
        if prepare:
            os.system("cd firmware && make clean all")

    # Generate LitePCIe Driver.
    generate_litepcie_software(soc, "software")

    # Load Bistream.
    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

    # Flash Bitstream.
    if args.flash:
        prog = soc.platform.create_programmer()
        prog.flash(0, os.path.join(builder.gateware_dir, soc.build_name + ".bin"))

if __name__ == "__main__":
    main()
