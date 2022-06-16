# Project config
PROJ := hello-world

PROJ_DEPS :=
PROJ_RTL_SRCS := $(addprefix rtl/, \
)
PROJ_TOP_SRC := rtl/hello_world.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= mch2022-proto4
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Include default rules
include ../../build/project-rules.mk
