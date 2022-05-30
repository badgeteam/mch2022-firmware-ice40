BOARD ?= mch2022-proto4
CROSS ?= riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs -D$(BOARD_DEFINE) -I.

HEADERS_common=\
	config.h \
	console.h \
	lcd.h \
	led.h \
	memtest.h \
	mini-printf.h \
	misc.h \
	msg.h \
	qpi.h \
	$(NULL)

SOURCES_common=\
	start.S \
	console.c \
	lcd.c \
	led.c \
	memtest.c \
	mini-printf.c  \
	misc.c \
	msg.c \
	qpi.c \
	$(NULL)

HEADERS_app=\
	$(NULL)

SOURCES_app=\
	fw_app.c \
	$(NULL)


all: fw_app.hex

fw_app.elf: lnk-app.lds $(HEADERS_app) $(SOURCES_app) $(HEADERS_common) $(SOURCES_common)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES_common) $(SOURCES_app)

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin
	hexdump -ve '1/4 "%08x\n"' $< > $@

clean:
	rm -f *.bin *.hex *.elf *.o *.gen.h

.PHONY: prog clean
