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

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Include default rules
include ../../build/project-rules.mk

# Custom rules
$(BUILD_TMP)/bootloader.hex:
	cp fw/bootloader/bootloader.hex $@
