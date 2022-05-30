/*
 * msg.h
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

bool     msg_pending(void);
uint32_t msg_get_request(void);
void     msg_put_response(uint32_t v);
