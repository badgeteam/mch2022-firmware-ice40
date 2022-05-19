# Project config
PROJ := spi_to_rgb

PROJ_DEPS := spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
	rgbled.v \
	pll.v \
	cycle.v \
)
PROJ_TESTBENCHES = \
	$(NULL)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Toolchain config
YOSYS_SYNTH_ARGS := -abc9 -device u
NEXTPNR_SEED ?= 15
NEXTPNR_ARGS = --no-promote-globals --seed $(NEXTPNR_SEED)

# Include default rules
include ../../build/project-rules.mk


