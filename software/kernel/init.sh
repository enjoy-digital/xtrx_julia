#!/bin/sh
# TODO: use udev instead

FOUND=$(lsmod | grep litepcie)
if [ "$FOUND" != "" ] ; then
    echo "Module already installed"
    exit 0
fi

INS=$(sudo insmod litepcie.ko 2>&1)
if [ "$?" != "0" ] ; then
    ERR=$(echo $INS | sed -s "s/.*litepcie.ko: //")
    case $ERR in
    'Invalid module format')
        set -e
        echo "Kernel may have changed, try to rebuild module"
        make -s clean
        make -s
        sudo insmod litepcie.ko
        set +e
        ;;
    'No such file or directory')
        set -e
        echo "Module not compiled"
        make -s
        sudo insmod litepcie.ko
        set +e
        ;;
    'Required key not available')
        echo "Can't insert kernel module, secure boot is probably enabled"
        echo "Please disable it from BIOS"
        exit 1
        ;;
    *)
        >&2 echo $INS
        exit 1
    esac
fi

sudo insmod liteuart.ko

for i in `seq 0 16` ; do
    sudo chmod 666 /dev/litepcie$i > /dev/null 2>&1
done

