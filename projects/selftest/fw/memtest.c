/*
 * memtest.c
 *
 * Driver for the Memory tester core
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "console.h"
#include "memtest.h"


struct wb_memtest {
	uint32_t cmd;
	uint32_t addr;
} __attribute__((packed,aligned(4)));

#define MT_CMD_DUAL		(1 << 18)
#define MT_CMD_CHECK_RST	(1 << 17)
#define MT_CMD_READ		(1 << 16)
#define MT_CMD_WRITE		(0 << 16)
#define MT_CMD_BUF_ADDR(x)	((x) << 8)
#define MT_CMD_LEN(x)		((x) - 1)


static volatile struct wb_memtest * const mt_regs = (void*)(MEMTEST_BASE);
static volatile uint32_t * const mt_mem = (void*)(MEMTEST_BASE + 0x400);


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

bool
mt_run(uint32_t size, bool debug)
{
	uint32_t base;
	bool ok = true;

	/* Fill buffer memory */
	for (int i=0; i<64; i++)
		mt_mem[i] =
			(((i << 2) + 0) << 24) |
			(((i << 2) + 1) << 16) |
			(((i << 2) + 2) <<  8) |
			(((i << 2) + 3) <<  0) ;

	/* Iterate over requested address space */
	for (base=0; base<size; base+=32)
	{
		// Issue write
		mt_cmd_write(base, 0, 32);
	}

	/* Iterate over requested address space */
	for (base=0; base<size; base+=32)
	{
		/* Issue read */
		mt_cmd_read(base, 0, 32, true);

		/* Check result */
		if (!(mt_regs->cmd & 2)) {
			printf("Error @ %08x\n", base);
			ok = false;

			if (debug) {
				for (int i=0; i<32; i++)
					printf("%02x %08x\n", i, mt_mem[i]);
			}
		}
	}

	/* Return overall result */
	return ok;
}
