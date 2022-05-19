CORE := spi_slave

RTL_SRCS_spi_slave := $(addprefix rtl/, \
	spi_fast_core.v \
)

TESTBENCHES_spi_slave := \
	spi_fast_core_tb \
	$(NULL)

include $(NO2BUILD_DIR)/core-magic.mk
