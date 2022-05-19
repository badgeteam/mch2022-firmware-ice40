
/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Top-level module for MCH2022 SPI to RGB LED project
 *
 * Copyright (C) 2022  Paul Honig <paul@printf.nl>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module top (
    // UART (to RP2040)
    output wire       uart_tx,
    input  wire       uart_rx,

    // IRQ (to ESP32)
    output wire       irq_n,

    // SPI Slave (to ESP32)
    input  wire       spi_mosi,
    output wire       spi_miso,
    input  wire       spi_clk,
    input  wire       spi_cs_n,

    // PSRAM
    inout  wire [3:0] ram_io,
    output wire       ram_clk,
    output wire       ram_cs_n,

    // LCD
    output wire [7:0] lcd_d,
    output wire       lcd_rs,
    output wire       lcd_wr_n,
    output wire       lcd_cs_n,
    output wire       lcd_mode,
    output wire       lcd_rst_n,
    input  wire       lcd_fmark,

    // PMOD
    inout  wire [7:0] pmod,

    // RGB Leds
    output wire [2:0] rgb,

    // Clock
    input  wire       clk_in
);
    wire clk;
    wire rst;

    // Release reset when pll has locked

    // Using a pll to create a desired clock
    pll pll_inst (
        .i_clk(clk_in),
        .o_clk(clk),
        .o_rst(rst)
    );

    // RGB LED wrapper
    rgbled rgbled_inst (
        .clk(clk),
        .rst(rst),

        // WHEN 1 - test mode is enabled
        // .test_mode(data_vector[0][0]),
        .test_mode(1'b1),

        // SPI control LEDS
        .in_r(1'b0),
        .in_g(1'b0),
        .in_b(1'b0),

        .led_r(rgb[0]),
        .led_g(rgb[1]),
        .led_b(rgb[2])
    );


endmodule // top