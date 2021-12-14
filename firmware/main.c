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
	puts("tcxo_test          - Test TCXO");
	puts("pmic_init          - Initialize PMICs");
}

/*-----------------------------------------------------------------------*/
/* Commands                                                              */
/*-----------------------------------------------------------------------*/

static void reboot_cmd(void)
{
	ctrl_reset_write(1);
}

/*-----------------------------------------------------------------------*/
/* I2C                                                                   */
/*-----------------------------------------------------------------------*/

static void i2c_test(void)
{
	printf("I2C0 Scan...\n");
	i2c0_scan();

	printf("I2C1 Scan...\n");
	i2c1_scan();
}

/*-----------------------------------------------------------------------*/
/* Temperature                                                           */
/*-----------------------------------------------------------------------*/

#define TMP108_ADDR 0x4a

static void temp_test(void)
{
	unsigned int temp;
	unsigned char dat[2];
	i2c1_read(TMP108_ADDR, 0x00, dat, 2, true);
	temp = (dat[0] << 4) | (dat[1] >> 4);
	temp = (62500*temp)/1000000; /* 0.0625°C/count */
	printf("Temperature: %d°C\n", temp);
}

/*-----------------------------------------------------------------------*/
/* TCXO                                                                  */
/*-----------------------------------------------------------------------*/

#define LTC26X6_ADDR 0x62 /* Test LTC26X6 effect on TCXO */

static void tcxo_test(void)
{
	int i;
	int prev;
	int curr;
	prev = 0;
	printf("TCXO test...\n");
	tcxo_control_write(0); /* TCXO: 0 / Ext: 1 */
	for (i=0; i<10; i++) {
		tcxo_cycles_latch_write(1);
		curr = tcxo_cycles_read(),
		printf("TCXO Cycles: %3d.%03dMHz\n", (curr - prev)/100000, ((curr - prev)/100)%1000);
		prev = curr;
		busy_wait(100);
	}
}

/*-----------------------------------------------------------------------*/
/* PMIC                                                                  */
/*-----------------------------------------------------------------------*/

#define LP8758_ADDR 0x60

static int pmic_init(void)
{
	unsigned char adr;
	unsigned char dat;

	printf("PMICs Initialization...\n");

	tcxo_control_write(0b01); /* FIXME: Move Power-Down */

	printf("PMIC-LMS: Check ID ");
	adr = 0x01;
	i2c0_read(LP8758_ADDR, adr, &dat, 1, true);
	if (dat != 0xe0) {
		printf("KO, exiting.\n");
		return 0;
	} else {
		printf("OK.\n");
	}

	printf("PMIC-LMS: Enable Buck1.\n");
	adr = 0x04;
	dat = 0x88;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck1 to 3280mV.\n");
	adr = 0x0c;
	dat = 0xfb;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Disable Buck0.\n");
	adr = 0x02;
	dat = 0xc8;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Disable Buck2.\n");
	adr = 0x06;
	dat = 0xc8;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Disable Buck3.\n");
	adr = 0x08;
	dat = 0xc8;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck0 to 1880mV.\n");
	adr = 0x0a;
	dat = 0xb5;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck2 to 1480mV.\n");
	adr = 0x0e;
	dat = 0xa1;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Set Buck3 to 1340mV.\n");
	adr = 0x10;
	dat = 0x92;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	busy_wait(1);

	printf("PMIC-FPGA: Check ID ");
	adr = 0x1;
	i2c1_read(LP8758_ADDR, adr, &dat, 1, true);
	if (dat != 0xe0) {
		printf("KO, exiting.\n");
		return 0;
	} else {
		printf("OK.\n");
	}


	printf("PMIC-LMS: Enable Buck0.\n");
	adr = 0x02;
	dat = 0x88;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Enable Buck2.\n");
	adr = 0x06;
	dat = 0x88;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-LMS: Enable Buck3.\n");
	adr = 0x08;
	dat = 0x88;
	i2c0_write(LP8758_ADDR, adr, &dat, 1);

	printf("PMIC-FPGA: Set Buck1 to 1800mV.\n");
	adr = 0x0c;
	dat = 0xb1;
	i2c1_write(LP8758_ADDR, adr, &dat, 1);


#if 0
	printf("PMIC-LMS Dump...\n");
	for (adr=0; adr<32; adr++) {
		i2c0_read(LP8758_ADDR, adr, &dat, 1, true);
		printf("0x%02x: 0x%02x\n", adr, dat);
	}
	printf("PMIC-FPGA Dump...\n");
	for (adr=0; adr<32; adr++) {
		i2c1_read(LP8758_ADDR, adr, &dat, 1, true);
		printf("0x%02x: 0x%02x\n", adr, dat);
	}
#endif

	return 1;
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
	else if(strcmp(token, "tcxo_test") == 0)
		tcxo_test();
	else if(strcmp(token, "pmic_init") == 0)
		pmic_init();
	prompt();
}

int main(void)
{
#ifdef CONFIG_CPU_HAS_INTERRUPT
	irq_setmask(0);
	irq_setie(1);
#endif
	uart_init();

	help();
	prompt();

	while(1) {
		console_service();
	}

	return 0;
}
