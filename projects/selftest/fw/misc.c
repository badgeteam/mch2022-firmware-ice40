/*
 * misc.c
 *
 * Driver for the "Misc" peripheral of the SoC, grouping
 * various random bits of hardware too small to have
 * dedicated peripherals.
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "misc.h"


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


void
gpio_set_dir(uint32_t pins, bool oe)
{
	misc_regs->gpio.oe = (misc_regs->gpio.oe & ~pins) | (oe ? pins : 0);
}

void
gpio_set_val(uint32_t pins, uint32_t val)
{
	misc_regs->gpio.out = (misc_regs->gpio.out & ~pins) | (val & pins);
}

void
gpio_set(uint32_t pins)
{
	misc_regs->gpio.out |= pins;
}

void
gpio_clear(uint32_t pins)
{
	misc_regs->gpio.out &= ~pins;
}

uint32_t
gpio_get_val(uint32_t pins)
{
	return misc_regs->gpio.in & pins;
}


void
delay_us(unsigned int us)
{
	unsigned int cycles = (us * (SYS_CLK_HZ / 1000)) / 1000;
	uint32_t start = misc_regs->cnt.cycles;

	while ((misc_regs->cnt.cycles - start) < cycles)
		asm("nop");
}

void
delay_ms(unsigned int ms)
{
	unsigned int cycles = (ms * (SYS_CLK_HZ / 1000));
	uint32_t start = misc_regs->cnt.cycles;

	while ((misc_regs->cnt.cycles - start) < cycles)
		asm("nop");
}


uint32_t
cycles_now(void)
{
	return misc_regs->cnt.cycles;
}

bool
cycles_elapsed_ms(uint32_t ref, unsigned int ms)
{
	unsigned int cycles = (ms * (SYS_CLK_HZ / 1000));
	return ((misc_regs->cnt.cycles - ref) >= cycles);
}


int
measure_framerate(void)
{
	uint32_t pv; /* Previous frames value */
	uint32_t to; /* Cycles timeout */
	uint32_t cycles[2];

	/* Grab cycle counter at two distinct frame transitions */
	for (int i=0; i<2; i++) {
		to = misc_regs->cnt.cycles;
		pv = misc_regs->cnt.frames;
		while (pv == misc_regs->cnt.frames)
			if ((misc_regs->cnt.cycles - to) > (SYS_CLK_HZ / 10))
				return 0;
		cycles[i] = misc_regs->cnt.cycles;
	}

	/* Compute frame rate */
	return SYS_CLK_HZ / (cycles[1] - cycles[0]);
}
