/*
 * cycle.v
 *
 * vim: ts=4 sw=4
 *
 * A simple LED cycle routine
 *
 * Copyright (C) 2022  Paul Honig <paul@prinf.nl>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */
`default_nettype none

module cycle #(
  parameter START_PHASE=0
) (
  input clk,
  input rst,
  input [4:0] i_speed,
  output o_led
);

  // LED output register
  reg r_led;

  /*
   * Pipelined Speed devider counter
   */
  reg        r_count_strobe;
  reg [16:0] r_count_speed;
  wire [9:0] w_count_speed_0;
  wire [7:0] w_count_speed_1;

  assign  w_count_speed_0 = r_count_speed[8:0] + 1;
  assign  w_count_speed_1 = r_count_speed[16:9] + w_count_speed_0[9];

  // Pipelined delay counter
  always @(posedge clk) begin
    // r_count_speed <= r_count_speed + 1;
    r_count_speed[8:0] <= w_count_speed_0[8:0];
    r_count_speed[16:9] <= w_count_speed_1[7:0];
    // if (r_count_speed == i_speed) // 124 +- 2 s
    r_count_strobe <= 1'b0;
    if (r_count_speed[i_speed]) begin
      r_count_strobe <= 1'b1;
      r_count_speed <= 0;
    end

    if(rst == 1'b0) begin
      r_count_speed <= 'b0;
    end
  end


  // Delta-sigma to output
  reg [7:0] led_brightness = 0;
  reg [7:0] ds_count = 0;
  wire [8:0] ds_count_new = ds_count + led_brightness;
  always @(posedge clk) begin
    ds_count <= ds_count_new[7:0];
    r_led <= ds_count_new[8];

    if (rst == 1'b0) begin
      ds_count <= 0;
      r_led <= 0;
    end
  end

  // count_cur up and down
  reg [7:0] phase_count;
  wire [8:0] phase_count_new = phase_count + 1;

  // Counter stage phase
  parameter PHASE_UP_0 = 0,
  PHASE_HIGH_0 = 1, // 256
  PHASE_HIGH_1 = 2, // 512
  PHASE_DOWN_0 = 3, // 768
  PHASE_LOW_0 = 4, // 1024
  PHASE_LOW_1 = 5; // 1280 - 1536
  reg [2:0] phase_state = START_PHASE;

  // Brightness state machine
  always @(posedge clk) begin
    // Update counters every X cycles
    if (r_count_strobe) begin

      /**
       * Create the shape that cycles the colors
       *   __
       *  /  \__
       *  0 1024 1535
       * *************************
       *  This over three channels with 512 phase difference makes a nice. color cycle
       *         __
       *  RED   /  \__
       *           __
       *  GREEN __/  \
       *        _    _
       *  BLUE   \__/  
       */

      // Update the phase counter
      phase_count <= phase_count_new[7:0];

      // Blink phase state machine
      case (phase_state)
        PHASE_UP_0: begin
          led_brightness <= phase_count;
          if (phase_count_new[8] == 1'b1) begin
            phase_state <= PHASE_HIGH_0;
          end
        end
        PHASE_HIGH_0: begin
          led_brightness <= 255;
          if (phase_count_new[8] == 1'b1) begin
            phase_state <= PHASE_HIGH_1;
          end
        end
        PHASE_HIGH_1: begin
          led_brightness <= 255;
          if (phase_count_new[8] == 1'b1) begin
            phase_state <= PHASE_DOWN_0;
          end
        end
        PHASE_DOWN_0: begin
          led_brightness <= 255 - phase_count;
          if (phase_count_new[8] == 1'b1) begin
            phase_state <= PHASE_LOW_0;
          end
        end
        PHASE_LOW_0: begin
          led_brightness <= 0;
          if (phase_count_new[8] == 1'b1) begin
            phase_state <= PHASE_LOW_1;
          end
        end
        PHASE_LOW_1: begin
          led_brightness <= 0;
          if (phase_count_new[8] == 1'b1) begin
            phase_state <= PHASE_UP_0;
          end
        end
        default: begin
          phase_state <= PHASE_UP_0;
        end
      endcase;
    end

    // Reset holds counters 
    if(rst == 1'b0 ) begin
      phase_state <= START_PHASE;
      phase_count <= 0;
    end

  end

  // LED register to output
  assign o_led = r_led;

endmodule
