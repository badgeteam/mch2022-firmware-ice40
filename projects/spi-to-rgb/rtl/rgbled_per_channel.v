
/*
 * rgbled_per_channel.v
 *
 * vim: ts=4 sw=4
 *
 * A simple LED cycle routine in RGB
 *
 * Copyright (C) 2022  Paul Honig <paul@prinf.nl>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`default_nettype none
module rgbled_per_channel (
    input wire clk,
    input wire rst,

    input wire enable,

    // Delta sigma output
    output wire rgb_out[2:0],

    // 8-bit input channels
    input wire [7:0] led_r_in,
    input wire [7:0] led_g_in,
    input wire [7:0] led_b_in
);

    delta_sigma(
        .clk(clk),
        .control      (led_r_in),
        .led_out      (rgb_out[0]),
    );
    delta_sigma(
        .clk(clk),
        .control      (led_g_in),
        .led_out      (rgb_out[1]),
    );
    delta_sigma(
        .clk(clk),
        .control      (led_b_in),
        .led_out      (rgb_out[2]),
    );
endmodule

module delta_sigma(
    input  wire clk,
    input  wire [7:0] control,
    output reg led_out
);
    wire [8:0] phase_new;
    reg  [7:0] r_count_out = 0;
    reg  [7:0] phase;
    reg        r_led;

    always @(posedge clk) begin
        // PWM the led
        phase <= phase_new[7:0];
        led_out <= phase_new[8];
    end

    assign phase_new = phase + r_count_out;
endmodule