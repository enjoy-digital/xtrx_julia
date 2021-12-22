/*
 * LiteX/XTRX util
 *
 * This file is part of XTRX-Julia.
 *
 * Copyright (c) 2021 Florent Kermarrec <florent@enjoy-digital.fr>
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

#define DMA_CHECK_DATA
#define DMA_RANDOM_DATA

static char litepcie_device[1024];
static int litepcie_device_num;

sig_atomic_t keep_running = 1;

void intHandler(int dummy) {
    keep_running = 0;
}

/* info */

static void info(void)
{
    int fd;
    int i;
    unsigned char fpga_identification[256];

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    for (i = 0; i < 256; i ++)
        fpga_identification[i] = litepcie_readl(fd, CSR_IDENTIFIER_MEM_BASE + 4 * i);
    printf("FPGA identification: %s\n", fpga_identification);
#ifdef CSR_DNA_BASE
    printf("FPGA dna: 0x%08x%08x\n",
        litepcie_readl(fd, CSR_DNA_ID_ADDR + 4 * 0),
        litepcie_readl(fd, CSR_DNA_ID_ADDR + 4 * 1)
    );
#endif
#ifdef CSR_XADC_BASE
    printf("FPGA temperature: %0.1f °C\n",
           (double)litepcie_readl(fd, CSR_XADC_TEMPERATURE_ADDR) * 503.975/4096 - 273.15);
    printf("FPGA vccint: %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCINT_ADDR) / 4096 * 3);
    printf("FPGA vccaux: %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCAUX_ADDR) / 4096 * 3);
    printf("FPGA vccbram: %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCBRAM_ADDR) / 4096 * 3);
#endif
    close(fd);
}

/* gps */

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

/* flash */

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

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    sector_size = litepcie_flash_get_erase_block_size(fd);

    /* pad to sector_size */
    size = ((size1 + sector_size - 1) / sector_size) * sector_size;

    buf = calloc(1, size);
    if (!buf) {
        fprintf(stderr, "%d: alloc failed\n", __LINE__);
        exit(1);
    }
    memcpy(buf, buf1, size1);

    printf("Programming (%d bytes at 0x%08x)\n", size, base);

    errors = litepcie_flash_write(fd, buf, base, size, flash_progress, NULL);

    /* result */
    if (errors) {
        printf("Failed %d errors\n", errors);
        exit(1);
    } else {
        printf("Success\n");
    }

    free(buf);

    close(fd);
}

static void flash_write(const char *filename, uint32_t offset)
{
    uint8_t *data;
    int size;
    FILE * f;

    f = fopen(filename, "rb");
    if (!f) {
        perror(filename);
        exit(1);
    }

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

    if (ret != 1)
        perror(filename);
    else
        flash_program(offset, data, size);

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

    f = fopen(filename, "wb");
    if (!f) {
        perror(filename);
        exit(1);
    }

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    base = offset;
    sector_size = litepcie_flash_get_erase_block_size(fd);
    for (i = 0; i < size; i++) {
        if ((i % sector_size) == 0) {
            printf("Dumping %08x\r", base + i);
            fflush(stdout);
        }
        byte = litepcie_flash_read(fd, base + i);
        fwrite(&byte, 1, 1, f);
    }

    fclose(f);

    close(fd);
}

static void flash_reload(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* reload fpga */
    litepcie_reload(fd);

    printf("================================================================\n");
    printf("= PLEASE REBOOT YOUR HARDWARE TO START WITH NEW FPGA GATEWARE  =\n");
    printf("================================================================\n");

    close(fd);
}
#endif

/* dma */

static inline int64_t add_mod_int(int64_t a, int64_t b, int64_t m)
{
    a += b;
    if (a >= m)
        a -= m;
    return a;
}

#ifdef DMA_CHECK_DATA
static inline uint16_t seed_to_data(uint16_t seed)
{
#ifdef DMA_RANDOM_DATA
    return seed * 69069 + 1;
#else
    return seed;
#endif
}

static void write_pn_data(uint16_t *buf, int count, uint16_t *pseed, int data_width)
{
    int i;
    uint16_t seed;
    uint16_t mask = (1 << data_width) - 1;

    seed = *pseed;
    for(i = 0; i < count; i++) {
        buf[i] = (seed_to_data(seed)&mask);
        seed = add_mod_int(seed, 1, DMA_BUFFER_SIZE / 2);
    }
    *pseed = seed;
}

static int check_pn_data(const uint16_t *buf, int count, uint16_t *pseed, int data_width)
{
    int i, errors;
    uint16_t seed;
    uint16_t mask = (1 << data_width) - 1;

    errors = 0;
    seed = *pseed;
    for (i = 0; i < count; i++) {
        if (buf[i] != (seed_to_data(seed)&mask)) {
            errors ++;
        }
        seed = add_mod_int(seed, 1, DMA_BUFFER_SIZE / 2);
    }
    *pseed = seed;
    return errors;
}
#endif

static void dma_test(uint8_t zero_copy, uint8_t external_loopback, int data_width)
{
    static struct litepcie_dma_ctrl dma = {.use_reader = 1, .use_writer = 1};
    dma.loopback = external_loopback ? 0 : 1;

    if (data_width > 16 || data_width < 1) {
        fprintf(stderr, "Invalid data width %d\n", data_width);
        exit(1);
    }

    // stats
    int i = 0;
    int64_t reader_sw_count_last = 0;
    int64_t last_time;
    uint32_t errors = 0;

#ifdef DMA_CHECK_DATA
    uint32_t seed_wr = 0;
    uint32_t seed_rd = 0;
    unsigned n_buffers_written = 0;
#endif

    signal(SIGINT, intHandler);

    if (litepcie_dma_init(&dma, litepcie_device, zero_copy))
        exit(1);

    /* test loop */
    last_time = get_time_ms();
    for (;;) {
        /* exit loop on ctrl+c pressed */
        if (!keep_running)
            break;

        litepcie_dma_process(&dma);

#ifdef DMA_CHECK_DATA
        if (n_buffers_written < DMA_BUFFER_COUNT) {
            while (1) {
                char *buf_wr = litepcie_dma_next_write_buffer(&dma);
                if (!buf_wr)
                    break;
                write_pn_data((uint16_t *) buf_wr, DMA_BUFFER_SIZE / sizeof(uint16_t), &seed_wr, data_width);
                n_buffers_written++;
            }
        } else {
            uint32_t check_errors = 0;
            while (1) {
                char *buf_rd = litepcie_dma_next_read_buffer(&dma);
                if (!buf_rd)
                    break;
                check_errors += check_pn_data((uint16_t *) buf_rd, DMA_BUFFER_SIZE / sizeof(uint16_t), &seed_rd, data_width);
                memset(buf_rd, 0, DMA_BUFFER_SIZE);
                if (dma.writer_hw_count > DMA_BUFFER_COUNT)
                    errors += check_errors;
            }
        }
#endif

        /* statistics */
        int64_t duration = get_time_ms() - last_time;
        if (duration > 200) {
            if (i % 10 == 0)
                printf("\e[1mDMA_SPEED(Gbps)\tTX_BUFFERS\tRX_BUFFERS\tDIFF\tERRORS\e[0m\n");
            i++;
            printf("%14.2f\t%10" PRIu64 "\t%10" PRIu64 "\t%6" PRIu64 "\t%7u\n",
                   (double)(dma.reader_sw_count - reader_sw_count_last) * DMA_BUFFER_SIZE * 8 / ((double)duration * 1e6),
                   dma.reader_sw_count,
                   dma.writer_sw_count,
                   dma.reader_sw_count - dma.writer_sw_count,
                   errors);
            errors = 0;
            last_time = get_time_ms();
            reader_sw_count_last = dma.reader_sw_count;
        }
    }

    litepcie_dma_cleanup(&dma);
}

/* lms7002m */

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
    control  = litepcie_readl(fd, CSR_LMS7002M_CONTROL_ADDR);
    control &= ~(1 << CSR_LMS7002M_CONTROL_TX_PATTERN_ENABLE_OFFSET);
    control |= enable *(1 << CSR_LMS7002M_CONTROL_TX_PATTERN_ENABLE_OFFSET);
    litepcie_writel(fd, CSR_LMS7002M_CONTROL_ADDR, control);

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

/* help */

static void help(void)
{
    printf("LiteX-XTRX utilities\n"
           "usage: litex_xtrx_util [options] cmd [args...]\n"
           "\n"
           "options:\n"
           "-h                                Help\n"
           "-c device_num                     Select the device (default = 0)\n"
           "-z                                Enable zero-copy DMA mode\n"
           "-e                                Use external loopback (default = internal)\n"
           "-w data_width                     Width of data bus (default = 16)\n"
           "\n"
           "available commands:\n"
           "info                              Board information\n"
           "gps_test                          Test GPS\n"
           "dma_test                          Test DMA\n"
           "\n"
           "lms_reset                         Reset LMS7002M\n"
           "lms_dump                          Dump LMS7002M registers\n"
           "lms_set_tx_pattern                Set LMS7002M TX pattern\n"
           "lms_set_tx_rx_loopback            Set LMS7002M TX-RX loopback (in FPGA)\n"
           "\n"
#ifdef CSR_FLASH_BASE
           "flash_write filename [offset]     Write file contents to SPI Flash\n"
           "flash_read filename size [offset] Read from SPI Flash and write contents to file.\n"
           "flash_reload                      Reload FPGA Image.\n"
#endif
           );
    exit(1);
}

/* main */

int main(int argc, char **argv)
{
    const char *cmd;
    int c;
    static uint8_t litepcie_device_zero_copy;
    static uint8_t litepcie_device_external_loopback;
    static int litepcie_data_width;


    litepcie_device_num = 0;
    litepcie_data_width = 16;
    litepcie_device_zero_copy = 0;
    litepcie_device_external_loopback = 0;

    /* parameters */
    for (;;) {
        c = getopt(argc, argv, "hc:w:ze");
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
        default:
            exit(1);
        }
    }

    if (optind >= argc)
        help();

    /* select device */
    snprintf(litepcie_device, sizeof(litepcie_device), "/dev/litepcie%d", litepcie_device_num);

    cmd = argv[optind++];

    if (!strcmp(cmd, "info"))
        info();
    else if (!strcmp(cmd, "gps_test"))
        gps_test();
    else if (!strcmp(cmd, "dma_test"))
        dma_test(litepcie_device_zero_copy, litepcie_device_external_loopback, litepcie_data_width);
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
    } else
        goto show_help;

    return 0;

show_help:
        help();

    return 0;
}
