# Project config
PROJ := spi_skeleton

PROJ_DEPS := spi_slave no2ice40 no2misc
PROJ_RTL_SRCS := $(addprefix rtl/, \
	sysmgr.v \
)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Toolchain config
NEXTPNR_SEED ?= 15
NEXTPNR_ARGS = --no-promote-globals --seed $(NEXTPNR_SEED)

# Include default rules
include ../../build/project-rules.mk
