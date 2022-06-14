/*
 * lcd_phy.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module lcd_phy #(
	parameter integer SPEED = 0		// 0 = clk/2, 1 = clk
)(
	// LCD
	output wire [7:0] lcd_d,
	output wire       lcd_rs,
	output wire       lcd_wr_n,
	input  wire       lcd_fmark,

	// Control
	input  wire       phy_ena,
	input  wire [7:0] phy_data,
	input  wire       phy_rs, // 0 = cmd, 1 = data
	input  wire       phy_valid,
	output wire       phy_ready,

	// Status
	output reg        phy_fmark_stb,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Frame Mark
	wire fmark_iob;
	reg  fmark_reg;


	// Parallel interface
	// ------------------

generate

	// Half-Speed
	if (SPEED == 0) begin

		// Signals
		reg [7:0] iob_d;
		reg       iob_rs;
		reg       iob_wr_n;

		// Issue commands
		always @(posedge clk)
		begin
			if (phy_ready) begin
				iob_d    <= phy_valid ? phy_data  : 8'h00;
				iob_rs   <= phy_valid ? phy_rs    : 1'b0;
			end
		end

		always @(posedge clk)
			iob_wr_n <= iob_wr_n ? ~phy_valid : 1'b1;

		// Ready tracking
		assign phy_ready = iob_wr_n;

		// IOBs
		SB_IO #(
			.PIN_TYPE(6'b1101_01),
			.PULLUP(1'b0),
			.IO_STANDARD("SB_LVCMOS")
		) iob_I[9:0] (
			.PACKAGE_PIN   ({lcd_wr_n, lcd_rs, lcd_d}),
			.OUTPUT_CLK    (clk),
			.OUTPUT_ENABLE (phy_ena),
			.D_OUT_0       ({iob_wr_n, iob_rs, iob_d})
		);

	end

	// Full-Speed
	if (SPEED == 1) begin

		// Signals
		reg [7:0] iob_d;
		reg       iob_rs;
		reg [1:0] iob_wr_n;

		// Issue commands
		always @(posedge clk)
		begin
			iob_d    <= phy_valid ? phy_data : 8'h00;
			iob_rs   <= phy_valid ? phy_rs   : 1'b0;
			iob_wr_n <= phy_valid ? 2'b01    : 2'b11;
		end

		assign phy_ready = 1'b1;

		// IOBs
		SB_IO #(
			.PIN_TYPE(6'b1100_01),
			.PULLUP(1'b0),
			.IO_STANDARD("SB_LVCMOS")
		) iob_I[9:0] (
			.PACKAGE_PIN   ({lcd_wr_n, lcd_rs, lcd_d}),
			.OUTPUT_CLK    (clk),
			.OUTPUT_ENABLE (phy_ena),
			.D_OUT_0       ({iob_wr_n[0], iob_rs, iob_d}),
			.D_OUT_1       ({iob_wr_n[1], iob_rs, iob_d})
		);

	end

endgenerate


	// Detect Frame
	// ------------

	// IOB
	SB_IO #(
		.PIN_TYPE(6'b0000_00),   // Reg input, Reg+RegOE output
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_fmark_U (
		.PACKAGE_PIN   (lcd_fmark),
		.INPUT_CLK     (clk),
		.D_IN_0        (fmark_iob)
	);

	// Edge detect
	always @(posedge clk)
		fmark_reg <= fmark_iob;

	always @(posedge clk)
		phy_fmark_stb <= fmark_iob & ~fmark_reg;

endmodule // lcd_phy
