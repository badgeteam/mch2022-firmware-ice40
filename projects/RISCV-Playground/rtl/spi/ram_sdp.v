/*
 * ram_sdp.v
 *
 * vim: ts=4 sw=4
 *
 * Simple Dual Port RAM, inferred.
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module ram_sdp #(
	parameter integer AWIDTH = 9,
	parameter integer DWIDTH = 8
)(
	input  wire [AWIDTH-1:0] wr_addr,
	input  wire [DWIDTH-1:0] wr_data,
	input  wire wr_ena,

	input  wire [AWIDTH-1:0] rd_addr,
	output reg  [DWIDTH-1:0] rd_data,
	input  wire rd_ena,

	input  wire clk
);
	// Signals
	(* no_rw_check *)
	reg [DWIDTH-1:0] ram [(1<<AWIDTH)-1:0];

`ifdef SIM
	integer i;
	initial
		for (i=0; i<(1<<AWIDTH); i=i+1)
			ram[i] = 0;
`endif

	always @(posedge clk)
	begin
		// Read
		if (rd_ena)
			rd_data <= ram[rd_addr];

		// Write
		if (wr_ena)
			ram[wr_addr] <= wr_data;
	end

endmodule // ram_sdp
