/*
 * spi_dev_arb.v
 *
 * vim: ts=4 sw=4
 *
 * Arbiter to wire up several cores to the "Read/Response IF" of
 * the protocol wrapper (`spi_dev_proto`).
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_arb #(
	parameter integer N = 1,

	// auto
	parameter integer NL =    N -1,
	parameter integer DL = (8*N)-1
)(
	// Upstream
	output wire        us_req,
	input  wire        us_gnt,

	output reg   [7:0] us_rdata,
	output reg         us_rstb,

	// Downstream
	input  wire [NL:0] ds_req,
	output wire [NL:0] ds_gnt,

	input  wire [DL:0] ds_rdata,
	input  wire [NL:0] ds_rstb,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	localparam WL = $clog2(N) - 1;

	reg [WL:0] sel_nxt;
	reg [WL:0] sel;
	reg [NL:0] sel_mask_nxt;
	reg [NL:0] sel_mask;
	reg        sel_valid;
	wire       sel_done;
	reg        sel_inhibit;


	// Control
	// -------

	// Continuous selection of potential next
	always @(*)
	begin : sel_loop
		integer i;

		sel_nxt = 0;
		sel_mask_nxt = 0;

		for (i=N-1; i>=0; i=i-1)
			if (ds_req[i]) begin
				sel_nxt = i;
				sel_mask_nxt = 0;
				sel_mask_nxt[i] = 1'b1;
			end
	end

	// Latch selection
	always @(posedge clk or posedge rst)
		if (rst) begin
			sel_valid <= 1'b0;
			sel_mask   <= 0;
			sel        <= 0;
		end else begin
			if (sel_valid) begin
				// Just track we're still active
				if (sel_done) begin
					sel_valid <= 1'b0;
					sel_mask   <= 0;
					sel        <= 0;
				end
			end else begin
				sel_valid <= |ds_req;
				sel_mask   <= sel_mask_nxt;
				sel        <= sel_nxt;
			end
		end

	// Detect end
	assign sel_done = sel_valid & ~ds_req[sel];

	always @(posedge clk)
		sel_inhibit <= sel_done;

	// Pass on request DS -> US
	assign us_req = sel_valid | (|ds_req & ~sel_inhibit);

	// Pass on grants US -> DS
	assign ds_gnt = (us_gnt & sel_valid) ? sel_mask : 0;

	// Data mux
	always @(posedge clk)
	begin
		us_rdata <= ds_rdata[8*sel+:8];
		us_rstb  <= ds_rstb[sel];
	end

endmodule // spi_dev_arb
