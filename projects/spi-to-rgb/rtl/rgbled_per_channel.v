
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
    output wire [2:0] rgb_out,

    // 8-bit input channels
    input wire [7:0] led_r_in,
    input wire [7:0] led_g_in,
    input wire [7:0] led_b_in
);

    delta_sigma dsr_inst(
        .clk(clk),
        .rst(rst),
        .control(led_r_in),
        .led_out(rgb_out[0])
    );
    delta_sigma dsg_inst(
        .clk(clk),
        .rst(rst),
        .control(led_g_in),
        .led_out(rgb_out[1])
    );
    delta_sigma dsb_inst(
        .clk(clk),
        .rst(rst),
        .control(led_b_in),
        .led_out(rgb_out[2])
    );
endmodule

module delta_sigma(
    input  wire clk,
    input  wire rst,
    input  wire [7:0] control,
    output reg led_out
);
    wire [8:0] phase_new = phase + control;
    reg  [7:0] phase;
    reg        r_led;

    always @(posedge clk) begin
        // PWM the led
        phase <= phase_new[7:0];
        if (rst == 1'b0) begin
            phase <= 0;
            led_out <= 0;
        end else begin
            led_out <= phase_new[8];
        end
    end

endmodule