/*
 * qpi.h
 *
 * Copyright (C) 2022 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdint.h>


void
qpi_xfer(const uint8_t cmd,
         const uint8_t *tx_buf, const unsigned int tx_len,
                                const unsigned int dummy_len,
               uint8_t *rx_buf, const unsigned int rx_len);

void
spi_xfer(const uint8_t *tx_buf, const unsigned int tx_len,
                                const unsigned int dummy_len,
               uint8_t *rx_buf, const unsigned int rx_len);
