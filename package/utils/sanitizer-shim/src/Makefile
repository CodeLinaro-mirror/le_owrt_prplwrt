# SPDX-License-Identifier: GPL-2.0-only
# Built by the OpenWrt package Makefile and by the host test.
# The shim must stay free of sanitizer instrumentation.
CC ?= cc
CFLAGS ?= -O2
LIB = libsanitizer-shim.so

all: $(LIB)

$(LIB): sanitizer-shim.c $(wildcard shim-config.h)
	$(CC) $(CFLAGS) $(CPPFLAGS) -Wall -Wextra -fPIC -fvisibility=hidden \
		-fno-sanitize=all -shared -Wl,-soname,$(LIB) \
		$(LDFLAGS) -o $@ $< -pthread

clean:
	rm -f $(LIB)

.PHONY: all clean
