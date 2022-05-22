/*
 * spi_loopback.v
 *
 * vim: ts=4 sw=4
 *
 * Simple loopback test for SPI core
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_loopback (
	// SPI Slave interface
	input  wire spi_mosi,
	output wire spi_miso,
	input  wire spi_clk,
	input  wire spi_cs_n,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// SPI Core
	wire [7:0] user_out;
	wire       user_out_stb;

	wire [7:0] user_in;
	wire       user_in_ack;

	wire       csn_state;
	wire       csn_rise;
	wire       csn_fall;

	// RAM
	reg  [8:0] mw_addr;
	wire [7:0] mw_data;
	wire       mw_ena;

	reg  [8:0] mr_addr;
	wire [7:0] mr_data;
	wire       mr_ena;


	// Core
	// ----

	spi_dev_core core_I (
		.spi_miso        (spi_miso),
		.spi_mosi        (spi_mosi),
		.spi_clk         (spi_clk),
		.spi_cs_n        (spi_cs_n),
		.user_out        (user_out),
		.user_out_stb    (user_out_stb),
		.user_in         (user_in),
		.user_in_ack     (user_in_ack),
		.csn_state       (csn_state),
		.csn_rise        (csn_rise),
		.csn_fall        (csn_fall),
		.clk             (clk),
		.rst             (rst) 
	);


	// Loopback
	// --------

	// Writes
	always @(posedge clk)
		if (csn_state)
			mw_addr <= 0;
		else
			mw_addr <= mw_addr + user_out_stb;
	
	assign mw_data = user_out;
	assign mw_ena  = user_out_stb;

	// Memory instance
	ram_sdp #(
		.AWIDTH(9),
		.DWIDTH(8)
	) mem_I (
		.wr_addr (mw_addr),
		.wr_data (mw_data),
		.wr_ena  (mw_ena),
		.rd_addr (mr_addr),
		.rd_data (mr_data),
		.rd_ena  (mr_ena),
		.clk     (clk)
	);

	// Reads
	always @(posedge clk)
		if (csn_state)
			mr_addr <= 0;
		else
			mr_addr <= mr_addr + user_in_ack;

	assign user_in = mr_data;
	assign mr_ena = 1'b1;

endmodule // spi_loopback
