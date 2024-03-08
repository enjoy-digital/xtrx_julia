#include <LMS7002M/LMS7002M.h>
#include <LMS7002M/LMS7002M_logger.h>

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

#include "litepcie_interface.h"

//signal handle for ctrl+c
static bool user_exit = false;
void sig_handler(int s)
{
    user_exit = true;
}

#define REF_FREQ 26e6

int main(int argc, char **argv)
{
    LMS7_set_log_level(LMS7_DEBUG);

    printf("=========================================================\n");
    printf("== Test LMS7002M access                                  \n");
    printf("=========================================================\n");
    if (argc < 2)
    {
        printf("Usage %s /dev/litepcieX\n", argv[0]);
        return EXIT_FAILURE;
    }

    int fd = open(argv[1], O_RDWR);
    if (fd < 0) {
        perror("open");
        return EXIT_FAILURE;
    }
    int ret = 0;

    printf("Read scratch 0x%x\n", litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR));

    //perform reset
    //TODO

    //create and test lms....
    printf("Create LMS7002M instance\n");
    LMS7002M_t *lms = LMS7002M_create(litepcie_interface_transact, &fd);
    if (lms == NULL) return EXIT_FAILURE;
    LMS7002M_reset(lms);
    LMS7002M_set_spi_mode(lms, 4); //set 4-wire spi before reading back

    //read info register
    LMS7002M_regs_spi_read(lms, 0x002f);
    printf("rev 0x%x\n", LMS7002M_regs(lms)->reg_0x002f_rev);
    printf("ver 0x%x\n", LMS7002M_regs(lms)->reg_0x002f_ver);

    //turn ldo on
    LMS7002M_ldo_enable(lms, true, LMS7002M_LDO_ALL);

    //turn the clocks on
    double actualRate = 0.0;
    ret = LMS7002M_set_data_clock(lms, REF_FREQ, 61.44e6, &actualRate);
    if (ret != 0)
    {
        printf("clock tune failure %d\n", ret);
		// FIXME
        //return EXIT_FAILURE;
    }

    // TODO

    printf("Debug setup!\n");
    printf("Press ctrl+c to exit\n");
    signal(SIGINT, sig_handler);
    while (!user_exit) sleep(1);

    //power down and clean up
    printf("Power down!\n");
    LMS7002M_power_down(lms);
    LMS7002M_destroy(lms);

    close(fd);

    printf("Done!\n");
    return EXIT_SUCCESS;
}
