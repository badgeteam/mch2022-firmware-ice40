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

module spi_loopback #(
	parameter [7:0] CMD_BYTE = 8'hf1
)(
	// Protocol wrapper interface
	input  wire  [7:0] pw_wdata,
	input  wire        pw_wcmd,
	input  wire        pw_wstb,

	input  wire        pw_end,

	output wire        pw_req,
	input  wire        pw_gnt,

	output wire  [7:0] pw_rdata,
	output wire        pw_rstb,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	reg active;


	// Core
	// ----

	// Decode command
	always @(posedge clk)
		if (rst)
			active <= 1'b0;
		else
			active <= (active | (pw_wstb & pw_wcmd & (pw_wdata == CMD_BYTE))) & ~pw_end;

	// Create response
	assign pw_req   = active;
	assign pw_rdata = pw_wdata;
	assign pw_rstb  = pw_wstb & active;

endmodule // spi_loopback
