obj-m = uslm_mod.o
uslm_mod-objs := uslm.o radiotap.o netdev.o station.o proc.o sta_proc.o

SRC := $(shell pwd)
KVERSION := $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KVERSION)/build

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC)

modules:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC)

install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) clean
