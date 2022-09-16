#include "liblitepcie.h"

#include <fcntl.h>
#include <unistd.h>

#define LITEPCIE_SPI_CS_HIGH (0 << 0)
#define LITEPCIE_SPI_CS_LOW  (1 << 0)
#define LITEPCIE_SPI_START   (1 << 0)
#define LITEPCIE_SPI_DONE    (1 << 0)
#define LITEPCIE_SPI_LENGTH  (1 << 8)

static inline uint32_t litepcie_interface_transact(void *handle, const uint32_t data_in, const bool readback)
{
    int *fd = (int *)handle;

    //load tx data
    litepcie_writel(*fd, CSR_LMS7002M_SPI_MOSI_ADDR, data_in);

    //start transaction
    litepcie_writel(*fd, CSR_LMS7002M_SPI_CONTROL_ADDR, 32*LITEPCIE_SPI_LENGTH | LITEPCIE_SPI_START);

    //wait for completion
    while ((litepcie_readl(*fd, CSR_LMS7002M_SPI_STATUS_ADDR) & LITEPCIE_SPI_DONE) == 0);

    //load rx data
    if (readback) {
        return litepcie_readl(*fd, CSR_LMS7002M_SPI_MISO_ADDR) & 0xffff;
    } else {
        return 0;
    }
}
