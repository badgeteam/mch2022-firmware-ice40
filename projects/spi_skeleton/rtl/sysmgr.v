/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module sysmgr (
	// Inputs
	input  wire clk_in,

	// System
	output wire clk,
	output wire rst
);

	// Signals
	// -------

	// Misc
	wire     pll_lock;

	// System reset
	reg [3:0] rst_cnt;
	wire      rst_i;


	// System clock
	// ------------

	// PLL
	SB_PLL40_2F_PAD #(
		.FEEDBACK_PATH       ("SIMPLE"),
		.DIVR                (4'b0000),
		.DIVF                (7'b1001111),
		.DIVQ                (3'b101),
		.FILTER_RANGE        (3'b001),
		.PLLOUT_SELECT_PORTA ("GENCLK")
	) pll_I (
		.PACKAGEPIN    (clk_in),
		.PLLOUTGLOBALA (clk),
		.RESETB        (1'b1),
		.LOCK          (pll_lock)
	);

	// Reset generation
	always @(posedge clk or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h8;
		else if (rst_i)
			rst_cnt <= rst_cnt + 1;

	assign rst_i = rst_cnt[3];

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_i),
		.GLOBAL_BUFFER_OUTPUT         (rst)
	);

endmodule // sysmgr
