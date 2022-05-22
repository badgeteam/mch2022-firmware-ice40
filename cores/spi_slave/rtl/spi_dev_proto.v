/*
 * spi_dev_proto.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_proto (
	// Interface to raw core
	input  wire [7:0] usr_mosi_data,
	input  wire       usr_mosi_stb,

	output wire [7:0] usr_miso_data,
	input  wire       usr_miso_ack,

	input  wire       csn_state,
	input  wire       csn_rise,
	input  wire       csn_fall,

	// Protocol wrapper interface
	output wire [7:0] pw_wdata,
	output wire       pw_wcmd,
	output wire       pw_wstb,

	output wire       pw_end,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	reg active;
	reg first_rx;
	reg first_tx;

	reg [7:0] cnt;


	// Dummy control
	// -------------

	assign pw_wdata = usr_mosi_data;
	assign pw_wcmd  = first_rx;
	assign pw_wstb  = usr_mosi_stb;

	assign usr_miso_data = first_tx ? 8'ha5 : cnt;

	always @(posedge clk)
		if (csn_state)
			cnt <= 0;
		else
			cnt <= cnt + (usr_miso_ack & ~first_tx);

	always @(posedge clk)
		if (rst) begin
			first_tx <= 1'b1;
			first_rx <= 1'b1;
		end else begin
			first_tx <= (first_tx & ~usr_miso_ack) | csn_rise;
			first_rx <= (first_rx & ~usr_mosi_stb) | csn_rise;
		end
	
	assign pw_end = csn_rise;

endmodule // spi_dev_proto
