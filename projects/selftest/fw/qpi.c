/*
 * qpi.c
 *
 * QPI driver
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <alloca.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "config.h"
#include "qpi.h"


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
	/* Request external control */
	qpi_regs->csr = 0x00000004 | (cs << 4);
	qpi_regs->csr = 0x00000002 | (cs << 4);
}

static void
_qpi_end(void)
{
	/* Release external control */
	qpi_regs->csr = 0x00000004;
}

void
qpi_xfer(const uint8_t cmd,
         const uint8_t *tx_buf, const unsigned int tx_len,
                                const unsigned int dummy_len,
               uint8_t *rx_buf, const unsigned int rx_len)
{
	/* FIXME */
}

void
spi_xfer(const uint8_t *tx_buf, const unsigned int tx_len,
                                const unsigned int dummy_len,
               uint8_t *rx_buf, const unsigned int rx_len)
{
	uint8_t *buf;
	int l, o;

	/* Prepare buffer */
	l = tx_len + dummy_len + rx_len;
	buf = alloca((l+3)&~3);

	memcpy(buf, tx_buf, tx_len);
	memset(buf+tx_len, 0, l-tx_len);

	/* Start transaction */
	_qpi_begin(0);

	/* Run */
	for (o=0; l>0; l-=4,o+=4)
	{
		/* Word and command */
		uint32_t w =
			(buf[o+0] << 24) |
			(buf[o+1] << 16) |
			(buf[o+2] <<  8) |
			(buf[o+3] <<  0);

		int c = (l >= 4) ? 0x13 : (0x10 + l - 1);
		int s = (l >= 4) ? 0 : (8*(4-l));

		/* Issue */
		qpi_regs->cmd[c] = w;
		uint32_t wr = qpi_regs->rf;

		/* Get RX */
		wr <<= s;

		buf[o+0] = wr >> 24;
		buf[o+1] = wr >> 16;
		buf[o+2] = wr >>  8;
		buf[o+3] = wr >>  0;
	}

	/* End transaction */
	_qpi_end();

	/* Return RX part */
	if (rx_len)
		memcpy(rx_buf, buf+tx_len+dummy_len, rx_len);
}
