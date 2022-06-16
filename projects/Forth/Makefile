# Project config
PROJ := forth

PROJ_DEPS := spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
	common-verilog/celement.v \
	common-verilog/cordic.v \
	common-verilog/DEFF.v \
	common-verilog/delayline.v \
	common-verilog/j1-universal-16kb-quickstore.v \
	common-verilog/ledcommflow.v \
	common-verilog/ledcommsimple.v \
	common-verilog/omsp_sync_cell.v \
	common-verilog/ringoscillator.v \
	common-verilog/sqrt.v \
	common-verilog/stack2.v \
	common-verilog/stack3.v \
	common-verilog/uart-fifo.v \
)
PROJ_PREREQ = \
      $(BUILD_TMP)/iceimage.hex \
      $(NULL)
PROJ_TOP_SRC := rtl/mch2022.v
PROJ_TOP_MOD := top

# Toolchain config
YOSYS_SYNTH_ARGS = -abc9 -device u -dffe_min_ce_use 4 -dsp -no-rw-check
NEXTPNR_ARGS = --no-promote-globals --ignore-loops

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Include default rules
include ../../build/project-rules.mk

# Custom rules
$(BUILD_TMP)/iceimage.hex:
	cp rtl/iceimage.hex $@
