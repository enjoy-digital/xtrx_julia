#mkdir -p /lib/modules/$(uname -r)/litex
cp litepcie.ko /lib/modules/$(uname -r)/litepcie.ko
cp liteuart.ko /lib/modules/$(uname -r)/liteuart.ko
depmod -a
modprobe litepcie
modprobe liteuart

echo "Remember to add litepcie and liteuart to /etc/modules-load.d/modules.conf"