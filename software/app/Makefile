CFLAGS=-O2 -Wall -g -I../kernel -I../user/liblitepcie -MMD
LDFLAGS=-g
CC=$(CROSS_COMPILE)gcc
AR=ar

PROGS=test_lms7002m_spi

all: $(PROGS)

test_lms7002m_spi: test_lms7002m_spi.o
	$(CC) $(LDFLAGS) -o $@ $^ -L../user/liblitepcie -llitepcie

clean:
	rm -f $(PROGS) *.o *.a *.d *~

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

-include $(wildcard *.d)
