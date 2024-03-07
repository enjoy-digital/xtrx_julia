/*
 * LitePCIe util
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2022 / Enjoy-Digital / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <inttypes.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include "liblitepcie.h"

/* Parameters */
/*------------*/

#define DMA_CHECK_DATA   /* Un-comment to disable data check */
#define DMA_RANDOM_DATA  /* Un-comment to disable data random */

/* Variables */
/*-----------*/

static char litepcie_device[1024];
static int litepcie_device_num;

sig_atomic_t keep_running = 1;

void intHandler(int dummy) {
    keep_running = 0;
}

/* Info */
/*------*/

static void info(void)
{
    int fd;
    int i;
    unsigned char fpga_identifier[256];

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }


    printf("\e[1m[> FPGA/SoC Information:\e[0m\n");
    printf("------------------------\n");

    for (i = 0; i < 256; i ++)
        fpga_identifier[i] = litepcie_readl(fd, CSR_IDENTIFIER_MEM_BASE + 4 * i);
    printf("FPGA Identifier:  %s.\n", fpga_identifier);
#ifdef CSR_DNA_BASE
    printf("FPGA DNA:         0x%08x%08x\n",
        litepcie_readl(fd, CSR_DNA_ID_ADDR + 4 * 0),
        litepcie_readl(fd, CSR_DNA_ID_ADDR + 4 * 1)
    );
#endif
#ifdef CSR_XADC_BASE
    printf("FPGA Temperature: %0.1f °C\n",
           (double)litepcie_readl(fd, CSR_XADC_TEMPERATURE_ADDR) * 503.975/4096 - 273.15);
    printf("FPGA VCC-INT:     %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCINT_ADDR) / 4096 * 3);
    printf("FPGA VCC-AUX:     %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCAUX_ADDR) / 4096 * 3);
    printf("FPGA VCC-BRAM:    %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCBRAM_ADDR) / 4096 * 3);
#endif
    close(fd);
}

/* Scratch */
/*---------*/

void scratch_test(void)
{
    int fd;

    printf("\e[1m[> Scratch register test:\e[0m\n");
    printf("-------------------------\n");

    /* Open LitePCIe device. */
    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* Write to scratch register. */
    printf("Write 0x12345678 to Scratch register:\n");
    litepcie_writel(fd, CSR_CTRL_SCRATCH_ADDR, 0x12345678);
    printf("Read: 0x%08x\n", litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR));

    /* Read from scratch register. */
    printf("Write 0xdeadbeef to Scratch register:\n");
    litepcie_writel(fd, CSR_CTRL_SCRATCH_ADDR, 0xdeadbeef);
    printf("Read: 0x%08x\n", litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR));

    /* Close LitePCIe device. */
    close(fd);
}

/* SPI Flash */
/*-----------*/

#ifdef CSR_FLASH_BASE

static void flash_progress(void *opaque, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    fflush(stdout);
    va_end(ap);
}

static void flash_program(uint32_t base, const uint8_t *buf1, int size1)
{
    int fd;

    uint32_t size;
    uint8_t *buf;
    int sector_size;
    int errors;

    /* Open LitePCIe device. */
    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* Get flash sector size and pad size to it. */
    sector_size = litepcie_flash_get_erase_block_size(fd);
    size = ((size1 + sector_size - 1) / sector_size) * sector_size;

    /* Alloc buffer and copy data to it. */
    buf = calloc(1, size);
    if (!buf) {
        fprintf(stderr, "%d: alloc failed\n", __LINE__);
        exit(1);
    }
    memcpy(buf, buf1, size1);

    /* Program flash. */
    printf("Programming (%d bytes at 0x%08x)...\n", size, base);
    errors = litepcie_flash_write(fd, buf, base, size, flash_progress, NULL);
    if (errors) {
        printf("Failed %d errors.\n", errors);
        exit(1);
    } else {
        printf("Success.\n");
    }

    /* Free buffer and close LitePCIe device. */
    free(buf);
    close(fd);
}

static void flash_write(const char *filename, uint32_t offset)
{
    uint8_t *data;
    int size;
    FILE * f;

    /* Open data source file. */
    f = fopen(filename, "rb");
    if (!f) {
        perror(filename);
        exit(1);
    }

    /* Get size, alloc buffer and copy data to it. */
    fseek(f, 0L, SEEK_END);
    size = ftell(f);
    fseek(f, 0L, SEEK_SET);
    data = malloc(size);
    if (!data) {
        fprintf(stderr, "%d: malloc failed\n", __LINE__);
        exit(1);
    }
    ssize_t ret = fread(data, size, 1, f);
    fclose(f);

    /* Program file to flash */
    if (ret != 1)
        perror(filename);
    else
        flash_program(offset, data, size);

    /* Free buffer */
    free(data);
}

static void flash_read(const char *filename, uint32_t size, uint32_t offset)
{
    int fd;
    FILE * f;
    uint32_t base;
    uint32_t sector_size;
    uint8_t byte;
    int i;

    /* Open data destination file. */
    f = fopen(filename, "wb");
    if (!f) {
        perror(filename);
        exit(1);
    }

    /* Open LitePCIe device. */
    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* Get flash sector size. */
    sector_size = litepcie_flash_get_erase_block_size(fd);

    /* Read flash and write to destination file. */
    base = offset;
    for (i = 0; i < size; i++) {
        if ((i % sector_size) == 0) {
            printf("Reading 0x%08x\r", base + i);
            fflush(stdout);
        }
        byte = litepcie_flash_read(fd, base + i);
        fwrite(&byte, 1, 1, f);
    }

    /* Close destination file and LitePCIe device. */
    fclose(f);
    close(fd);
}

static void flash_reload(void)
{
    int fd;

    /* Open LitePCIe device. */
    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* Reload FPGA through ICAP.*/
    litepcie_reload(fd);

    /* Notice user to reboot the hardware.*/
    printf("================================================================\n");
    printf("= PLEASE REBOOT YOUR HARDWARE TO START WITH NEW FPGA GATEWARE  =\n");
    printf("================================================================\n");

    /* Close LitePCIe device. */
    close(fd);
}
#endif

/* DMA */
/*-----*/

static inline int64_t add_mod_int(int64_t a, int64_t b, int64_t m)
{
    a += b;
    if (a >= m)
        a -= m;
    return a;
}

#ifdef DMA_CHECK_DATA

static inline uint32_t seed_to_data(uint32_t seed)
{
#ifdef DMA_RANDOM_DATA
    /* Return pseudo random data from seed. */
    return seed * 69069 + 1;
#else
    /* Return seed. */
    return seed;
#endif
}

static int get_next_pow2(int data_width)
{
    int x = 1;
    while (x < data_width)
        x <<= 1;
    return x;
}

static uint32_t get_data_mask(int data_width)
{
    int i;
    uint32_t mask;
    mask = 0;
    for (i = 0; i < 32/get_next_pow2(data_width); i++) {
        mask <<= get_next_pow2(data_width);
        mask |= (1 << data_width) - 1;
    }
    return mask;
}

static void write_pn_data(uint32_t *buf, int count, uint32_t *pseed, int data_width)
{
    int i;
    uint32_t seed;
    uint32_t mask = get_data_mask(data_width);

    seed = *pseed;
    for(i = 0; i < count; i++) {
        buf[i] = (seed_to_data(seed) & mask);
        seed = add_mod_int(seed, 1, DMA_BUFFER_SIZE / sizeof(uint32_t));
    }
    *pseed = seed;
}

static int check_pn_data(const uint32_t *buf, int count, uint32_t *pseed, int data_width)
{
    int i, errors;
    uint32_t seed;
    uint32_t mask = get_data_mask(data_width);

    errors = 0;
    seed = *pseed;
    for (i = 0; i < count; i++) {
        if (buf[i] != (seed_to_data(seed) & mask)) {
            errors ++;
        }
        seed = add_mod_int(seed, 1, DMA_BUFFER_SIZE / sizeof(uint32_t));
    }
    *pseed = seed;
    return errors;
}
#endif

static void dma_test(uint8_t zero_copy, uint8_t external_loopback, int data_width, int auto_rx_delay)
{
    static struct litepcie_dma_ctrl dma = {.use_reader = 1, .use_writer = 1};
    dma.loopback = external_loopback ? 0 : 1;

    if (data_width > 32 || data_width < 1) {
        fprintf(stderr, "Invalid data width %d\n", data_width);
        exit(1);
    }

    /* Statistics */
    int i = 0;
    int64_t reader_sw_count_last = 0;
    int64_t last_time;
    uint32_t errors = 0;

#ifdef DMA_CHECK_DATA
    uint32_t seed_wr = 0;
    uint32_t seed_rd = 0;
    uint8_t  run = (auto_rx_delay == 0);
#else
    uint8_t run = 1;
#endif

    signal(SIGINT, intHandler);

    printf("\e[1m[> DMA loopback test:\e[0m\n");
    printf("---------------------\n");

    if (litepcie_dma_init(&dma, litepcie_device, zero_copy))
        exit(1);

    /* Test loop. */
    last_time = get_time_ms();
    for (;;) {
        /* Exit loop on CTRL+C. */
        if (!keep_running)
            break;

        /* Update DMA status. */
        litepcie_dma_process(&dma);

#ifdef DMA_CHECK_DATA
        char *buf_wr;
        char *buf_rd;

        /* DMA-TX Write. */
        while (1) {
            /* Get Write buffer. */
            buf_wr = litepcie_dma_next_write_buffer(&dma);
            /* Break when no buffer available for Write. */
            if (!buf_wr)
                break;
            /* Write data to buffer. */
            write_pn_data((uint32_t *) buf_wr, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_wr, data_width);
        }

        /* DMA-RX Read/Check */
        while (1) {
            /* Get Read buffer. */
            buf_rd = litepcie_dma_next_read_buffer(&dma);
            /* Break when no buffer available for Read. */
            if (!buf_rd)
                break;
            /* Skip the first 128 DMA loops. */
            if (dma.writer_hw_count < 128*DMA_BUFFER_COUNT)
                break;
            /* When running... */
            if (run) {
                /* Check data in Read buffer. */
                errors += check_pn_data((uint32_t *) buf_rd, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_rd, data_width);
                /* Clear Read buffer */
                memset(buf_rd, 0, DMA_BUFFER_SIZE);
            } else {
                /* Find initial Delay/Seed (Useful when loopback is introducing delay). */
                uint32_t errors_min = 0xffffffff;
                for (int delay = 0; delay < DMA_BUFFER_SIZE / sizeof(uint32_t); delay++) {
                    seed_rd = delay;
                    errors = check_pn_data((uint32_t *) buf_rd, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_rd, data_width);
                    //printf("delay: %d / errors: %d\n", delay, errors);
                    if (errors < errors_min)
                        errors_min = errors;
                    if (errors < (DMA_BUFFER_SIZE / sizeof(uint32_t)) / 2) {
                        printf("RX_DELAY: %d (errors: %d)\n", delay, errors);
                        run = 1;
                        break;
                    }
                }
                if (!run) {
                    printf("Unable to find DMA RX_DELAY (min errors: %d/%ld), exiting.\n",
                        errors_min,
                        DMA_BUFFER_SIZE / sizeof(uint32_t));
                    goto end;
                }
            }

        }
#endif

        /* Statistics every 200ms. */
        int64_t duration = get_time_ms() - last_time;
        if (run & (duration > 200)) {
            /* Print banner every 10 lines. */
            if (i % 10 == 0)
                printf("\e[1mDMA_SPEED(Gbps)\tTX_BUFFERS\tRX_BUFFERS\tDIFF\tERRORS\e[0m\n");
            i++;
            /* Print statistics. */
            printf("%14.2f\t%10" PRIu64 "\t%10" PRIu64 "\t%4" PRIu64 "\t%6u\n",
                   (double)(dma.reader_sw_count - reader_sw_count_last) * DMA_BUFFER_SIZE * 8 * data_width / (get_next_pow2(data_width) * (double)duration * 1e6),
                   dma.reader_sw_count,
                   dma.writer_sw_count,
                   dma.reader_sw_count - dma.writer_sw_count,
                   errors);
            /* Update errors/time/count. */
            errors = 0;
            last_time = get_time_ms();
            reader_sw_count_last = dma.reader_sw_count;
        }
    }


    /* Cleanup DMA. */
#ifdef DMA_CHECK_DATA
end:
#endif
    litepcie_dma_cleanup(&dma);
}

/* UART */
/*------*/

#ifdef CSR_UART_XOVER_RXTX_ADDR
void uart_test(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    litepcie_writel(fd, CSR_CTRL_RESET_ADDR, 1); /* reset CPU */

    while (1) {
        if ((litepcie_readl(fd, CSR_UART_XOVER_RXEMPTY_ADDR) & 0x1) == 0) {
            printf("%c", litepcie_readl(fd, CSR_UART_XOVER_RXTX_ADDR) & 0xff);
        }
    }

    close(fd);
}
#endif

/* GPS */
/*-----*/

void gps_test(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
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

/* LMS7002M */
/*----------*/

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

void lms7002m_reset(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
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

    printf("Reset LMS7002M...\n");
    lms7002m_spi_write(fd, 0x20, 0x0000);
    printf("0x20: 0x%04x\n", lms7002m_spi_read(fd, 0x20));
    lms7002m_spi_write(fd, 0x20, 0xffff);
    printf("0x20: 0x%04x\n", lms7002m_spi_read(fd, 0x20));

    close(fd);
}


void lms7002m_dump(void)
{
    int fd;
    int i;

    fd = open(litepcie_device, O_RDWR);
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
    for (i=0; i<64; i++) {
        printf("reg 0x%04x: 0x%04x\n", i, lms7002m_spi_read(fd, i));
    }

    close(fd);
}

void lms7002m_set_tx_pattern(uint8_t enable)
{
    int fd;
    uint32_t control;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    printf("Setting LMS7002M FPGA TX pattern to %d\n", enable);
    control  = litepcie_readl(fd, CSR_LMS7002M_TX_PATTERN_CONTROL_ADDR);
    control &= ~(1 << CSR_LMS7002M_TX_PATTERN_CONTROL_ENABLE_OFFSET);
    control |= enable *(1 << CSR_LMS7002M_TX_PATTERN_CONTROL_ENABLE_OFFSET);
    litepcie_writel(fd, CSR_LMS7002M_TX_PATTERN_CONTROL_ADDR, control);

    close(fd);
}

void lms7002m_set_tx_rx_loopback(uint8_t enable)
{
    int fd;
    uint32_t control;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    printf("Setting LMS7002M FPGA TX-RX internal loopback to %d\n", enable);
    control  = litepcie_readl(fd, CSR_LMS7002M_CONTROL_ADDR);
    control &= ~(1 << CSR_LMS7002M_CONTROL_TX_RX_LOOPBACK_ENABLE_OFFSET);
    control |= enable *(1 << CSR_LMS7002M_CONTROL_TX_RX_LOOPBACK_ENABLE_OFFSET);
    litepcie_writel(fd, CSR_LMS7002M_CONTROL_ADDR, control);

    close(fd);
}

/* Help */
/*------*/

static void help(void)
{
    printf("LitePCIe utilities\n"
           "usage: litepcie_util [options] cmd [args...]\n"
           "\n"
           "options:\n"
           "-h                                Help.\n"
           "-c device_num                     Select the FPGA device (default = 0).\n"
           "-g device_num                     Select the GPU device (default = -1, disabled).\n"
           "-z                                Enable zero-copy DMA mode.\n"
           "-e                                Use external loopback (default = internal).\n"
           "-w data_width                     Width of data bus (default = 16).\n"
           "-a                                Automatic DMA RX-Delay calibration.\n"
           "\n"
           "available commands:\n"
           "info                              Get Board information.\n"
           "\n"
           "dma_test                          Test DMA.\n"
           "scratch_test                      Test Scratch register.\n"
#ifdef CSR_UART_XOVER_RXTX_ADDR
           "uart_test                         Test CPU Crossover UART\n"
#endif
           "gps_test                          Test GPS\n"
           "\n"
           "lms_reset                         Reset LMS7002M\n"
           "lms_dump                          Dump LMS7002M registers\n"
           "lms_set_tx_pattern                Set LMS7002M TX pattern\n"
           "lms_set_tx_rx_loopback            Set LMS7002M TX-RX loopback (in FPGA)\n"
           "\n"
#ifdef CSR_FLASH_BASE
           "flash_write filename [offset]     Write file contents to SPI Flash.\n"
           "flash_read filename size [offset] Read from SPI Flash and write contents to file.\n"
           "flash_reload                      Reload FPGA Image.\n"
#endif
           );
    exit(1);
}

/* Main */
/*------*/

int main(int argc, char **argv)
{
    const char *cmd;
    int c;
    static uint8_t litepcie_device_zero_copy;
    static uint8_t litepcie_device_external_loopback;
    static int litepcie_data_width;
    static int litepcie_auto_rx_delay;

    litepcie_device_num = 0;
    litepcie_data_width = 16;
    litepcie_auto_rx_delay = 0;
    litepcie_device_zero_copy = 0;
    litepcie_device_external_loopback = 0;

    /* Parameters. */
    for (;;) {
        c = getopt(argc, argv, "hc:w:zea");
        if (c == -1)
            break;
        switch(c) {
        case 'h':
            help();
            break;
        case 'c':
            litepcie_device_num = atoi(optarg);
            break;
        case 'w':
            litepcie_data_width = atoi(optarg);
            break;
        case 'z':
            litepcie_device_zero_copy = 1;
            break;
        case 'e':
            litepcie_device_external_loopback = 1;
            break;
        case 'a':
            litepcie_auto_rx_delay = 1;
            break;
        default:
            exit(1);
        }
    }

    /* Show help when too much args. */
    if (optind >= argc)
        help();

    /* Select device. */
    snprintf(litepcie_device, sizeof(litepcie_device), "/dev/litepcie%d", litepcie_device_num);

    cmd = argv[optind++];

    /* Info cmds. */
    if (!strcmp(cmd, "info"))
        info();
    /* Scratch cmds. */
    else if (!strcmp(cmd, "scratch_test"))
        scratch_test();
    /* UART cmds. */
#ifdef CSR_UART_XOVER_RXTX_ADDR
    else if (!strcmp(cmd, "uart_test"))
        uart_test();
#endif
    /* GPS cmds. */
    else if (!strcmp(cmd, "gps_test"))
        gps_test();
    /* SPI Flash cmds. */
#if CSR_FLASH_BASE
    else if (!strcmp(cmd, "flash_write")) {
        const char *filename;
        uint32_t offset = 0;
        if (optind + 1 > argc)
            goto show_help;
        filename = argv[optind++];
        if (optind < argc)
            offset = strtoul(argv[optind++], NULL, 0);
        flash_write(filename, offset);
    }
    else if (!strcmp(cmd, "flash_read")) {
        const char *filename;
        uint32_t size = 0;
        uint32_t offset = 0;
        if (optind + 2 > argc)
            goto show_help;
        filename = argv[optind++];
        size = strtoul(argv[optind++], NULL, 0);
        if (optind < argc)
            offset = strtoul(argv[optind++], NULL, 0);
        flash_read(filename, size, offset);
    }
    else if (!strcmp(cmd, "flash_reload"))
        flash_reload();
#endif
    /* DMA cmds. */
    else if (!strcmp(cmd, "dma_test"))
        dma_test(
            litepcie_device_zero_copy,
            litepcie_device_external_loopback,
            litepcie_data_width,
            litepcie_auto_rx_delay);
    /* LMS7002M cmds. */
    else if (!strcmp(cmd, "lms_reset"))
        lms7002m_reset();
    else if (!strcmp(cmd, "lms_dump"))
        lms7002m_dump();
    else if (!strcmp(cmd, "lms_set_tx_pattern")) {
        uint8_t enable = 0;
        if (optind + 1 > argc)
            goto show_help;
        enable = strtoul(argv[optind++], NULL, 0);
        lms7002m_set_tx_pattern(enable);
    } else if (!strcmp(cmd, "lms_set_tx_rx_loopback")) {
        uint8_t enable = 0;
        if (optind + 1 > argc)
            goto show_help;
        enable = strtoul(argv[optind++], NULL, 0);
        lms7002m_set_tx_rx_loopback(enable);
    }

    /* Show help otherwise. */
    else
        goto show_help;

    return 0;

show_help:
        help();

    return 0;
}
