# Project config
PROJ := spi_skeleton

PROJ_DEPS := spi_slave no2ice40 no2misc
PROJ_RTL_SRCS := $(addprefix rtl/, \
	sysmgr.v \
)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Toolchain config
NEXTPNR_SEED ?= 15
NEXTPNR_ARGS = --no-promote-globals --seed $(NEXTPNR_SEED)

# Include default rules
include ../_common/build.mk
