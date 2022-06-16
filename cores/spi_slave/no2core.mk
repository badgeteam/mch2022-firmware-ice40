CORE := spi_slave

DEPS_spi_slave := no2misc

RTL_SRCS_spi_slave := $(addprefix rtl/, \
	spi_dev_arb.v \
	spi_dev_core.v \
	spi_dev_ezwb.v \
	spi_dev_fread.v \
	spi_dev_proto.v \
	spi_dev_scmd.v \
	spi_dev_to_wb.v \
)

TESTBENCHES_spi_slave := \
	spi_dev_core_tb \
	spi_dev_to_wb_tb \
	$(NULL)

include $(NO2BUILD_DIR)/core-magic.mk
