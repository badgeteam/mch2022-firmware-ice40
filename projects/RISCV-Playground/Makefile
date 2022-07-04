# Project config
PROJ := riscv-playground

PROJ_DEPS := spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
)
PROJ_PREREQ = \
      $(BUILD_TMP)/bootloader.hex \
      $(NULL)
PROJ_TOP_SRC := rtl/riscv_playground.v
PROJ_TOP_MOD := riscv_playground

# Toolchain config
YOSYS_SYNTH_ARGS = -dsp -relut -abc9 -no-rw-check
NEXTPNR_ARGS = --ignore-loops

# Default load blinky
PROG_EXTRA := 0xDABBAD00:fw/tinyblinky/tinyblinky.bin

# Include default rules
include ../_common/build.mk

# Custom rules
$(BUILD_TMP)/bootloader.hex:
	cp fw/bootloader/bootloader.hex $@
