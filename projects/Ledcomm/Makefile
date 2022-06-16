# Project config
PROJ := ledcomm

PROJ_DEPS :=
PROJ_RTL_SRCS := $(addprefix rtl/, \
	ledcommflow.v \
	uart-fifo.v \
)
PROJ_TOP_SRC := rtl/ledcomm.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Include default rules
include ../../build/project-rules.mk
