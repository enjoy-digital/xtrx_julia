#ifndef __I2C1_H
#define __I2C1_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

/* I2C1 frequency defaults to a safe value in range 10-100 kHz to be compatible with SMBus */
#ifndef I2C1_FREQ_HZ
#define I2C1_FREQ_HZ  50000
#endif

#define I2C1_ADDR_WR(addr) ((addr) << 1)
#define I2C1_ADDR_RD(addr) (((addr) << 1) | 1u)

void i2c1_reset(void);
bool i2c1_write(unsigned char slave_addr, unsigned char addr, const unsigned char *data, unsigned int len);
bool i2c1_read(unsigned char slave_addr, unsigned char addr, unsigned char *data, unsigned int len, bool send_stop);
bool i2c1_poll(unsigned char slave_addr);
void i2c1_scan(void);

#ifdef __cplusplus
}
#endif

#endif /* __I2C1_H */
