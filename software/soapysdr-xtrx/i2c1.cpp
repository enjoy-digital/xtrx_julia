#include "XTRXDevice.hpp"
#include <unistd.h>


#define I2C1_DELAY(n)	  cdelay(n)


inline void cdelay(int i)
{
	while(i > 0) {
		usleep((int)1e6/I2C1_FREQ_HZ);
		i--;
	}
}

inline void SoapyXTRX::i2c1_oe_scl_sda(bool oe, bool scl, bool sda) const
{
	litepcie_writel(_fd, CSR_I2C1_W_ADDR,
		((oe & 1)  << CSR_I2C1_W_OE_OFFSET)	|
		((scl & 1) << CSR_I2C1_W_SCL_OFFSET) |
		((sda & 1) << CSR_I2C1_W_SDA_OFFSET)
	);
}

// START condition: 1-to-0 transition of SDA when SCL is 1
void SoapyXTRX::i2c1_start(void) const
{
	i2c1_oe_scl_sda(1, 1, 1);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 1, 0);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(1, 0, 0);
	I2C1_DELAY(1);
}

// STOP condition: 0-to-1 transition of SDA when SCL is 1
void SoapyXTRX::i2c1_stop(void) const
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
void SoapyXTRX::i2c1_transmit_bit(int value) const
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
int SoapyXTRX::i2c1_receive_bit(void) const
{
	int value;
	i2c1_oe_scl_sda(0, 0, 0);
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(0, 1, 0);
	I2C1_DELAY(1);
	// read in the middle of SCL high
	value = litepcie_readl(_fd, CSR_I2C1_R_ADDR) & 1;
	I2C1_DELAY(1);
	i2c1_oe_scl_sda(0, 0, 0);
	I2C1_DELAY(1);
	return value;
}

// Send data byte and return 1 if slave sends ACK
bool SoapyXTRX::i2c1_transmit_byte(unsigned char data) const
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
unsigned char SoapyXTRX::i2c1_receive_byte(bool ack) const
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
void SoapyXTRX::i2c1_reset(void) const
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
bool SoapyXTRX::i2c1_read(unsigned char slave_addr, unsigned char addr, unsigned char *data, unsigned int len, bool send_stop) const
{
	unsigned int i;

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
bool SoapyXTRX::i2c1_write(unsigned char slave_addr, unsigned char addr, const unsigned char *data, unsigned int len) const
{
	unsigned int i;

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
		if(!i2c1_transmit_byte(data[i])) {
			i2c1_stop();
			return false;
		}
	}

	i2c1_stop();

	return true;
}

bool SoapyXTRX::i2c1_poll(unsigned char slave_addr) const
{
    bool result;

    i2c1_start();
    result  = i2c1_transmit_byte(I2C1_ADDR_WR(slave_addr));
    result |= i2c1_transmit_byte(I2C1_ADDR_RD(slave_addr));
    i2c1_stop();

    return result;
}


void SoapyXTRX::i2c1_scan(void) const
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

