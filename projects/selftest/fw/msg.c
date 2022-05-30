/*
 * msg.c
 *
 * Driver for the messaging system over SPI between
 * PicoRV and the ESP32
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "msg.h"


struct wb_msg {
	uint32_t csr;
	uint32_t data;
} __attribute__((packed,aligned(4)));

#define MSG_CSR_REQ_PENDING		(1 << 0)
#define MSG_CSR_RESP_IN_PROGRESS	(1 << 1)
#define MSG_CSR_RESP_START		(1 << 2)
#define MSG_CSR_RESP_STOP		(1 << 3)

#define MSG_DATA_INVALID		(1 << 31)


static volatile struct wb_msg * const msg_regs = (void*)(MSG_BASE);


bool
msg_pending(void)
{
	return !!(msg_regs->csr & MSG_CSR_REQ_PENDING);
}

uint32_t
msg_get_request(void)
{
	uint32_t v = 0, r;

	while (!((r = msg_regs->data) & MSG_DATA_INVALID)) {
		v = (v << 8) | r;
	}

	msg_regs->csr = MSG_CSR_REQ_PENDING;

	return v;
}

void
msg_put_response(uint32_t v)
{
	msg_regs->csr = MSG_CSR_RESP_START;
	msg_regs->data = (v >> 24) & 0xff;
	msg_regs->data = (v >> 16) & 0xff;
	msg_regs->data = (v >>  8) & 0xff;
	msg_regs->data = (v      ) & 0xff;
	msg_regs->csr = MSG_CSR_RESP_STOP;
}
