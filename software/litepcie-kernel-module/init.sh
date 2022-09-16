#!/bin/sh
# TODO: use udev instead

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

FOUND=$(lsmod | grep litepcie)
if [ "$FOUND" != "" ] ; then
    echo "Module already installed"
    exit 0
fi

INS=$(sudo insmod ${DIR}/litepcie.ko 2>&1)
if [ "$?" != "0" ] ; then
    ERR=$(echo $INS | sed -s "s/.*litepcie.ko: //")
    case $ERR in
    'Invalid module format')
        echo "Kernel may have changed, please rebuild the kernel modules"
        ;;
    'No such file or directory')
        echo "Module not compiled"
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

sudo insmod ${DIR}/liteuart.ko

for i in `seq 0 16` ; do
    sudo chmod 666 /dev/litepcie$i > /dev/null 2>&1 || true
done

