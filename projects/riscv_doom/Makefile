# Project config
PROJ = riscv_doom

PROJ_DEPS := no2misc no2ice40 no2qpimem no2memcache lcd spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
	vid_top.v \
	vid_palette.v \
	vid_framebuf.v \
	soc_bram.v \
	spi_link.v \
	sysmgr.v \
	VexRiscv.v \
)
PROJ_TESTBENCHES := \
	vid_top_tb
PROJ_PREREQ = \
	$(BUILD_TMP)/boot.hex
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

SEED ?= 4

# Toolchain config
YOSYS_SYNTH_ARGS = -dffe_min_ce_use 4 -abc9 -device u -dsp
NEXTPNR_ARGS = --no-promote-globals --pre-pack data/clocks.py --pre-place $(CORE_no2ice40_DIR)/sw/serdes-nextpnr-place.py --seed $(SEED)
NEXTPNR_ARGS += --timing-allow-fail

# Include default rules
include ../../build/project-rules.mk

# Custom rules
$(BUILD_TMP)/boot.hex:
	icebram -g -s 0 32 256 > $@

fw_boot/boot.hex:
	make -C fw_boot boot.hex

$(BUILD_TMP)/$(PROJ)-sw.asc: $(BUILD_TMP)/$(PROJ).asc $(BUILD_TMP)/boot.hex fw_boot/boot.hex
	cat $(BUILD_TMP)/$(PROJ).asc | icebram $(BUILD_TMP)/boot.hex fw_boot/boot.hex > $@

PROG_DEV ?= /dev/ttyACM0

prog-fpga: $(BUILD_TMP)/$(PROJ)-sw.bin
ifeq ($(PROG_SW),)
	uart_fpga.py $(PROG_DEV) $<
else
	uart_fpga.py $(PROG_DEV) $< 0x355beaa3:$(PROG_SW)
endif
