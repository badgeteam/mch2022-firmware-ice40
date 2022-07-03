# Target config
BOARD ?= mch2022-prod
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/$(BOARD).pcf

# Override default target with our own
all: all_int

# Include default rules
include ../../build/project-rules.mk

# Final target
PROJ_BIN_FINAL ?= $(PROJ).bin
PROJ_BIN_FINAL := $(BUILD_TMP)/$(PROJ_BIN_FINAL)

all_int: $(PROJ_BIN_FINAL)

# MCH2022 programming
PROG_SCRIPT ?= ../../tools/webusb_fpga.py
PROG_EXTRA ?=

prog-fpga: $(PROJ_BIN_FINAL)
	$(PROG_SCRIPT) $< $(PROG_EXTRA)
