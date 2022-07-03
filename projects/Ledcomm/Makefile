# Project config
PROJ := ledcomm

PROJ_DEPS :=
PROJ_RTL_SRCS := $(addprefix rtl/, \
	ledcommflow.v \
	uart-fifo.v \
)
PROJ_TOP_SRC := rtl/ledcomm.v
PROJ_TOP_MOD := top

# Include default rules
include ../_common/build.mk
