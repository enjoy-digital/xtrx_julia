// This file is Copyright (c) 2020 Antmicro <www.antmicro.com>

#include <stdio.h>

#include "i2c1.h"

#include <generated/csr.h>

#ifdef CSR_I2C1_BASE

#define I2C1_PERIOD_CYCLES (CONFIG_CLOCK_FREQUENCY / I2C1_FREQ_HZ)
#define I2C1_DELAY(n)	  cdelay((n)*I2C1_PERIOD_CYCLES/4)

static inline void cdelay(int i)
{
	while(i > 0) {
		__asm__ volatile(CONFIG_CPU_NOP);
		i--;
	}
}

static inline void i2c1_oe_scl_sda(bool oe, bool scl, bool sda)
{
	i2c1_w_write(
		((oe & 1)  << CSR_I2C1_W_OE_OFFSET)	|
		((scl & 1) << CSR_I2C1_W_SCL_OFFSET) |
		((sda & 1) << CSR_I2C1_W_SDA_OFFSET)
	);
}

// START condition: 1-to-0 transition of SDA when SCL is 1
void i2c1_start(void)
{
	i2c1_oe_scl_sda(1, 1, 1);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 1, 0);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 0, 0);
	I2C1_DELAY(1);
}

// STOP condition: 0-to-1 transition of SDA when SCL is 1
void i2c1_stop(void)
{
	i2c1_oe_scl_sda(1, 0, 0);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 1, 0);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 1, 1);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(0, 1, 1);
}

// Call when in the middle of SCL low, advances one clk period
static void i2c1_transmit_bit(int value)
{
	i2c1_oe_scl_sda(1, 0, value);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 1, value);
	I2C1_DELAY(2);
	i2c1_oe_scl_sda(1, 0, value);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(0, 0, 0);  // release line
}

// Call when in the middle of SCL low, advances one clk period
static int i2c1_receive_bit(void)
{
	int value;
	i2c1_oe_scl_sda(0, 0, 0);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(0, 1, 0);
	I2C1_DELAY(1);
	// read in the middle of SCL high
	value = i2c1_r_read() & 1;
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(0, 0, 0);
	I2C1_DELAY(1);
	return value;
}

// Send data byte and return 1 if slave sends ACK
bool i2c1_transmit_byte(unsigned char data)
{
	int i;
	int ack;

	// SCL should have already been low for 1/4 cycle
	i2c1_oe_scl_sda(0, 0, 0);
	for (i = 0; i < 8; ++i) {
		// MSB first
		i2c1_transmit_bit((data & (1 << 7)) != 0);
		data <<= 1;
	}
	ack = i2c1_receive_bit();

	// 0 from slave means ack
	return ack == 0;
}

// Read data byte and send ACK if ack=1
static unsigned char i2c1_receive_byte(bool ack)
{
	int i;
	unsigned char data = 0;

	for (i = 0; i < 8; ++i) {
		data <<= 1;
		data |= i2c1_receive_bit();
	}
	i2c1_transmit_bit(!ack);

	return data;
}

// Reset line state
void i2c1_reset(void)
{
	int i;
	i2c1_oe_scl_sda(1, 1, 1);
	I2C1_DELAY(8);
	for (i = 0; i < 9; ++i) {
		i2c1_oe_scl_sda(1, 0, 1);
		I2C1_DELAY(2);
		i2c1_oe_scl_sda(1, 1, 1);
		I2C1_DELAY(2);
	}
	i2c1_oe_scl_sda(0, 0, 1);
	I2C1_DELAY(1);
	i2c1_stop();
	i2c1_oe_scl_sda(0, 1, 1);
	I2C1_DELAY(8);
}

/*
 * Read slave memory over I2C1 starting at given address
 *
 * First writes the memory starting address, then reads the data:
 *   START WR(slaveaddr) WR(addr) STOP START WR(slaveaddr) RD(data) RD(data) ... STOP
 * Some chips require that after transmiting the address, there will be no STOP in between:
 *   START WR(slaveaddr) WR(addr) START WR(slaveaddr) RD(data) RD(data) ... STOP
 */
bool i2c1_read(unsigned char slave_addr, unsigned char addr, unsigned char *data, unsigned int len, bool send_stop)
{
	int i;

	i2c1_start();

	if(!i2c1_transmit_byte(I2C1_ADDR_WR(slave_addr))) {
		i2c1_stop();
		return false;
	}
	if(!i2c1_transmit_byte(addr)) {
		i2c1_stop();
		return false;
	}

	if (send_stop) {
		i2c1_stop();
	}
	i2c1_start();

	if(!i2c1_transmit_byte(I2C1_ADDR_RD(slave_addr))) {
		i2c1_stop();
		return false;
	}
	for (i = 0; i < len; ++i) {
		data[i] = i2c1_receive_byte(i != len - 1);
	}

	i2c1_stop();

	return true;
}

/*
 * Write slave memory over I2C1 starting at given address
 *
 * First writes the memory starting address, then writes the data:
 *   START WR(slaveaddr) WR(addr) WR(data) WR(data) ... STOP
 */
bool i2c1_write(unsigned char slave_addr, unsigned char addr, const unsigned char *data, unsigned int len)
{
	int i;

	i2c1_start();

	if(!i2c1_transmit_byte(I2C1_ADDR_WR(slave_addr))) {
		i2c1_stop();
		return false;
	}
	if(!i2c1_transmit_byte(addr)) {
		i2c1_stop();
		return false;
	}
	for (i = 0; i < len; ++i) {
		printf("[i2c1] Transmitting 0x%x -> 0x%x\n", data[i], addr);
		if(!i2c1_transmit_byte(data[i])) {
			i2c1_stop();
			return false;
		}
	}

	i2c1_stop();

	return true;
}

/*
 * Poll I2C1 slave at given address, return true if it sends an ACK back
 */
bool i2c1_poll(unsigned char slave_addr)
{
    bool result;

    i2c1_start();
    result  = i2c1_transmit_byte(I2C1_ADDR_WR(slave_addr));
    result |= i2c1_transmit_byte(I2C1_ADDR_RD(slave_addr));
    i2c1_stop();

    return result;
}


/*
 * Scan I2C1
 */
void i2c1_scan(void)
{
	int slave_addr;

	printf("       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f");
	for (slave_addr = 0; slave_addr < 0x80; slave_addr++) {
		if (slave_addr % 0x10 == 0) {
			printf("\n0x%02x:", slave_addr & 0x70);
		}
		if (i2c1_poll(slave_addr)) {
			printf(" %02x", slave_addr);
		} else {
			printf(" --");
		}
	}
	printf("\n");
}

#endif /* CSR_I2C1_BASE */
