#! /usr/bin/env bash
set -euo pipefail

# Autodetect XTRX devices with `lspci` filtering on our vendor ID:
XTRX_DEVICE_ADDRS=( $(lspci -d '10ee:7022:' -mm | awk '{ print $1 }') )

if [ "${#XTRX_DEVICE_ADDRS[@]}" -lt 1 ]; then
    echo "ERROR: No XTRX devices found!" >&2
    exit 1
fi

if [ "${EUID}" -ne "0" ]; then
    echo "ERROR: Must run this script as root!" >&2
    exit 1
fi

echo "Resetting ${#XTRX_DEVICE_ADDRS[@]} XTRX device(s)"
for ADDR in "${XTRX_DEVICE_ADDRS[@]}"; do
    echo "Resetting 0000:${ADDR}..."
    echo "1" > /sys/bus/pci/devices/"0000:${ADDR}"/reset
done
