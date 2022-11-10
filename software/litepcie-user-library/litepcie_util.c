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

static int cuda_device_num;

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
#ifdef CUDA
    if (cuda_device_num >= 0) {
        checked_cuda_call(cuInit(0));

        CUdevice device;
        checked_cuda_call(cuDeviceGet(&device, cuda_device_num));

        char name[256];
        checked_cuda_call(cuDeviceGetName(name, 256, device));
        fprintf(stderr, "GPU identification: %s\n", name);

        // get compute capabilities and the devicename
        int major = 0, minor = 0;
        checked_cuda_call(
            cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, device));
        checked_cuda_call(
            cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, device));
        fprintf(stderr, "GPU compute capability: %d.%d\n", major, minor);

        size_t global_mem = 0;
        checked_cuda_call(cuDeviceTotalMem(&global_mem, device));
        fprintf(stderr, "GPU global memory: %llu MB\n", (unsigned long long)(global_mem >> 20));
        if (global_mem > (unsigned long long)4 * 1024 * 1024 * 1024L)
            fprintf(stderr, "GPU 64-bit memory address support\n");
    }
#endif
}

/* Scratch */
/*---------*/

int scratch_test(void)
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
    int ascending = litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR);
    printf("Read: 0x%08x\n", ascending);

    /* Read from scratch register. */
    printf("Write 0xdeadbeef to Scratch register:\n");
    litepcie_writel(fd, CSR_CTRL_SCRATCH_ADDR, 0xdeadbeef);
    int deadbeef = litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR);
    printf("Read: 0x%08x\n", deadbeef);

    /* Close LitePCIe device. */
    close(fd);

    /* Explicitly return exit codes for `main()` here */
    if (ascending == 0x12345678 && deadbeef == 0xdeadbeef)
        return 0;
    return 1;
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

static void dma_test(uint8_t zero_copy, uint8_t external_loopback, int data_width, int auto_rx_delay, int64_t total_duration_ms, int64_t expected_buffers)
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
    int64_t start_time, last_print_time;
    uint32_t errors = 0;

#ifdef DMA_CHECK_DATA
    uint32_t seed_wr = 0;
    uint32_t seed_rd = 0;
    uint8_t  run = (auto_rx_delay == 0);
#endif

#ifdef CUDA
    CUdevice gpu_dev;
    CUcontext gpu_ctx;
    if (cuda_device_num >= 0) {
        checked_cuda_call(cuInit(0));
        checked_cuda_call(cuDeviceGet(&gpu_dev, cuda_device_num));
        checked_cuda_call(cuCtxCreate(&gpu_ctx, 0, gpu_dev));
    }
#endif

    signal(SIGINT, intHandler);

    printf("\e[1m[> DMA loopback test:\e[0m\n");
    printf("---------------------\n");

    if (litepcie_dma_init(&dma, litepcie_device, zero_copy, cuda_device_num >= 0))
        exit(1);

#if defined(DMA_CHECK_DATA) && defined(CUDA)
    if (cuda_device_num >= 0) {
        write_pn_data((uint32_t *) dma.buf_wr, DMA_BUFFER_TOTAL_SIZE/4, &seed_wr, data_width);

        // check whether GPU memory, initialized by writing to mmapped memory,
        // can be read back and verified using CUDA API calls.
        void* cpu_buf = malloc(2*DMA_BUFFER_TOTAL_SIZE);
        checked_cuda_call(cuMemcpyDtoH(cpu_buf, dma.gpu_buf, 2*DMA_BUFFER_TOTAL_SIZE));
        for (i = 0; i < DMA_BUFFER_COUNT; i++) {
            // access the underlying memory in the way the kernel driver would
            errors += check_pn_data(
                (uint32_t *) cpu_buf + i*DMA_BUFFER_SIZE/2,
                DMA_BUFFER_SIZE/4,
                &seed_rd, data_width
            );
        }
        if (errors) {
            fprintf(stderr, "GPU memory initialization failed (%d errors), exiting.\n", errors);
            exit(1);
        }
    }
#endif

    /* Test loop. */
    start_time = get_time_ms();
    last_print_time = get_time_ms();
    for (;;) {
        /* Exit loop on CTRL+C. */
        if (!keep_running)
            break;

        /* Update DMA status. */
        litepcie_dma_process(&dma);

#ifdef DMA_CHECK_DATA
        char *buf_wr;
        char *buf_rd;

        // XXX: these individual read/write operations are very expensive
        //      when backed by a GPU buffer, so disable data verification.

        /* DMA-TX Write. */
        while (cuda_device_num == -1) {
            /* Get Write buffer. */
            buf_wr = litepcie_dma_next_write_buffer(&dma);
            /* Break when no buffer available for Write. */
            if (!buf_wr)
                break;
            /* Write data to buffer. */
            write_pn_data((uint32_t *) buf_wr, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_wr, data_width);
        }

        /* DMA-RX Read/Check */
        while (cuda_device_num == -1) {
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
        int64_t curr_time = get_time_ms();
        if (run && ((curr_time - last_print_time) > 200)) {
            /* Print banner every 10 lines. */
            if (i % 10 == 0)
                printf("\e[1mDMA_SPEED(Gbps)\tTX_BUFFERS\tRX_BUFFERS\tLOADED\tRX_BUFFERS/SEC\tERRORS\e[0m\n");
            i++;
            /* Print statistics. */
            printf("%14.2f\t%10" PRIu64 "\t%10" PRIu64 "\t%4" PRIu64 "\t%.1f\t%6u\n",
                   (double)(dma.reader_sw_count - reader_sw_count_last) * DMA_BUFFER_SIZE * 8 * data_width / (get_next_pow2(data_width) * (double)(curr_time - last_print_time) * 1e6),
                   dma.reader_sw_count,
                   dma.writer_sw_count,
                   dma.reader_sw_count - dma.writer_sw_count,
                   dma.writer_sw_count*1000.0/(curr_time - start_time),
                   errors);
            /* Update errors/time/count. */
            errors = 0;
            last_print_time = curr_time;
            reader_sw_count_last = dma.reader_sw_count;
        }

        /* If we've been given a total duration, use it to set `keep_running` here.*/
        if (run && (total_duration_ms > 0) && ((curr_time - start_time) > total_duration_ms)) {
            keep_running = 0;
        }
    }

    float avg_buffers_per_second;
end:
    /* Cleanup DMA. */
    avg_buffers_per_second = dma.reader_sw_count * 1000.0 / (get_time_ms() - start_time);
    litepcie_dma_cleanup(&dma);

    /* If we have been given either an expected buffer count, fail the test if we have not transferred enough. */
    if (expected_buffers > 0 && (dma.reader_sw_count < expected_buffers)) {
        return 1;
    }
    return 0;
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
           "-t timeout                        Automatic timeout in milliseconds (default = 0).\n"
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
    static int64_t total_duration_ms;
    static int64_t expected_buffer_count;

    litepcie_device_num = 0;
    litepcie_data_width = 16;
    litepcie_auto_rx_delay = 0;
    litepcie_device_zero_copy = 0;
    litepcie_device_external_loopback = 0;
    total_duration_ms = 0;
    expected_buffer_count = 0;

    cuda_device_num = -1;

    /* Parameters. */
    for (;;) {
        c = getopt(argc, argv, "hc:g:w:t:b:r:zea");
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
        case 't':
            total_duration_ms = atoi(optarg);
            break;
        case 'z':
            litepcie_device_zero_copy = 1;
            break;
        case 'g':
            cuda_device_num = atoi(optarg);
            break;
        case 'e':
            litepcie_device_external_loopback = 1;
            break;
        case 'a':
            litepcie_auto_rx_delay = 1;
            break;
        case 'b':
            expected_buffer_count = atoi(optarg);
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

    if (!strcmp(cmd, "info"))
        info();
    /* Scratch cmds. */
    else if (!strcmp(cmd, "scratch_test"))
        return scratch_test();
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
            litepcie_auto_rx_delay,
            total_duration_ms,
            expected_buffer_count);
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
