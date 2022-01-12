#!/usr/bin/env python3

import sys
import time
import argparse

from litex import RemoteClient

# LMS7002M Pattern ---------------------------------------------------------------------------------

def lms7002m_pattern_enable(bus):
    bus.regs.lms7002m_tx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)
    bus.regs.lms7002m_rx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)


def lms7002m_pattern_disable(bus):
    bus.regs.lms7002m_tx_pattern_control.write(0)
    bus.regs.lms7002m_rx_pattern_control.write(0)

def lms7002m_pattern(port, enable):
    bus = RemoteClient(port=port)
    bus.open()

    if enable:
        bus.regs.lms7002m_tx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)
        bus.regs.lms7002m_rx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)
    else:
        bus.regs.lms7002m_tx_pattern_control.write(0)
        bus.regs.lms7002m_rx_pattern_control.write(0)

    bus.close()

# LMS7002M Delay Scan ------------------------------------------------------------------------------

PATTERN_ENABLE     =   (1 << 0)
PATTERN_COUNT_MODE = 0*(1 << 1)
PATTERN_PRBS_MODE  = 1*(1 << 1)

def lms7002m_delay_tx_scan(port):
    bus = RemoteClient(port=port)
    bus.open()

    print("TX Delay Scan...")

    # Reset Delay.
    bus.regs.lms7002m_tx_delay_rst.write(1)

    # Enable Pattern.
    bus.regs.lms7002m_tx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)
    bus.regs.lms7002m_rx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)

    # Scan all Delay values..
    for i in range(32):
        bus.regs.lms7002m_tx_delay_inc.write(1)
        start_errors = bus.regs.lms7002m_rx_pattern_errors.read()
        time.sleep(0.1)
        end_errors   = bus.regs.lms7002m_rx_pattern_errors.read()
        errors = (end_errors - start_errors)
        print(f"Delay: {i:d}, Errors: {errors:d}")

    # Disable Pattern.
    bus.regs.lms7002m_tx_delay_rst.write(1)
    bus.regs.lms7002m_tx_pattern_control.write(0)
    bus.regs.lms7002m_rx_pattern_control.write(0)

    bus.close()


def lms7002m_delay_rx_scan(port):
    bus = RemoteClient(port=port)
    bus.open()

    print("RX Delay Scan...")

    # Reset Delay.
    bus.regs.lms7002m_rx_delay_rst.write(1)

    # Enable Pattern.
    bus.regs.lms7002m_tx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)
    bus.regs.lms7002m_rx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)

    # Scan all Delay values..
    for i in range(32):
        bus.regs.lms7002m_rx_delay_inc.write(1)
        time.sleep(0.1)
        start_errors = bus.regs.lms7002m_rx_pattern_errors.read()
        time.sleep(0.1)
        end_errors = bus.regs.lms7002m_rx_pattern_errors.read()
        errors = (end_errors - start_errors)
        print(f"Delay: {i:d}, Errors: {errors:d}")

    # Disable Pattern.
    bus.regs.lms7002m_rx_delay_rst.write(1)
    bus.regs.lms7002m_tx_pattern_control.write(0)
    bus.regs.lms7002m_rx_pattern_control.write(0)

    bus.close()

def lms7002m_delay_tx_rx_scan(port):
    bus = RemoteClient(port=port)
    bus.open()

    print("TX-RX Delay Scan...")

    # Reset Delay.
    bus.regs.lms7002m_tx_delay_rst.write(1)
    bus.regs.lms7002m_rx_delay_rst.write(1)

    # Enable Pattern.
    bus.regs.lms7002m_tx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)
    bus.regs.lms7002m_rx_pattern_control.write(PATTERN_ENABLE | PATTERN_COUNT_MODE)

    # Scan all Delay values..
    print("TX / RX ", end="")
    for rx in range(32):
        print(f"{rx:02d} ", end="")
    print("")
    for tx in range(32):
        bus.regs.lms7002m_tx_delay_inc.write(1)
        print(f"{tx:02d} |    ", end="")
        for rx in range(32):
            bus.regs.lms7002m_rx_delay_inc.write(1)
            #time.sleep(0.01)
            start_errors = bus.regs.lms7002m_rx_pattern_errors.read()
            #time.sleep(0.01)
            end_errors   = bus.regs.lms7002m_rx_pattern_errors.read()
            errors = (end_errors - start_errors)
            if errors:
                print(" - ", end="")
            else:
                print(f"{rx:02d} ", end="")
            sys.stdout.flush()
        print("")

    # Disable Pattern.
    bus.regs.lms7002m_rx_delay_rst.write(1)
    bus.regs.lms7002m_tx_pattern_control.write(0)
    bus.regs.lms7002m_rx_pattern_control.write(0)

    bus.close()

# LMS7002M Delay Set -------------------------------------------------------------------------------

def lms7002m_delay_tx_set(port, delay):
    bus = RemoteClient(port=port)
    bus.open()

    assert delay < 32

    # Reset Delay.
    bus.regs.lms7002m_tx_delay_rst.write(1)

    # Configure Delay.
    for i in range(delay):
        bus.regs.lms7002m_tx_delay_inc.write(1)

    bus.close()

def lms7002m_delay_rx_set(port, delay):
    bus = RemoteClient(port=port)
    bus.open()

    assert delay < 32

    # Reset Delay.
    bus.regs.lms7002m_rx_delay_rst.write(1)

    # Configure Delay.
    for i in range(delay):
        bus.regs.lms7002m_rx_delay_inc.write(1)

    bus.close()

# Run ----------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="TX Clk Delay utility")
    parser.add_argument("--port",       default="1234",  help="Host bind port.")
    parser.add_argument("--tx-scan",    action="store_true", help="Run TX delay scan.")
    parser.add_argument("--rx-scan",    action="store_true", help="Run RX delay scan.")
    parser.add_argument("--tx-rx-scan", action="store_true", help="Run TX-RX delay scan.")
    parser.add_argument("--tx-delay",   default=None,        help="Set TX delay.")
    parser.add_argument("--rx-delay",   default=None,        help="Set RX delay.")
    parser.add_argument("--pattern",    default=None,        help="Enable/Disable Pattern.")

    args = parser.parse_args()

    port = int(args.port, 0)

    if args.tx_scan:
        lms7002m_delay_tx_scan(port=port)

    if args.rx_scan:
        lms7002m_delay_rx_scan(port=port)

    if args.tx_rx_scan:
        lms7002m_delay_tx_rx_scan(port=port)

    if args.tx_delay is not None:
        lms7002m_delay_tx_set(port=port, delay=int(args.tx_delay, 0))

    if args.rx_delay is not None:
        lms7002m_delay_rx_set(port=port, delay=int(args.rx_delay, 0))

    if args.pattern is not None:
        lms7002m_pattern(port=port, enable=int(args.pattern, 0))

if __name__ == "__main__":
    main()
