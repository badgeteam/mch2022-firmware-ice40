/*
 * lcd.h
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>


enum lcd_pattern {
	LCD_PATTERN_BLACK =  0,
	LCD_PATTERN_RED   =  9,
	LCD_PATTERN_GREEN = 10,
	LCD_PATTERN_BLUE  = 12,
	LCD_PATTERN_WHITE = 15,
	LCD_PATTERN_BARS  = 16,
};

void lcd_keep_reset(void);
void lcd_init(void);
void lcd_fill(enum lcd_pattern pat);
void lcd_passthrough(bool enable);
