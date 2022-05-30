/*
 * misc.h
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>


#define MISC_GPIO_IRQ_N		(1 << 11)
#define MISC_GPIO_LCD_CS_N	(1 << 10)
#define MISC_GPIO_LCD_MODE	(1 <<  9)
#define MISC_GPIO_LCD_RST_N	(1 <<  8)
#define MISC_GPIO_PMOD(n)	(1 << (n))
#define MISC_GPIO_PMOD_ALL	(0xff)


void     gpio_set_dir(uint32_t pins, bool oe);
void     gpio_set_val(uint32_t pins, uint32_t val);
void     gpio_set(uint32_t pins);
void     gpio_clear(uint32_t pins);
uint32_t gpio_get_val(uint32_t pins);

void delay_us(unsigned int us);
void delay_ms(unsigned int ms);

int measure_framerate(void);
