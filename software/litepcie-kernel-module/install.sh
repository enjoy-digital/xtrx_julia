mkdir -p /lib/modules/$(uname -r)/kernel/litex
cp litepcie.ko /lib/modules/$(uname -r)/kernel/litex/litepcie.ko
cp liteuart.ko /lib/modules/$(uname -r)/kernel/litex/liteuart.ko
depmod -a
modprobe litepcie
modprobe liteuart
cp 99-litepci.rules /etc/udev/rules.d/99-litepci.rules

echo "!!! Remember to add litepcie and liteuart to /etc/modules-load.d/modules.conf !!!!"
