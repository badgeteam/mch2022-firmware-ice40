/*
 * spi_dev_scmd.v
 *
 * vim: ts=4 sw=4
 *
 * Simple Command decoder.
 * Interfaces to the protocol wrapper to decode simple/short commands
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_scmd #(
	parameter [7:0] CMD_BYTE = 8'h00,
	parameter integer CMD_LEN = 4,

	// auto
	parameter integer DL = (8*CMD_LEN)-1
)(
	// Protocol wrapper interface
	input  wire  [7:0] pw_wdata,
	input  wire        pw_wcmd,
	input  wire        pw_wstb,

	input  wire        pw_end,

	// Command output
	output wire [DL:0] cmd_data,
	output reg         cmd_stb,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Write Shift
	reg  [DL:0] ws_data;
	reg  [CMD_LEN-1:0] ws_stb_shift;


	// Command decoder
	// ---------------

	// Data shift register
	always @(posedge clk)
		if (pw_wstb)
			ws_data <= { ws_data[23:0], pw_wdata };

	assign cmd_data = ws_data;

	// Command match
	always @(posedge clk or posedge rst)
		if (rst)
			ws_stb_shift <= 0;
		else if (pw_wstb)
			ws_stb_shift <= {
				ws_stb_shift[CMD_LEN-2:0],
				(pw_wdata == CMD_BYTE) & pw_wcmd
			};

	always @(posedge clk)
		cmd_stb <= pw_wstb & ws_stb_shift[CMD_LEN-1];

endmodule // spi_dev_scmd
