#!/usr/bin/env python3

import sys
import argparse

from litex import RemoteClient

# TX Clk Delay Test --------------------------------------------------------------------------------

def tx_clk_delay_test(port, delay):
    bus = RemoteClient(port=port)
    bus.open()

    assert delay < 32

    # Reset Delay.
    bus.regs.lms7002m_tx_clk_rst.write(1)

    # Configure Delay.
    for i in range(delay):
        bus.regs.lms7002m_tx_clk_inc.write(1)

    bus.close()

# Run ----------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="TX Clk Delay utility")
    parser.add_argument("--port",  default="1234",  help="Host bind port")
    parser.add_argument("--delay", default="0",     help="TX Clk Delay")
    args = parser.parse_args()

    port = int(args.port, 0)

    tx_clk_delay_test(port=port, delay=int(args.delay, 0))

if __name__ == "__main__":
    main()
