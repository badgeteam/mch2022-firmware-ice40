/*
 * cycle.v
 *
 * vim: ts=4 sw=4
 *
 * A simple LED cycle routine in RGB
 *
 * Copyright (C) 2022  Paul Honig <paul@prinf.nl>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`default_nettype none
module rgbled_cycle (
  input wire        clk,
  input wire        rst,

  input wire  [4:0] r_speed,
  input wire  [4:0] g_speed,
  input wire  [4:0] b_speed,

  input wire        enable, // Enable cycle

  output wire [2:0] rgb_out // Output to the LED pins
);

  // Cycle speeds of the RGB colors (All primes)

  // RED
  cycle #(
  .START_PHASE(0) // cycle.PHASE_UP_0
  ) red_cycle (
    .clk(clk),
    .rst(rst),
    .i_speed(r_speed),
    .o_led(rgb_out[0])
  );

  // GREEN
  cycle #(
  .START_PHASE(2) // cycle.PHASE_HIGH_1
  ) green_cycle (
    .clk(clk),
    .rst(rst),
    .i_speed(g_speed),
    .o_led(rgb_out[1])
  );

  // BLUE
  cycle #(
  .START_PHASE(4) // cycle.PHASE_LOW_0
  ) blue_cycle (
    .clk(clk),
    .rst(rst),
    .i_speed(b_speed),
    .o_led(rgb_out[2])
  );


endmodule
