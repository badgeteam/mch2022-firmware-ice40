/*
 * fw_app.c
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <alloca.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "console.h"
#include "lcd.h"
#include "led.h"
#include "memtest.h"
#include "mini-printf.h"
#include "misc.h"
#include "msg.h"
#include "qpi.h"


// ---------------------------------------------------------------------------
// LED status reporting
// ---------------------------------------------------------------------------

enum led_status {
	STATUS_PREBOOT = 0,
	STATUS_RUN     = 1,
	STATUS_GOOD    = 2,
	STATUS_BAD     = 3
};

static bool
led_set_status(enum led_status s)
{
	switch (s) {
	case STATUS_PREBOOT:
		/* Pre-boot continuous blue */
		led_color(4, 4, 24);
		led_blink(false, 0, 0);
		led_breathe(false, 0, 0);
		break;

	case STATUS_RUN:
		/* Running: slow breathe blue */
		led_color(4, 4, 24);
		led_blink(true, 200, 1000);
		led_breathe(true, 100, 200);
		break;

	case STATUS_GOOD:
		/* Good: continuous green */
		led_color(0, 16, 0);
		led_blink(false, 0, 0);
		led_breathe(false, 0, 0);
		break;

	case STATUS_BAD:
		/* Bad: agressive red blink */
		led_color(16, 0, 0);
		led_blink(true, 100, 100);
		led_breathe(false, 0, 0);
		break;

	default:
		return false;
	}

	return true;
}


// ---------------------------------------------------------------------------
// Test routines
// ---------------------------------------------------------------------------

#define SOC_CMD_PING			0x00
#define SOC_CMD_PING_PARAM		0xc0ffee
#define SOC_CMD_PING_RESP		0xcafebabe

#define SOC_CMD_RGB_STATE_SET		0x10
#define SOC_CMD_IRQN_SET		0x11
#define SOC_CMD_LCD_RGB_CYCLE_SET	0x12
#define SOC_CMD_PMOD_CYCLE_SET		0x13
#define SOC_CMD_LCD_PASSTHROUGH_SET	0x14

#define SOC_CMD_PSRAM_TEST		0x20
#define SOC_CMD_UART_LOOPBACK_TEST	0x21
#define SOC_CMD_PMOD_OPEN_TEST		0x22
#define SOC_CMD_PMOD_PLUG_TEST		0x23
#define SOC_CMD_LCD_INIT_TEST		0x24

#define SOC_CMD_LCD_CHECK_MODE		0x30

#define SOC_RESP_OK		0x00000000
#define SOC_RESP_ERR_FAIL	0xffbadbad
#define SOC_RESP_ERR_INVAL	0xdeaddead
#define SOC_RESP_ERR(n)		(0xff000000 | (n))


static enum led_status g_led = STATUS_PREBOOT;
static int g_cycle_lcd_rgb = -1;
static int g_cycle_pmod = -1;


static uint32_t
h_cmd_ping(uint32_t param)
{
	if (param == SOC_CMD_PING_PARAM)
		return 0xcafebabe;
	else
		return SOC_RESP_ERR_FAIL;
}

static uint32_t
h_cmd_rgb_state_set(uint32_t param)
{
	if (led_set_status(param)) {
		g_led = param;
		return SOC_RESP_OK;
	} else {
		return SOC_RESP_ERR_FAIL;
	}
}

static uint32_t
h_cmd_irqn_set(uint32_t param)
{
	if (param) {
		/* Assert INT_n (i.e. force low !) */
		gpio_set_val(MISC_GPIO_IRQ_N, 0);
		gpio_set_dir(MISC_GPIO_IRQ_N, true);
	} else {
		/* Release INT_n (Hi-Z) */
		gpio_set_dir(MISC_GPIO_IRQ_N, false);
	}

	return SOC_RESP_OK;
}

static uint32_t
h_cmd_lcd_rgb_cycle_set(uint32_t param)
{
	/* Start cycle ... */
	if (param) {
		/* Enable cycling */
		g_cycle_lcd_rgb = 0;
	}

	/* ... or Stop cycle */
	else {
		/* Restore LED */
		led_set_status(g_led);

		/* Restore LCD */
		lcd_fill(LCD_PATTERN_BARS);

		/* Stop cycling */
		g_cycle_lcd_rgb = -1;
	}

	/* Done */
	return SOC_RESP_OK;
}

static uint32_t
h_cmd_pmod_cycle_set(uint32_t param)
{
	/* Start cycle ... */
	if (param) {
		/* Set PMOD to Output */
		gpio_set_val(MISC_GPIO_PMOD_ALL, 0);
		gpio_set_dir(MISC_GPIO_PMOD_ALL, true);

		/* Enable cycling */
		g_cycle_pmod = 0;
	}

	/* ... or Stop cycle */
	else {
		/* Set PMOD to Hi-Z */
		gpio_set_dir(MISC_GPIO_PMOD_ALL, false);

		/* Stop cycling */
		g_cycle_pmod = -1;
	}

	/* Done */
	return SOC_RESP_OK;
}

static uint32_t
h_cmd_lcd_passthrough_set(uint32_t param)
{
	lcd_passthrough(param != 0);
	return SOC_RESP_OK;
}

static uint32_t
h_cmd_psram_test(uint32_t param)
{
	/* Enable QPI */
	const uint8_t tx_buf[1] = { 0x35 };
	spi_xfer(tx_buf, 1, 0, NULL, 0);

	/* Run full test */
	return mt_run(0x200000, false) ? SOC_RESP_OK : SOC_RESP_ERR_FAIL;
}

static uint32_t
h_cmd_uart_loopback_test(uint32_t param)
{
	uint8_t buf[128];
	bool ok = true;
	int i;

	/* Flush FIFO */
	for (i = 0; i < 1024; i++)
		if (getchar_nowait() < 0)
			break;

	if (i == 1024)
		return SOC_RESP_ERR(1);

	/* Generate random sequence */
	buf[0] = 1;
	for (i = 1; i < 128; i++)
		buf[i] = (buf[i-1] << 1) ^ ((buf[i-1] & 0x80) ? 0x1d : 0x00);

	/* Send it */
	for (i = 0; i < 128; i++)
		putchar(buf[i] ^ 0xa5);

	/* Wait for it to go through */
	delay_ms(10);

	/* Validate response */
	for (i = 0; i < 128; i++)
		ok &= (buf[i] == getchar_nowait());

	/* Return */
	return ok ? SOC_RESP_OK : SOC_RESP_ERR_FAIL;
}

static uint32_t
h_cmd_pmod_open_test(uint32_t param)
{
	uint32_t err_mask = 0;

	/* Test each pin */
	for (int i=0; i<8; i++)
	{
		uint32_t mask = MISC_GPIO_PMOD(i);

		/* Set all pins to output '1' */
		gpio_set_val(MISC_GPIO_PMOD_ALL, MISC_GPIO_PMOD_ALL);
		gpio_set_dir(MISC_GPIO_PMOD_ALL, true);

		/* Wait for charge */
		delay_ms(1);

		/* Set all pins to Hi-Z */
		gpio_set_dir(MISC_GPIO_PMOD_ALL, false);

		/* Wait to settle */
		delay_ms(1);

		/* Check everything is '1' */
		err_mask |= gpio_get_val(MISC_GPIO_PMOD_ALL) ^ MISC_GPIO_PMOD_ALL;

		/* Set one pin to output 0 */
		gpio_set_dir(mask, true);
		gpio_set_val(mask, 0);

		/* Wait to settle */
		delay_ms(1);

		/* Check everything is '1' except for the pin */
		err_mask |= gpio_get_val(MISC_GPIO_PMOD_ALL) ^ MISC_GPIO_PMOD_ALL ^ mask;
	}

	/* Set all pins to Hi-Z */
	gpio_set_dir(MISC_GPIO_PMOD_ALL, false);

	/* Return results */
	if (err_mask)
		return SOC_RESP_ERR(err_mask);
	else
		return SOC_RESP_OK;
}

static int
_maj(uint32_t v)
{
	int cnt = 0;
	for (int i=0; i<8; i++) {
		cnt += (v & 1);
		v >>= 1;
	}
	return cnt > 4;
}

static uint32_t
h_cmd_pmod_plug_test(uint32_t param)
{
	uint32_t err_mask = 0;

	/* Test each pin */
	for (int i=0; i<8; i++)
	{
		uint32_t mask = MISC_GPIO_PMOD(i);

		/* Set all pins to Hi-Z */
		gpio_set_dir(MISC_GPIO_PMOD_ALL, false);

		/* Set selected pin to 0 */
		gpio_set_val(mask, 0);
		gpio_set_dir(mask, true);

		/* Wait to settle */
		delay_ms(1);

		/* Check everything is '0' */
		if (_maj(gpio_get_val(MISC_GPIO_PMOD_ALL)) != 0)
			err_mask |= mask;

		/* Set selected pin to 1 */
		gpio_set_val(mask, mask);
		gpio_set_dir(mask, true);

		/* Wait to settle */
		delay_ms(1);

		/* Check everything is '1' */
		if (_maj(gpio_get_val(MISC_GPIO_PMOD_ALL)) != 1)
			err_mask |= mask;
	}

	/* Set all pins to Hi-Z */
	gpio_set_dir(MISC_GPIO_PMOD_ALL, false);

	/* Return results */
	if (err_mask)
		return SOC_RESP_ERR(err_mask);
	else
		return SOC_RESP_OK;
}

static uint32_t
h_cmd_lcd_init_test(uint32_t param)
{
	int f;

	/* Check LCD is assigned to FPGA */
	gpio_set_dir(MISC_GPIO_LCD_MODE, false);
	if (!gpio_get_val(MISC_GPIO_LCD_MODE))
		return SOC_RESP_ERR(1);

	/* Force LCD to reset */
	lcd_keep_reset();

	/* Check there is no fmark */
	f = measure_framerate();

	if (f != 0)
		return SOC_RESP_ERR(4);

	/* Run init sequence */
	lcd_init();

	/* Fill LCD with pattern */
	lcd_fill(LCD_PATTERN_BARS);

	/* Check reported frame rate is within bound */
	f = measure_framerate();

	if (f == 0)
		return SOC_RESP_ERR(5);
	else if (f < 65)
		return SOC_RESP_ERR(6);
	else if (f > 85)
		return SOC_RESP_ERR(7);

	return SOC_RESP_OK;
}

static uint32_t
h_cmd_lcd_check_mode(uint32_t param)
{
	if ((!!gpio_get_val(MISC_GPIO_LCD_MODE)) != (!!param))
		return SOC_RESP_ERR_FAIL;

	return SOC_RESP_OK;
}


typedef uint32_t (*msg_handler_t)(uint32_t param);

const static struct {
	uint8_t cmd;
	msg_handler_t fn;
} handlers[] = {
	{ SOC_CMD_PING,			h_cmd_ping },
	{ SOC_CMD_RGB_STATE_SET,	h_cmd_rgb_state_set },
	{ SOC_CMD_IRQN_SET,		h_cmd_irqn_set },
	{ SOC_CMD_LCD_RGB_CYCLE_SET,	h_cmd_lcd_rgb_cycle_set },
	{ SOC_CMD_PMOD_CYCLE_SET,	h_cmd_pmod_cycle_set },
	{ SOC_CMD_LCD_PASSTHROUGH_SET,	h_cmd_lcd_passthrough_set },
	{ SOC_CMD_PSRAM_TEST,		h_cmd_psram_test },
	{ SOC_CMD_UART_LOOPBACK_TEST,	h_cmd_uart_loopback_test },
	{ SOC_CMD_PMOD_OPEN_TEST,	h_cmd_pmod_open_test },
	{ SOC_CMD_PMOD_PLUG_TEST,	h_cmd_pmod_plug_test },
	{ SOC_CMD_LCD_INIT_TEST,	h_cmd_lcd_init_test },
	{ SOC_CMD_LCD_CHECK_MODE,       h_cmd_lcd_check_mode },
	{ 0, NULL }	/* guard */
};

static void
handle_message(void)
{
	/* Get message */
	uint32_t msg = msg_get_request();

	uint8_t  cmd = msg >> 24;
	uint32_t param = msg & 0xffffff;

	/* Find handler */
	for (int i=0; handlers[i].fn; i++)
	{
		if (handlers[i].cmd == cmd)
		{
			msg_put_response(handlers[i].fn(param));
			return;
		}
	}

	/* No handlers found */
	msg_put_response(SOC_RESP_ERR_INVAL);
}


// ---------------------------------------------------------------------------
// Cycles
// ---------------------------------------------------------------------------

static void
cycle_lcd_rgb(void)
{
	enum lcd_pattern lp;
	uint8_t r,g,b;

	/* Active ? */
	if (g_cycle_lcd_rgb < 0)
		return;

	/* Select color */
	switch (g_cycle_lcd_rgb) {
	case 0:
		lp = LCD_PATTERN_RED;
		r  = 16;
		g  = 0;
		b  = 0;
		break;

	case 1:
		lp = LCD_PATTERN_GREEN;
		r  = 0;
		g  = 16;
		b  = 0;
		break;

	case 2:
		lp = LCD_PATTERN_BLUE;
		r  = 0;
		g  = 0;
		b  = 16;
		break;
	}

	/* Set RGB */
	led_color(r, g, b);
	led_blink(false, 0, 0);
	led_breathe(false, 0, 0);

	/* Fill LCD */
	lcd_fill(lp);

	/* Next color */
	if (++g_cycle_lcd_rgb > 2)
		g_cycle_lcd_rgb = 0;
}

static void
cycle_pmod(void)
{
	/* Active ? */
	if (g_cycle_pmod < 0)
		return;

	/* Set value */
	gpio_set_val(MISC_GPIO_PMOD_ALL, MISC_GPIO_PMOD(g_cycle_pmod));

	/* Next pin */
	g_cycle_pmod = (g_cycle_pmod + 1) & 7;
}


// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main()
{
	uint32_t t;

	/* Init console IO */
	console_init();
	puts("MCH2022 iCE40 selftest\n");

	/* LED */
	led_init();
	led_set_status(STATUS_PREBOOT);
	led_state(true);

	/* Initial time */
	t = cycles_now();

	/* Main loop */
	while (1) {
		/* Poll for message */
		if (msg_pending())
			handle_message();

		/* Time to update cycles ? */
		if (cycles_elapsed_ms(t, 500)) {
			/* Update time ref */
			t = cycles_now();

			/* Run cycles */
			cycle_lcd_rgb();
			cycle_pmod();
		}

		/* Debug interactive console */
#if 0
		int cmd = getchar_nowait();

		switch (cmd) {
		case -1:
			break;

		case 'e':
			printf("%08x\n", h_cmd_ping(SOC_CMD_PING_PARAM));
			break;

		case '0':
			printf("%08x\n", h_cmd_rgb_state_set(0));
			break;

		case '1':
			printf("%08x\n", h_cmd_rgb_state_set(1));
			break;

		case '2':
			printf("%08x\n", h_cmd_rgb_state_set(2));
			break;

		case '3':
			printf("%08x\n", h_cmd_rgb_state_set(3));
			break;

		case 'i':
			printf("%08x\n", h_cmd_irqn_set(0));
			break;

		case 'I':
			printf("%08x\n", h_cmd_irqn_set(1));
			break;

		case 'k':
			printf("%08x\n", h_cmd_lcd_rgb_cycle_set(0));
			break;

		case 'K':
			printf("%08x\n", h_cmd_lcd_rgb_cycle_set(1));
			break;

		case 'p':
			printf("%08x\n", h_cmd_pmod_cycle_set(0));
			break;

		case 'P':
			printf("%08x\n", h_cmd_pmod_cycle_set(1));
			break;

		case 't':
			printf("%08x\n", h_cmd_lcd_passthrough_set(0));
			break;

		case 'T':
			printf("%08x\n", h_cmd_lcd_passthrough_set(1));
			break;

		case 'r':
			printf("%08x\n", h_cmd_psram_test(0));
			break;

		case 'u':
			printf("%08x\n", h_cmd_uart_loopback_test(0));
			break;

		case 'o':
			printf("%08x\n", h_cmd_pmod_open_test(0));
			break;

		case 's':
			printf("%08x\n", h_cmd_pmod_plug_test(0));
			break;

		case 'l':
			printf("%08x\n", h_cmd_lcd_init_test(0));
			break;
		}
#endif
	}
}
