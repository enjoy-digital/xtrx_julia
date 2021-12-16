#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#include "liblitepcie.h"

void gps_test(const char *device_name)
{
    int fd;

    fd = open(device_name, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    printf("Enabling GPS...\n");
    litepcie_writel(fd, CSR_GPS_CONTROL_ADDR,
        1 * (1 << CSR_GPS_CONTROL_ENABLE_OFFSET)
    );

    printf("Dump GPS UART...\n");
    while (1) {
        if (litepcie_readl(fd, CSR_GPS_UART_RXEMPTY_ADDR) == 0)
            printf("%c", litepcie_readl(fd, CSR_GPS_UART_RXTX_ADDR));
        usleep(10);
    }

    close(fd);
}

int main(int argc, char **argv)
{
    gps_test(argv[1]);
}
