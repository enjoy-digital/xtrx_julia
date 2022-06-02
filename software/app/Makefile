CFLAGS=-O2 -Wall -g -I../kernel -I../user/liblitepcie -MMD
LDFLAGS=-g
CC=$(CROSS_COMPILE)gcc
AR=ar

CFLAGS += $(shell pkgconf --cflags cuda)

PROGS=litex_xtrx_util

all: $(PROGS)

litex_xtrx_util: litex_xtrx_util.o
	$(CC) $(LDFLAGS) -o $@ $^ -L../user/liblitepcie -lcuda -llitepcie

clean:
	rm -f $(PROGS) *.o *.a *.d *~

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

-include $(wildcard *.d)
