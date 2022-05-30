/*
 * lcd.c
 *
 * Driver for the LCD
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "config.h"
#include "lcd.h"
#include "misc.h"


struct wb_lcd {
	uint32_t csr;
	uint32_t mux;
} __attribute__((packed,aligned(4)));

#define LCD_CSR_BUSY	(1 << 31)
#define LCD_CSR_LEN(l)	(((l)-1) << 16)
#define LCD_CSR_ADDR(a)	(a)

#define LCD_MUX_REQ	(1 << 0)
#define LCD_MUX_STATE	(1 << 1)


static volatile struct wb_lcd * const lcd_regs = (void*)(LCD_BASE);
static volatile uint32_t      * const lcd_mem  = (void*)(LCD_BASE + 0x0800);


static const uint8_t lcd_init_data[] = {
	 3, 0xef, 0x03, 0x80, 0x02,		// ? (undocumented cmd)
	 3, 0xcf, 0x00, 0xc1, 0x30,		// Power control B
	 4, 0xed, 0x64, 0x03, 0x12, 0x81,	// Power on sequence control
	 3, 0xe8, 0x85, 0x00, 0x78,		// Driver timing control A
	 5, 0xcb, 0x39, 0x2c, 0x00, 0x34, 0x02,	// Power control A
	 1, 0xf7, 0x20,				// Pump ratio control
	 2, 0xea, 0x00, 0x00,			// Driver timing control B
	 1, 0xc0, 0x23,				// Power control 1
	 1, 0xc1, 0x10,				// Power control 2
	 2, 0xc5, 0x3e, 0x28,			// VCOM Control 1
	 1, 0xc7, 0x86,				// VCOM Control 2
	 1, 0x3a, 0x55,				// Pixel Format: 16b
	 3, 0xb6, 0x08, 0x82, 0x27,		// Display Function Control
	 1, 0xf2, 0x00,				// 3 Gamma control disable
	 1, 0x26, 0x01,				// Gamma Set
	15, 0xe0, 0x0f, 0x31, 0x2b, 0x0c, 0x0e,	// Positive Gamma Correction
	          0x08, 0x4e, 0xf1, 0x37, 0x07,
	          0x10, 0x03, 0x0e, 0x09, 0x00,
	15, 0xe1, 0x00, 0x0e, 0x14, 0x03, 0x11,	// Negative Gamma Correction
	          0x07, 0x31, 0xc1, 0x48, 0x08,
	          0x0f, 0x0c, 0x31, 0x36, 0x0f,
	 0, 0x11,				// Sleep Out
	 0, 0x29,				// Display ON
	 1, 0x35, 0x00,				// Tearing Effect Line ON
	 1, 0x36, 0x08,				// Memory Access Control
	 4, 0x2a, 0x00, 0x00, 0x00, 0xef,	// Column Address Set
	 4, 0x2b, 0x00, 0x00, 0x01, 0x3f,	// Page Address Set
};


static void
lcd_play(const uint8_t *seq, const unsigned int len)
{
	/* Wait for core to be ready */
	while (lcd_regs->csr & LCD_CSR_BUSY);

	/* Write data */
	if (seq) {
		for (int i=0; i<len; i++)
			lcd_mem[i] = seq[i];
	}

	/* Run it ! */
	lcd_regs->csr =
		LCD_CSR_LEN(len) |
		LCD_CSR_ADDR(0);
}

bool
lcd_init(void)
{
	/* Disable pass-through */
	lcd_regs->mux = 0;

	/* Check LCD is assigned to FPGA */
	gpio_set_dir(MISC_GPIO_LCD_MODE, false);
	if (!gpio_get_val(MISC_GPIO_LCD_MODE))
		return false;

	/* GPIO setup & reset */
		/* Set direction and CS_n=1, RST_n=0 */
	gpio_set_val(MISC_GPIO_LCD_CS_N | MISC_GPIO_LCD_RST_N, MISC_GPIO_LCD_CS_N);
	gpio_set_dir(MISC_GPIO_LCD_CS_N | MISC_GPIO_LCD_RST_N, true);

		/* Wait 1 ms for reset pulse */
	delay_ms(1);

		/* Rise RST_n */
	gpio_set_val(MISC_GPIO_LCD_RST_N, MISC_GPIO_LCD_RST_N);

		/* Wait 120 ms for LCD to complete reset */
	delay_ms(120);

		/* Lower CS_n */
	gpio_set_val(MISC_GPIO_LCD_CS_N, 0);

	/* Play init sequence */
	lcd_play(lcd_init_data, sizeof(lcd_init_data));

	/* Done */
	return true;
}

void
lcd_fill(enum lcd_pattern pat)
{
	#define RGB(r,g,b) ((((r) >> 3) << 11) | (((g) >> 2) << 5) | (((b) >> 3) << 0))
	const int16_t pal[16] = {
		RGB(   0,   0,   0),
		RGB( 170,   0,   0),
		RGB(   0, 170,   0),
		RGB( 170,  85,   0),
		RGB(   0,  85, 170),
		RGB( 170,   0, 170),
		RGB(   0, 170, 170),
		RGB( 170, 170, 170),
		RGB(  85,  85,  85),
		RGB( 255,  85,  85),
		RGB(  85, 255,  85),
		RGB( 255, 255,  85),
		RGB(  85,  85, 155),
		RGB( 255,  85, 255),
		RGB(  85, 255, 255),
		RGB( 255, 255, 255),
	};

	static uint8_t buf[242];

	/* Fill buffer with color bars */
	for (int i=0; i<240; i+=2) {
		int col = (pat >= 16) ? (i / 15) : pat;
		buf[i+2] = pal[col] >> 8;
		buf[i+3] = pal[col] & 0xff;
	}

	/* First write */
	buf[0] = 240;
	buf[1] = 0x2c;

	lcd_play(buf, 242);

	buf[1] = 0x3c;
	lcd_play(buf, 242);

	/* Loop over 319 * 2 chunks */
	for (int i=0; i<319*2; i++)
		lcd_play(NULL, 242);
}

void
lcd_passthrough(bool enable)
{
	lcd_regs->mux = enable ? LCD_MUX_REQ : 0;
}
