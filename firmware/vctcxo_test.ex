#!/usr/bin/expect

spawn litex_term /dev/ttyLXU0 --kernel=firmware.bin

# Find the `litex-xtrx> ` prompt; note that because of the character coloring,
# we drop the ending `>` since there are ASCII codes in-between.
send "\r"
set timeout 1
expect {
    timeout {
        puts "Couldn't find prompt!"
        exit 1
    }
    "litex-xtrx"
}

# Reboot, which will re-load the firmware bitstream.
# Note; if you pass `--safe` to `litex_term`, this can take a while!
set timeout 100
send "reboot\r"
expect "litex-xtrx"

# Start the vctcxo test, wait for it to finish, then close.
send "vctcxo_test\r"
expect "litex-xtrx"
close
