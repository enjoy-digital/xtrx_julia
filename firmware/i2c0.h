#ifndef __I2C0_H
#define __I2C0_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

/* I2C0 frequency defaults to a safe value in range 10-100 kHz to be compatible with SMBus */
#ifndef I2C0_FREQ_HZ
#define I2C0_FREQ_HZ  50000
#endif

#define I2C0_ADDR_WR(addr) ((addr) << 1)
#define I2C0_ADDR_RD(addr) (((addr) << 1) | 1u)

void i2c0_reset(void);
bool i2c0_write(unsigned char slave_addr, unsigned char addr, const unsigned char *data, unsigned int len);
bool i2c0_read(unsigned char slave_addr, unsigned char addr, unsigned char *data, unsigned int len, bool send_stop);
bool i2c0_poll(unsigned char slave_addr);
void i2c0_scan(void);

#ifdef __cplusplus
}
#endif

#endif /* __I2C0_H */
