/*
 * spi_dev_core_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module spi_dev_core_tb;

	// Signals
	reg rst = 1'b1;
	reg clk_slow = 1'b0;
	reg clk_fast = 1'b0;

	wire spi_mosi;
	wire spi_miso;
	wire spi_cs_n;
	wire spi_clk;

	wire [7:0] usr_mosi_data;
	wire       usr_mosi_stb;

	reg  [7:0] usr_miso_data;
	wire       usr_miso_ack;

	wire csn_state;
	wire csn_rise;
	wire csn_fall;

	// Setup recording
	initial begin
		$dumpfile("spi_dev_core_tb.vcd");
		$dumpvars(0,spi_dev_core_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #16.66 clk_slow = !clk_slow; // ~  30 MHz (sys_clk)
	always #3.125 clk_fast = !clk_fast; // ~ 160 MHz (2*spi_clk)

	// DUT
	spi_dev_core spi_I (
		.spi_mosi     (spi_mosi),
		.spi_miso     (spi_miso),
		.spi_cs_n     (spi_cs_n),
		.spi_clk      (spi_clk),
		.usr_mosi_data(usr_mosi_data),
		.usr_mosi_stb (usr_mosi_stb),
		.usr_miso_data(usr_miso_data),
		.usr_miso_ack (usr_miso_ack),
		.csn_state    (csn_state),
		.csn_rise     (csn_rise),
		.csn_fall     (csn_fall),
		.clk          (clk_slow),
		.rst          (rst)
	);

	// Dummy TX
	always @(posedge clk_slow)
		if (csn_state)
			usr_miso_data <= 8'hA5;
		else if (usr_miso_ack)
			usr_miso_data <= usr_miso_data + 1;

	// SPI data generation
	reg [71:0] spi_csn_data = 72'b111100000000000000000000000000000000000000000000000000000001111111111111;
	reg [71:0] spi_clk_data = 72'b000000101010101010101010101010101010101010101010101010000000000000000000;
	reg [71:0] spi_dat_data = 72'b000001100110000110011111100000000001111110000000011000000000000000000000;

	always @(posedge clk_fast)
	begin
		if (~rst) begin
			spi_csn_data <= { spi_csn_data[70:0], spi_csn_data[71] };
			spi_clk_data <= { spi_clk_data[70:0], spi_clk_data[71] };
			spi_dat_data <= { spi_dat_data[70:0], spi_dat_data[71] };
		end
	end

	assign spi_mosi = spi_dat_data[70];
	assign spi_cs_n = spi_csn_data[70];
	assign spi_clk  = spi_clk_data[70];

	// Print and validate output
	reg  [1:0] out_cnt;
	reg [23:0] out_val = 24'hc2c1a5;

	always @(posedge clk_slow)
	begin
		if (csn_fall) begin
			$write("\nRX:");
			out_cnt = 0;
		end

		if (usr_mosi_stb) begin
			$write(" %02x", usr_mosi_data);
			if (usr_mosi_data != out_val[out_cnt*8+:8])
				$error("\nInvalid data\n");
			out_cnt = out_cnt + 1;
		end

		if (out_cnt == 4)
			$error("\nToo many data\n");
	end

endmodule // spi_dev_core_tb
