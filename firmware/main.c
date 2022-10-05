// This file is Copyright (c) 2020-2021 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <irq.h>
#include <libbase/uart.h>
#include <libbase/console.h>
#include <generated/csr.h>

#include "i2c0.h"
#include "i2c1.h"

/*-----------------------------------------------------------------------*/
/* Constants                                                             */
/*-----------------------------------------------------------------------*/

#define XTRX_EXT_CLK    (1 << 0)
#define XTRX_VCTCXO_CLK (0 << 0)

#define TMP108_I2C_ADDR  0x4a
#define LP8758_I2C_ADDR  0x60
#define MCP4725_I2C_ADDR 0x62 /* Rev4 */
#define DAC60501_I2C_ADDR 0x4b /* Rev5 */

#define LMS7002M_RESET      (1 << 0)
#define LMS7002M_POWER_DOWN (1 << 1)
#define LMS7002M_TX_ENABLE  (1 << 2)
#define LMS7002M_RX_ENABLE  (1 << 3)


/*-----------------------------------------------------------------------*/
/* Global Variables                                                      */
/*-----------------------------------------------------------------------*/

static int board_revision;
static unsigned char dac_addr;

/*-----------------------------------------------------------------------*/
/* Helpers                                                               */
/*-----------------------------------------------------------------------*/

void busy_wait(unsigned int ms)
{
	timer0_en_write(0);
	timer0_reload_write(0);
	timer0_load_write(CONFIG_CLOCK_FREQUENCY/1000*ms);
	timer0_en_write(1);
	timer0_update_value_write(1);
	while(timer0_value_read()) timer0_update_value_write(1);
}

/*-----------------------------------------------------------------------*/
/* UART                                                                  */
/*-----------------------------------------------------------------------*/

static char *readstr(void)
{
	char c[2];
	static char s[64];
	static int ptr = 0;

	if(readchar_nonblock()) {
		c[0] = getchar();
		c[1] = 0;
		switch(c[0]) {
			case 0x7f:
			case 0x08:
				if(ptr > 0) {
					ptr--;
					fputs("\x08 \x08", stdout);
				}
				break;
			case 0x07:
				break;
			case '\r':
			case '\n':
				s[ptr] = 0x00;
				fputs("\n", stdout);
				ptr = 0;
				return s;
			default:
				if(ptr >= (sizeof(s) - 1))
					break;
				fputs(c, stdout);
				s[ptr] = c[0];
				ptr++;
				break;
		}
	}

	return NULL;
}

static char *get_token(char **str)
{
	char *c, *d;

	c = (char *)strchr(*str, ' ');
	if(c == NULL) {
		d = *str;
		*str = *str+strlen(*str);
		return d;
	}
	*c = 0;
	d = *str;
	*str = c+1;
	return d;
}

static void prompt(void)
{
	printf("\e[92;1mlitex-xtrx\e[0m> ");
}

/*-----------------------------------------------------------------------*/
/* Help                                                                  */
/*-----------------------------------------------------------------------*/

static void help(void)
{
	puts("\nLiteX-XTRX firmware built "__DATE__" "__TIME__"\n");
	puts("Available commands:");
	puts("help               - Show this command");
	puts("reboot             - Reboot CPU");
	puts("i2c_test           - Test I2C Buses");
	puts("temp_test          - Test Temperature Sensor");
	puts("vctcxo_test        - Test VCTCXO");
	puts("rfic_test          - Test RFIC");
	puts("digi_1v8           - Set Digital Interface to 1.8V");
	puts("xtrx_init          - Initialize XTRX");
	puts("pmic_dump          - Dump PMIC Registers");
	puts("dac_dump           - Dump DAC Registers");
	puts("xsync_spi_test     - Test XSYNC SPI Bus");
}

/*-----------------------------------------------------------------------*/
/* Commands                                                              */
/*-----------------------------------------------------------------------*/

static void reboot_cmd(void)
{
	ctrl_reset_write(1);
}

/*-----------------------------------------------------------------------*/
/* Board                                                                 */
/*-----------------------------------------------------------------------*/

static int board_get_revision(void)
{
	/* Get board revision from SPI DACs:
	   - XTRX Rev4 is equipped with a MCP4725.
	   - XTRX Rev5 is equipped with a DAC60501.
	   The DAC60501 has the particularity of only accepting write commands,
	   so we detect MCP4725 presence (and thus Rev4 revision) by doing a
	   I2C read to the MCP4725 I2C address.
	*/

	/* Check MCP4725 presence */
	int has_mcp4725;
	i2c1_start();
	has_mcp4725 = i2c1_transmit_byte(I2C1_ADDR_RD(MCP4725_I2C_ADDR));
	i2c1_stop();

	if (has_mcp4725) {
		dac_addr = MCP4725_I2C_ADDR;
		return 4;
	} else {
		dac_addr = DAC60501_I2C_ADDR;
		return 5;
	}
}

static void pmic_dump(void){
	unsigned char adr;
	unsigned char dat;
	printf("PMIC-LMS Dump...\n");
	for (adr=0; adr<32; adr++) {
		i2c0_read(LP8758_I2C_ADDR, adr, &dat, 1, true);
		printf("0x%02x: 0x%02x\n", adr, dat);
	}
	printf("PMIC-FPGA Dump...\n");
	for (adr=0; adr<32; adr++) {
		i2c1_read(LP8758_I2C_ADDR, adr, &dat, 1, true);
		printf("0x%02x: 0x%02x\n", adr, dat);
	}
}

static void dac_dump(void){
	unsigned char adr;
	unsigned char dat[2];
	if (dac_addr == DAC60501_I2C_ADDR) {
		// TODO: Fix endianness
		printf("DAC @0x%02x Dump...\n", dac_addr);
		for (adr=0; adr<9; adr++) {
			i2c1_read(dac_addr, adr, dat, 2, true);
			printf("0x%02x: 0x%04x\n", adr, *dat);
		}
	}
}

/*-----------------------------------------------------------------------*/
/* I2C                                                                   */
/*-----------------------------------------------------------------------*/

static void i2c_test(void)
{
	printf("I2C0 Scan...\n");
	i2c0_scan();

	printf("\n");

	printf("I2C1 Scan...\n");
	i2c1_scan();
}

/*-----------------------------------------------------------------------*/
/* Temperature                                                           */
/*-----------------------------------------------------------------------*/

static void temp_test(void)
{
	unsigned int temp;
	unsigned char dat[2];
	i2c1_read(TMP108_I2C_ADDR, 0x00, dat, 2, true);
	temp = (dat[0] << 4) | (dat[1] >> 4);
	temp = (62500*temp)/1000000; /* 0.0625°C/count */
	printf("Temperature: %d°C\n", temp);
}

/*-----------------------------------------------------------------------*/
/* VCTCXO                                                                */
/*-----------------------------------------------------------------------*/

static void dac_init(void) {
	unsigned char cmd;
	unsigned char dat[2];

	/* Rev4 is equipped with a MCP4725 */
	if (board_revision == 4) {
		printf("DAC is MCP4725\n");
	/* Rev5 is equipped with a DAC60501 */
	} else {
		printf("DAC is DAC60501.\n");
		// The stock XTRX does this read, but we don't need it.
		cmd = 0x04;
		i2c1_read(DAC60501_I2C_ADDR, cmd, dat, 2, true);

		// Gain register
		cmd = 0x04;
		dat[0] = 0x01; // Buffer Amplifier Gain -> 2
		dat[1] = 0x01; // Reference divider -> 2
		i2c1_write(DAC60501_I2C_ADDR, cmd, dat, 2);
	}
}

static void vctcxo_dac_set(int value) {
	unsigned char cmd;
	unsigned char dat[2];
	bool ret;

	value = value & 0xfff; /* 12-bit full range clamp */

	/* Rev4 is equipped with a MCP4725 */
	if (board_revision == 4) {
		cmd    = (0b0000 << 4) | (value >> 8);
		dat[0] = (value & 0xff);
		i2c1_write(MCP4725_I2C_ADDR, cmd, dat, 1);
	/* Rev5 is equipped with a DAC60501 */
	} else {
		// Bottom four bits are ignored on DAC60501
		value <<= 4;
		dat[0] = (value & 0xff00) >> 8;
		dat[1] = value & 0xff;
		cmd = 0x08;
		ret = i2c1_write(DAC60501_I2C_ADDR, cmd, dat, 2);
		if (!ret) {
			printf("DAC write failed\n");
		}
	}
}

static int vctcxo_cycles[16];

static void vctcxo_test(int n)
{
	int i;
	int diff;
	volatile int before, after;
	vctcxo_control_write(XTRX_VCTCXO_CLK);

	for (i=0; i<n; i++) {
		vctcxo_dac_set(i*0x111);

		// Pulse cycle count into status register, then read it
		vctcxo_cycles_latch_write(1);
		before = vctcxo_cycles_read();

		// Wait for 1 second
		busy_wait(1000);

		// Pulse cycle count into status register, then read it
		vctcxo_cycles_latch_write(1);
		after = vctcxo_cycles_read();

		// Calculate how many cycles we observed in the last second
		vctcxo_cycles[i] = after - before;
	}

	for (i=0; i<n; i++) {
		diff = vctcxo_cycles[i];
		// see the effect it's having, as the DAC tunes it very precisely.
		// Of course, since we're counting cycles over 1 second, our `diff`
		// value is literally just the frequency in Hz, so this double-
		// printing in cycles and MHz is arguably not that interesting...
		printf("VCTCXO freq: %3d.%5dMHz (cycles: %d / dac: 0x%04x)\n",
			(diff)/1000000,
			diff%1000000,
			diff,
			i*0x111
		);
	}


}

/*-----------------------------------------------------------------------*/
/* Digital Interface                                                     */
/*-----------------------------------------------------------------------*/

static void digi_1v8(void)
{
	unsigned char adr;
	unsigned char dat;

	printf("PMIC-FPGA: Set Buck1 to 1880mV.\n");
	adr = 0x0c;
	dat = 0xb5;
	i2c1_write(LP8758_I2C_ADDR, adr, &dat, 1);
}

/*-----------------------------------------------------------------------*/
/* Init                                                                  */
/*-----------------------------------------------------------------------*/

static int xtrx_init(void)
{
	unsigned char adr;
	unsigned char dat;

	printf("PMICs Initialization...\n");
	printf("-----------------------\n");

	printf("PMIC-LMS: Check ID ");
	adr = 0x01;
	i2c0_read(LP8758_I2C_ADDR, adr, &dat, 1, true);
	if (dat != 0xe0) {
		printf("KO, exiting.\n");
		return 0;
	} else {
		printf("OK.\n");
	}

	printf("PMIC-LMS: Enable Buck1.\n");
	adr = 0x04;
	dat = 0x88;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck1 to 3280mV.\n");
	adr = 0x0c;
	dat = 0xfb;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Disable Buck0.\n");
	adr = 0x02;
	dat = 0xc8;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Disable Buck2.\n");
	adr = 0x06;
	dat = 0xc8;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Disable Buck3.\n");
	adr = 0x08;
	dat = 0xc8;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck0 to 1880mV.\n");
	adr = 0x0a;
	dat = 0xb5;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck2 to 1480mV.\n");
	adr = 0x0e;
	dat = 0xa1;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck3 to 1340mV.\n");
	adr = 0x10;
	dat = 0x92;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	busy_wait(1);

	printf("PMIC-FPGA: Check ID ");
	adr = 0x1;
	i2c1_read(LP8758_I2C_ADDR, adr, &dat, 1, true);
	if (dat != 0xe0) {
		printf("KO, exiting.\n");
		return 0;
	} else {
		printf("OK.\n");
	}

	printf("PMIC-LMS: Enable Buck0.\n");
	adr = 0x02;
	dat = 0x88;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Enable Buck2.\n");
	adr = 0x06;
	dat = 0x88;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Enable Buck3.\n");
	adr = 0x08;
	dat = 0x88;
	i2c0_write(LP8758_I2C_ADDR, adr, &dat, 1);

	printf("PMIC-FPGA: Set Buck1 to 3280mV.\n");
	adr = 0x0c;
	dat = 0xfb;
	i2c1_write(LP8758_I2C_ADDR, adr, &dat, 1);

	/* Get board revision */
	printf("\n");
	printf("Getting Board Revision...\n");
	printf("-------------------------\n");

	board_revision = board_get_revision();

	printf("Rev%d.\n", board_revision);

	printf("\n");
	printf("DAC initialization...\n");
	printf("-------------------------\n");
	dac_init();

	printf("\n");
	printf("VCTCXO Initialization...\n");
	printf("----------------------\n");
	printf("Using VCTCXO Clk.\n");
	vctcxo_control_write(XTRX_VCTCXO_CLK);

	printf("\n");
	printf("LMS7002M Initialization...\n");
	printf("---------------------------\n");
	printf("LMS7002M Power-Down.\n");
	lms7002m_control_write(LMS7002M_RESET | LMS7002M_POWER_DOWN);
	busy_wait(1);
	printf("LMS7002M Reset.\n");
	lms7002m_control_write(LMS7002M_RESET);
	busy_wait(1);
	printf("LMS7002M TX/RX Enable.\n");
	lms7002m_control_write(LMS7002M_TX_ENABLE | LMS7002M_RX_ENABLE);

	printf("\n");
	printf("Board Tests...\n");
	printf("--------------\n");
	i2c_test();
	temp_test();
	vctcxo_test(2);

	return 1;
}

/*-----------------------------------------------------------------------*/
/* XSYNC Test                                                            */
/*-----------------------------------------------------------------------*/

#define SPI_CS_HIGH (0 << 0)
#define SPI_CS_LOW  (1 << 0)
#define SPI_START   (1 << 0)
#define SPI_DONE    (1 << 0)
#define SPI_LENGTH  (1 << 8)

static void xsync_spi_xfer(uint32_t word) {
    /* Write word on MOSI */
    xsync_spi_mosi_write(word);
    /* Initiate SPI Xfer */
    xsync_spi_control_write(32*SPI_LENGTH | SPI_START);
    /* Wait SPI Xfer to be done */
    while(xsync_spi_status_read() != SPI_DONE);
}

static void xsync_test(void)
{
	xsync_spi_xfer(0x5aa55aa5); /* FIXME: Add ADF4355 init sequence */
}

/*-----------------------------------------------------------------------*/
/* Console service / Main                                                */
/*-----------------------------------------------------------------------*/

static void console_service(void)
{
	char *str;
	char *token;

	str = readstr();
	if(str == NULL) return;
	token = get_token(&str);
	if(strcmp(token, "help") == 0)
		help();
	else if(strcmp(token, "reboot") == 0)
		reboot_cmd();
	else if(strcmp(token, "i2c_test") == 0)
		i2c_test();
	else if(strcmp(token, "temp_test") == 0)
		temp_test();
	else if(strcmp(token, "vctcxo_test") == 0)
		vctcxo_test(16);
	else if(strcmp(token, "digi_1v8") == 0)
		digi_1v8();
	else if(strcmp(token, "xtrx_init") == 0)
		xtrx_init();
	else if(strcmp(token, "pmic_dump") == 0)
		pmic_dump();
	else if(strcmp(token, "dac_dump") == 0)
		dac_dump();
	else if(strcmp(token, "xsync_test") == 0)
		xsync_test();
	prompt();
}

int main(void)
{
#ifdef CONFIG_CPU_HAS_INTERRUPT
	irq_setmask(0);
	irq_setie(1);
#endif
	uart_init();
	xtrx_init();

	help();
	prompt();

	while(1) {
		console_service();
	}

	return 0;
}
