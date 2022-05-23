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
  input clk,
  input rst,

  input enable,

  // Output to the LED pins
  output [2:0] rgb_out
);

  wire w_cycle_r, w_cycle_g, w_cycle_b;
  wire w_led_r, w_led_g, w_led_b;
  reg r_led_r, r_led_g, r_led_b;

  // Cycle speeds of the RGB colors (All primes)
  parameter
  p_speed_r = 20'hff,
  p_speed_g = 20'hff,
  p_speed_b = 20'hff;

  // RED
  cycle #(
  .START_POS(0)
  ) red_cycle (
    .i_clk(clk),
    .i_rst(rst),
    .i_speed(p_speed_r),
    .o_led(rgb_out[0]),
  );

  // GREEN
  cycle #(
  .START_POS(512)
  ) green_cycle (
    .i_clk(clk),
    .i_rst(rst),
    .i_speed(p_speed_g),
    .o_led(rgb_out[1])
  );

  // BLUE
  cycle #(
  .START_POS(1024)
  ) blue_cycle (
    .i_clk(clk),
    .i_rst(rst),
    .i_speed(p_speed_b),
    .o_led(rgb_out[2])
  );

endmodule
