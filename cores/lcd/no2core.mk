CORE := lcd

RTL_SRCS_lcd := $(addprefix rtl/, \
	lcd_phy.v \
)

TESTBENCHES_lcd := \
	$(NULL)

include $(NO2BUILD_DIR)/core-magic.mk
