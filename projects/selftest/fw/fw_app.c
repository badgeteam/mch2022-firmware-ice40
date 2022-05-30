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
#include "led.h"
#include "mini-printf.h"

#include "config.h"


static void
wait_ms(int ms)
{
	while (ms--) {
		// Complete guess ...
		for (int i=0; i<2000; i++)
			asm("nop");
	}
}


// ---------------------------------------------------------------------------
// QPI driver
// ---------------------------------------------------------------------------

struct wb_qpi {
	union {
		struct {
			uint32_t csr;
			uint32_t _rsvd0;
			uint32_t _rsvd1;
			uint32_t rf;
		};
		uint32_t cmd[0];
	};
} __attribute__((packed,aligned(4)));

static volatile struct wb_qpi * const qpi_regs = (void*)(QPI_BASE);


static void
_qpi_begin(int cs)
{
	// Request external control
	qpi_regs->csr = 0x00000004 | (cs << 4);
	qpi_regs->csr = 0x00000002 | (cs << 4);

}

static void
_qpi_end(void)
{
	// Release external control
	qpi_regs->csr = 0x00000004;
}

static void
qpi_xfer(const uint8_t cmd,
         const uint8_t *tx_buf, const unsigned int tx_len,
                                const unsigned int dummy_len,
               uint8_t *rx_buf, const unsigned int rx_len)
{
	// FIXME
}

static void
spi_xfer(const uint8_t *tx_buf, const unsigned int tx_len,
                                const unsigned int dummy_len,
               uint8_t *rx_buf, const unsigned int rx_len)
{
	uint8_t *buf;
	int l, o;

	// Prepare buffer;
	l = tx_len + dummy_len + rx_len;
	buf = alloca((l+3)&~3);

	memcpy(buf, tx_buf, tx_len);
	memset(buf+tx_len, 0, l-tx_len);

	// Start transaction
	_qpi_begin(0);

	// Run
	for (o=0; l>0; l-=4,o+=4)
	{
		// Word and command
		uint32_t w =
			(buf[o+0] << 24) |
			(buf[o+1] << 16) |
			(buf[o+2] <<  8) |
			(buf[o+3] <<  0);

		int c = (l >= 4) ? 0x13 : (0x10 + l - 1);
		int s = (l >= 4) ? 0 : (8*(4-l));

		// Issue
		qpi_regs->cmd[c] = w;
		uint32_t wr = qpi_regs->rf;
#if 0
		printf("%08x %08x\n", w, wr);
#endif

		// Get RX
		wr <<= s;

		buf[o+0] = wr >> 24;
		buf[o+1] = wr >> 16;
		buf[o+2] = wr >>  8;
		buf[o+3] = wr >>  0;
	}

	// End transaction
	_qpi_end();

	// Return RX part
	if (rx_len)
		memcpy(rx_buf, buf+tx_len+dummy_len, rx_len);
}


// ---------------------------------------------------------------------------
// Memory tester
// ---------------------------------------------------------------------------

struct wb_memtest {
	uint32_t cmd;
	uint32_t addr;
} __attribute__((packed,aligned(4)));

static volatile struct wb_memtest * const mt_regs = (void*)(MEMTEST_BASE);
static volatile uint32_t * const mt_mem = (void*)(MEMTEST_BASE + 0x400);

#define MT_CMD_DUAL		(1 << 18)
#define MT_CMD_CHECK_RST	(1 << 17)
#define MT_CMD_READ		(1 << 16)
#define MT_CMD_WRITE		(0 << 16)
#define MT_CMD_BUF_ADDR(x)	((x) << 8)
#define MT_CMD_LEN(x)		((x) - 1)

static void
mt_cmd_write(uint32_t ram_addr, uint32_t buf_addr, uint32_t len)
{
	mt_regs->addr = ram_addr;
	mt_regs->cmd =
		MT_CMD_WRITE |
		MT_CMD_BUF_ADDR(buf_addr) |
		MT_CMD_LEN(len);

	while (!(mt_regs->cmd & 1));
}

static void
mt_cmd_read(uint32_t ram_addr, uint32_t buf_addr, uint32_t len, bool check_reset)
{
	mt_regs->addr = ram_addr;
	mt_regs->cmd =
		(check_reset ? MT_CMD_CHECK_RST : 0) |
		MT_CMD_READ |
		MT_CMD_BUF_ADDR(buf_addr) |
		MT_CMD_LEN(len);

	while (!(mt_regs->cmd & 1));
}

static bool
mt_run(uint32_t size, bool debug)
{
	uint32_t base;
	bool ok = true;

	// Fill memory
	for (int i=0; i<64; i++)
		mt_mem[i] =
			(((i << 2) + 0) << 24) |
			(((i << 2) + 1) << 16) |
			(((i << 2) + 2) <<  8) |
			(((i << 2) + 3) <<  0) ;

	// Iterate over 8 Mbytes address space
	for (base=0; base<size; base+=32)
	{
		// Issue write
		mt_cmd_write(base, 0, 32);
	}

	// Iterate over 8 Mbytes address space
	for (base=0; base<size; base+=32)
	{
		// Issue read
		mt_cmd_read(base, 0, 32, true);

		// Check result
		if (!(mt_regs->cmd & 2)) {
			printf("Error @ %08x\n", base);
			ok = false;

			if (debug) {
				for (int i=0; i<32; i++)
					printf("%02x %08x\n", i, mt_mem[i]);
			}
		}
	}

	// Return overall result
	return ok;
}


// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

struct wb_misc {
	struct {
		uint32_t oe;
		uint32_t out;
		uint32_t in;
		uint32_t _rsvd;
	} gpio;
	struct {
		uint32_t cycles;
		uint32_t frames;
	} cnt;
} __attribute__((packed,aligned(4)));

static volatile struct wb_misc * const misc_regs = (void*)(MISC_BASE);

#define MISC_GPIO_IRQ_N	(1 << 11)
#define MISC_GPIO_LCD_CS_N	(1 << 10)
#define MISC_GPIO_LCD_MODE	(1 <<  9)
#define MISC_GPIO_LCD_RST_N	(1 <<  8)
#define MISC_GPIO_PMOD(n)	(1 << (n))


// ---------------------------------------------------------------------------
// LCD
// ---------------------------------------------------------------------------

struct wb_lcd {
	uint32_t csr;
	uint32_t mux;
} __attribute__((packed,aligned(4)));

static volatile struct wb_lcd * const lcd_regs = (void*)(LCD_BASE);
static volatile uint32_t      * const lcd_mem  = (void*)(LCD_BASE + 0x0800);

#define LCD_CSR_BUSY	(1 << 31)
#define LCD_CSR_LEN(l)	(((l)-1) << 16)
#define LCD_CSR_ADDR(a)	(a)

#define LCD_MUX_REQ	(1 << 0)
#define LCD_MUX_STATE	(1 << 1)


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
	// Wait for core to be ready
	while (lcd_regs->csr & LCD_CSR_BUSY);

	// Write data
	if (seq) {
		for (int i=0; i<len; i++)
			lcd_mem[i] = seq[i];
	}

	// Run it !
	lcd_regs->csr =
		LCD_CSR_LEN(len) |
		LCD_CSR_ADDR(0);
}

static void
lcd_init(void)
{
	// GPIO setup & reset
	misc_regs->gpio.out &= ~MISC_GPIO_LCD_RST_N;
	misc_regs->gpio.out |=  MISC_GPIO_LCD_CS_N | MISC_GPIO_LCD_MODE;

	misc_regs->gpio.oe  |=  MISC_GPIO_LCD_CS_N | MISC_GPIO_LCD_MODE | MISC_GPIO_LCD_RST_N;

	wait_ms(1);

	misc_regs->gpio.out |=  MISC_GPIO_LCD_CS_N | MISC_GPIO_LCD_MODE | MISC_GPIO_LCD_RST_N;

	wait_ms(120);

	misc_regs->gpio.out &= ~MISC_GPIO_LCD_CS_N;

	// Play init sequence
	lcd_play(lcd_init_data, sizeof(lcd_init_data));
}

static void
lcd_color_screen(void)
{
	static uint8_t buf[242];

	/* Fill buffer with color bars */
	for (int i=0; i<240; i+=2) {
		buf[i+2] = i;
		buf[i+3] = i;
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


// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

struct wb_msg {
	uint32_t csr;
	uint32_t data;
} __attribute__((packed,aligned(4)));

static volatile struct wb_msg * const msg_regs = (void*)(MSG_BASE);

#define MSG_CSR_REQ_PENDING		(1 << 0)
#define MSG_CSR_RESP_IN_PROGRESS	(1 << 1)
#define MSG_CSR_RESP_START		(1 << 2)
#define MSG_CSR_RESP_STOP		(1 << 3)

#define MSG_DATA_INVALID		(1 << 31)


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
	lcd_color_screen();
#endif

	/* Main loop */
	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			printf("Command> ");

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
				lcd_init();
				lcd_color_screen();
				break;
			}

			default:
				break;
			}
		}
	}
}
