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
YOSYS_ARGS = -q
YOSYS_SYNTH_ARGS = -abc2 -dsp -relut -no-rw-check
NEXTPNR_ARGS = --ignore-loops

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Include default rules
include ../_common/build.mk

# Custom rules
$(BUILD_TMP)/iceimage.hex:
	cp rtl/iceimage.hex $@
