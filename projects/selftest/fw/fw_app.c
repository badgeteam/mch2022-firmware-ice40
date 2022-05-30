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
// Main
// ---------------------------------------------------------------------------

static void
set_status(int s)
{
	switch (s) {
	case 0:
		/* Running: slow breathe */
		led_color(16, 16, 16);
		led_blink(true, 200, 1000);
		led_breathe(true, 100, 200);
		break;

	case 1:
		/* Done OK: continuous white */
		led_color(16, 16, 16);
		led_blink(false, 0, 0);
		led_breathe(false, 0, 0);
		break;

	case 2:
		/* Done error: agressive primary blink */
		led_color(16, 0, 0);
		led_blink(true, 100, 100);
		led_breathe(false, 0, 0);
		break;
	}
}

void main()
{
	int cmd = 0;

	/* Init console IO */
	console_init();
	puts("Booting selftest image..\n");

	/* LED */
	led_init();
	set_status(0);
	led_state(true);

#if 1
	/* Enable QPI */
	{
		const uint8_t tx_buf[1] = { 0x35 };
		spi_xfer(tx_buf, 1, 0, NULL, 0);
	}

	/* Run memory test */
	set_status( mt_run(0x200000, false) ? 1 : 2 );

	/* LCD init */
	lcd_init();
	lcd_fill(LCD_PATTERN_BARS);
	lcd_passthrough(true);
#endif

	/* Main loop */
	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			printf("Command> ");

		/* Check if there is a message */
		if (msg_pending())
		{
			printf("Message: %08x\n", msg_get_request());
			msg_put_response(0xcafebabe);
		}
		/* Poll for command */
		cmd = getchar_nowait();

		if (cmd >= 0) {
			if (cmd > 32 && cmd < 127)
				putchar(cmd);
			putchar('\r');
			putchar('\n');

			switch (cmd)
			{
			case 'm': {
				printf("Running debug memory test\n");
				mt_run(0x20, true);
				break;
			}

			case 'M': {
				printf("Running full memory test\n");
				set_status(0);
				set_status( mt_run(0x200000, false) ? 1 : 2 );
				break;
			}


			case 'q': {
				const uint8_t tx_buf[1] = { 0x35 };
				spi_xfer(tx_buf, 1, 0, NULL, 0);
				break;
			}

			case 'i': {
				const uint8_t tx_buf[1] = { 0x9f };
				uint8_t rx_buf[8];
				spi_xfer(tx_buf, 1, 3, rx_buf, 8);
				printf("ID: %02x %02x %02x %02x %02x %02x %02x %02x\n",
					rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3],
					rx_buf[4], rx_buf[5], rx_buf[6], rx_buf[7]
				);
				break;
			}

			case 'w': {
				const uint8_t tx_buf[] = { 0x02, 0x00, 0x00, 0x00, 0xba, 0xad, 0xb0, 0x0b };
				spi_xfer(tx_buf, 8, 0, NULL, 0);
				break;
			}
			case 'W': {
				const uint8_t tx_buf[] = { 0x02, 0x00, 0x00, 0x00, 0xca, 0xfe, 0xba, 0xbe };
				spi_xfer(tx_buf, 8, 0, NULL, 0);
				break;
			}
			case 'r': {
				const uint8_t tx_buf[] = { 0x0b, 0x00, 0x00, 0x00 };
				uint8_t rx_buf[4];
				spi_xfer(tx_buf, 4, 1, rx_buf, 4);
				printf("%02x %02x %02x %02x\n",
					rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3]
				);
				break;
			}

			case 'l': {
				static int p = 0;
				printf("%d\n", lcd_init());
				lcd_fill(p);
				p = (p + 1) & 15;
				break;
			}

			case '0':
				led_color(16,  0,  0);
				break;
			case '1':
				led_color( 0, 16,  0);
				break;
			case '2':
				led_color( 0,  0, 16);
				break;

			case 'c':
				printf("%d\n", measure_framerate());
				break;

			default:
				break;
			}
		}
	}
}
