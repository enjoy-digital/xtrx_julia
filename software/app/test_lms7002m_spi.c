#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include "liblitepcie.h"

#define SPI_CS_HIGH (0 << 0)
#define SPI_CS_LOW  (1 << 0)
#define SPI_START   (1 << 0)
#define SPI_DONE    (1 << 0)
#define SPI_LENGTH  (1 << 8)

static void lms7002m_spi_write(int fd, int addr, int value) {
    int cmd;
    int dat;
    cmd = (1 << 15) | (addr & 0x7fff);
    dat = value & 0xffff;
    litepcie_writel(fd, CSR_LMS7002M_SPI_MOSI_ADDR, cmd << 16 | dat);
    litepcie_writel(fd, CSR_LMS7002M_SPI_CONTROL_ADDR, 32*SPI_LENGTH | SPI_START);
    while ((litepcie_readl(fd, CSR_LMS7002M_SPI_STATUS_ADDR) & SPI_DONE) == 0);
}

static int lms7002m_spi_read(int fd, int addr) {
    int cmd;
    int dat;
    cmd = (0 << 15) | (addr & 0x7fff);
    litepcie_writel(fd, CSR_LMS7002M_SPI_MOSI_ADDR, cmd << 16);
    litepcie_writel(fd, CSR_LMS7002M_SPI_CONTROL_ADDR, 32*SPI_LENGTH | SPI_START);
    while ((litepcie_readl(fd, CSR_LMS7002M_SPI_STATUS_ADDR) & SPI_DONE) == 0);
    dat = litepcie_readl(fd, CSR_LMS7002M_SPI_MISO_ADDR) & 0xffff;
    return dat;
}


void lms7002m_spi_test(const char *device_name)
{
    int fd;
    int i;

    fd = open(device_name, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    printf("Enabling LMS7002M...\n");
    litepcie_writel(fd, CSR_LMS7002M_CONTROL_ADDR,
        0 * (1 << CSR_LMS7002M_CONTROL_RESET_OFFSET)      |
        0 * (1 << CSR_LMS7002M_CONTROL_POWER_DOWN_OFFSET) |
        0 * (1 << CSR_LMS7002M_CONTROL_TX_ENABLE_OFFSET)  |
        0 * (1 << CSR_LMS7002M_CONTROL_RX_ENABLE_OFFSET)
    );

    printf("Dump LMS7002M Registers...\n");
    for (i=0; i<128; i++) {
        printf("reg 0x%04x: 0x%04x\n", i, lms7002m_spi_read(fd, i));
    }

    close(fd);
}

int main(int argc, char **argv)
{
    lms7002m_spi_test(argv[1]);
}
