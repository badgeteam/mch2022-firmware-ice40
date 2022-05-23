/*
 * spi_rgb_effects.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Paul Honig <paul@etv.cx>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_rgb_effects #(
)(
    // RGB routing 
    output wire  [2:0] rgb_leds_o,

    // Wishbone interface
    input  wire [31:0] wb_wdata,
    output reg  [31:0] wb_rdata,
    input  wire [ 1:0] wb_addr,
    input  wire        wb_we,
    input  wire        wb_cyc,
    output reg         wb_ack,

    // Clock / Reset
    input  wire clk,
    input  wire rst
);

    // Signals
    // -------
    reg         func_reg_o;
    reg  [31:0] func_reg_data;
    reg         rgb_o;
    reg  [31:0] rgb_data;

    reg         driver_enable;
    reg         cycle_enable;
    reg         per_channel_enable;

    // Bus IF
    wire bus_clr;
    reg  bus_we_gpio_oe;
    reg  bus_we_gpio_o;

    wire [2:0] rgb_leds_d;
    wire [2:0] rgb_leds_c;
    wire [2:0] rgb_leds_p;

    // Bus interface
    // -------------

    // ACK & Clear
    always @(posedge clk)
    wb_ack <= wb_cyc & ~wb_ack;

    assign bus_clr = ~wb_cyc | wb_ack;

    // Write Enables
    always @(posedge clk)
    if (bus_clr) begin
        bus_we_gpio_oe <= 1'b0;
        bus_we_gpio_o  <= 1'b0;
    end else begin
        func_reg_o <= wb_we & (wb_addr[1:0] == 2'b00);
        rgb_o  <= wb_we & (wb_addr[1:0] == 2'b01);
    end

    // Registers
    always @(posedge clk)
    if (rst)
        func_reg_o <= 0;
    else if (bus_we_gpio_oe)
        func_reg_data <= wb_wdata[N-1:0];

    always @(posedge clk)
    if (rst)
        rgb_o <= 0;
    else if (bus_we_gpio_o)
        rgb_data <= wb_wdata[N-1:0];

        // Read-Mux
    always @(posedge clk)
    if (bus_clr)
        wb_rdata <= 0;
    else
        casez (wb_addr[1:0])
            2'b00:   wb_rdata <= func_reg_data;
            2'b01:   wb_rdata <= rgb_data;
            // 2'b10:   wb_rdata <= { {(32-N){1'b0}}, gpio_i  };
            default: wb_rdata <= 32'hxxxxxxxx;
        endcase

        // Effects
    always @(posedge clk) begin
        driver_enable <= func_reg_data[0];
        cycle_enable <= func_reg_data[1];
        per_channel_enable <= func_reg_data[2];
    end

    // RGB LED wrapper
    rgbled_cycle rgbled_cycle_inst (
        .clk(clk),
        .rst(rst),
        // WHEN 1 - test mode is enabled
        // .test_mode(data_vector[0][0]),
        .enable(cycle_enable),
        .rgb_out(rgb_leds_c)
    );

    // RGB LED, per channel value
    rgbled_per_channel rgbled_per_channel_inst (
        .clk(clk),
        .rst(rst),

        .enable(per_channel_enable),

        .led_r_in(rgb_data[7:0]),
        .led_g_in(rgb_data[8:15]),
        .led_b_in(rgb_data[16:24]),

        .rgb_out(rgb_leds_p),
    );

    // RGB LED, to the output
    always @(posedge clk) begin
        if (rst) begin
            rgb_leds_o <= 3'b000;
        end else begin
            if (cycle_enable) begin
                rgb_leds_d <= rgb_leds_c;
            end else if (per_channel_enable) begin
                rgb_leds_d <= rgb_leds_p;
            end
        end
    end

    // RGB IP
    SB_RGBA_DRV #(
    .CURRENT_MODE("0b1"),
    .RGB0_CURRENT("0b000001"),
    .RGB1_CURRENT("0b000001"),
    .RGB2_CURRENT("0b000001")
    ) u_rgb_drv (
        .RGB0(rgb_leds_o[0]),
        .RGB1(rgb_leds_o[1]),
        .RGB2(rgb_leds_o[2]),
        .RGBLEDEN(1'b1),
        .RGB0PWM(rgb_leds_d[0]),
        .RGB1PWM(rgb_leds_d[1]),
        .RGB2PWM(rgb_leds_d[2]),
        .CURREN(driver_enable)
    );

endmodule // gpio_wb
