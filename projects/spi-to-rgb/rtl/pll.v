/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Module for MCH2022 SPI to RGB LED project, PLL wrapper
 *
 * Copyright (C) 2022  Paul Honig <paul@printf.nl>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module pll (
    input  wire i_clk,
    output wire o_clk,
    output wire o_rst
);

    wire pll_lock;

    // Generated by icepll -i 12 -o 20

    // F_PLLIN:    12.000 MHz (given)
    // F_PLLOUT:   40.000 MHz (requested)
    // F_PLLOUT:   39.750 MHz (achieved)

    // FEEDBACK: SIMPLE
    // F_PFD:   12.000 MHz
    // F_VCO:  636.000 MHz

    // DIVR:  0 (4'b0000)
    // DIVF: 52 (7'b0110100)
    // DIVQ:  5 (3'b100)

    // FILTER_RANGE: 1 (3'b001)

    // Phase locked loop
    SB_PLL40_2F_PAD #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),
    .DIVF(7'b0110100),
    .DIVQ(3'b100),
    .FILTER_RANGE(3'b001),
    .PLLOUT_SELECT_PORTA ("GENCLK")
    ) SB_PLL40_PAD_inst (
        .LOCK(pll_lock),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .PACKAGEPIN(i_clk),
        .PLLOUTGLOBALA(o_clk)
    );

    reg [1:0] rst_ff;

    always @(posedge o_clk or negedge pll_lock)
    if (!pll_lock)
        rst_ff <= 2'b11;
    else
        rst_ff <= {rst_ff[0], 1'b0};

        // Use a global buffer to route the reset signal efficiently
    SB_GB rst_gbuf_I (
        .USER_SIGNAL_TO_GLOBAL_BUFFER (rst_ff[1]),
        .GLOBAL_BUFFER_OUTPUT         (o_rst)
    );

endmodule
