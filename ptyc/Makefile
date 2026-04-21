# ptyc — PTY-spawn helper for clide.
#
# Single source file, libc only. No configure step. Builds everywhere a
# POSIX-y C compiler + unix sockets exist.

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Wpedantic -Werror -O2 -D_FORTIFY_SOURCE=2
LDFLAGS ?=

BIN     := bin/ptyc

.PHONY: all
all: $(BIN)

$(BIN): ptyc.c | bin
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

bin:
	mkdir -p bin

.PHONY: test
test: $(BIN)
	./test_ptyc.sh

.PHONY: clean
clean:
	rm -rf bin *.o
