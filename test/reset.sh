#! /usr/bin/env bash

for i in `printf '%x\n' $(seq 4 12)`;
    do echo "1" > /sys/bus/pci/devices/0000\:0${i}\:00.0/reset;
done