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
	LCD_PATTERN_BLACK = 0,
	LCD_PATTERN_RED   = 1,
	LCD_PATTERN_GREEN = 2,
	LCD_PATTERN_BLUE  = 4,
	LCD_PATTERN_WHITE = 15,
	LCD_PATTERN_BARS  = 16,
};

bool lcd_init(void);
void lcd_fill(enum lcd_pattern pat);
void lcd_passthrough(bool enable);
