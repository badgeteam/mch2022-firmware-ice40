/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * CRG generating:
 *  - clk_1x  -  30 MHz for main logic
 *  - clk_4x  - 120 MHz for QPI memory
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module sysmgr (
	// Inputs
	input  wire clk_in,

	// System
	output wire clk_1x,
	output wire clk_4x,
	output wire sync_4x,
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
		.DIVQ                (3'b011),
		.FILTER_RANGE        (3'b001),
		.PLLOUT_SELECT_PORTA ("GENCLK"),
		.PLLOUT_SELECT_PORTB ("SHIFTREG_0deg")
	) pll_I (
		.PACKAGEPIN    (clk_in),
		.PLLOUTGLOBALA (clk_4x),
		.PLLOUTGLOBALB (clk_1x),
		.RESETB        (1'b1),
		.LOCK          (pll_lock)
	);

	// SERDES sync signal
	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (0),
		.BEL_COL    ("X21"),
		.BEL_ROW    ("Y4")
	) sync_4x_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_4x),
		.rst      (rst),
		.sync     (sync_4x)
	);

	// Reset generation
	always @(posedge clk_1x or negedge pll_lock)
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
