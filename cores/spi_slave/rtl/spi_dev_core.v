/*
 * spi_dev_core.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_core (
	// SPI interface
	output wire spi_miso,
	input  wire spi_mosi,
	input  wire spi_clk,
	input  wire spi_cs_n,

	// User data interface
	output wire [7:0] usr_mosi_data,
	output reg        usr_mosi_stb,

	input  wire [7:0] usr_miso_data,
	output reg        usr_miso_ack,

	// CS_n line (resynched to user clock domain)
	output wire csn_state,
	output wire csn_rise,
	output wire csn_fall,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// IOs
	wire spi_clk_buf;
	wire spi_mosi_in;
	wire spi_miso_out;
	wire spi_miso_oe;

	// SPI clock domain
	reg  [3:0] bit_cnt;
	wire bit_cnt_last;

	wire [7:0] shift_in;
	wire [7:0] shift_reg;

	wire [7:0] save_in;
	wire [7:0] save_reg;

	reg xfer_toggle = 1'b0;	// init only for simulation

	// User clock domain
	wire [1:0] xfer_sync;
	wire xfer_now;

	wire csn_cap_i;
	wire csn_state_i;
	wire csn_rise_i;
	wire csn_fall_i;

	wire [7:0] cap_reg;
	wire [7:0] out_reg;

	wire cap_ce;
	wire out_ce;


	// SPI clock domain
	// ----------------

	// Buffer SPI clock (X19/Y0 is used by PLL out :/)
	(* BEL="X13/Y0/gb" *) SB_GB spi_clk_gb_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(spi_clk),
		.GLOBAL_BUFFER_OUTPUT(spi_clk_buf)
	);

	// MOSI IOB
	SB_IO #(
		.PIN_TYPE(6'b000001),
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) spi_mosi_iob_I (
		.PACKAGE_PIN(spi_mosi),
		.D_IN_0(spi_mosi_in)
	);

	// MISO IOB
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) spi_miso_iob_I (
		.PACKAGE_PIN(spi_miso),
		.OUTPUT_ENABLE(spi_miso_oe),
		.D_OUT_0(spi_miso_out)
	);

	// Bit counter
	always @(posedge spi_clk_buf or posedge spi_cs_n)
		if (spi_cs_n)
			bit_cnt <= 4'h1;
		else
			bit_cnt <= { 1'b0, bit_cnt[2:0] } + 1;

	assign bit_cnt_last = bit_cnt[3];

	// Shift register
	assign shift_in = bit_cnt_last ? out_reg : { shift_reg[6:0], spi_mosi_in };

	spi_dev_reg8 #(
		.BEL("X23/Y1")
	) shift_I (
		.d(shift_in),
		.q(shift_reg),
		.ce(1'b1),
		.rst(spi_cs_n),
		.clk(spi_clk_buf)
	);

	// Save register
	assign save_in = { shift_reg[6:0], spi_mosi_in };

	spi_dev_reg8 #(
		.BEL("X24/Y1")
	) save_I (
		.d(save_in),
		.q(save_reg),
		.ce(bit_cnt_last),
		.rst(1'b0),
		.clk(spi_clk_buf)
	);

	// Transfer Toggle register
	always @(posedge spi_clk_buf)
		xfer_toggle <= xfer_toggle ^ (bit_cnt[2:0] == 3'b111);

	// Output
	assign spi_miso_oe = ~spi_cs_n;
	assign spi_miso_out = shift_reg[7];


	// User clock domain
	// -----------------

	// Transfer Toggle synchronizer
	(* dont_touch="true", BEL="X23/Y2/lc0" *) SB_DFF dff_xt_0_I (
		.D(xfer_toggle),
		.Q(xfer_sync[0]),
		.C(clk)
	);

	(* dont_touch="true", BEL="X23/Y2/lc1" *) SB_DFF dff_xt_1_I (
		.D(xfer_sync[0]),
		.Q(xfer_sync[1]),
		.C(clk)
	);

	(* dont_touch="true", BEL="X23/Y2/lc2" *) SB_DFF dff_xt_n_I (
		.D(xfer_sync[0] ^ xfer_sync[1]),
		.Q(xfer_now),
		.C(clk)
	);

	// Chip Select synchronizer and edge detection
	(* dont_touch="true", BEL="X23/Y2/lc3" *) SB_DFF dff_cs_c_I (
		.D(spi_cs_n),
		.Q(csn_cap_i),
		.C(clk)
	);

	(* dont_touch="true", BEL="X23/Y2/lc4" *) SB_DFF dff_cs_s_I (
		.D(csn_cap_i),
		.Q(csn_state_i),
		.C(clk)
	);

	(* dont_touch="true", BEL="X23/Y2/lc5" *) SB_DFF dff_cs_r_I (
		.D(~csn_state & csn_cap_i),
		.Q(csn_rise_i),
		.C(clk)
	);

	(* dont_touch="true", BEL="X23/Y2/lc6" *) SB_DFF dff_cs_f_I (
		.D(csn_state & ~csn_cap_i),
		.Q(csn_fall_i),
		.C(clk)
	);

	// Input Capture register
	spi_dev_reg8 #(
		.BEL("X24/Y2")
	) in_cap_I (
		.d(save_reg),
		.q(cap_reg),
		.ce(cap_ce),
		.rst(1'b0),
		.clk(clk)
	);

	// Output Cross register
	spi_dev_reg8 #(
		.BEL("X22/Y1")
	) out_cross_I (
		.d(usr_miso_data),
		.q(out_reg),
		.ce(out_ce),
		.rst(1'b0),
		.clk(clk)
	);

	// Control
		// Capture & Send to user
	assign cap_ce = xfer_now;

	always @(posedge clk)
		usr_mosi_stb <= xfer_now;

		// Save user data and send to SPI
	assign out_ce = xfer_now | csn_fall_i;

	always @(posedge clk)
		usr_miso_ack <= xfer_now | csn_fall_i;

	// Send CS_n status to user
	assign csn_state = csn_state_i;
	assign csn_rise  = csn_rise_i;
	assign csn_fall  = csn_fall_i;

	// Send data to user
	assign usr_mosi_data = cap_reg;

endmodule // spi_dev_core


module spi_dev_reg8 #(
	parameter BEL = "X0/Y0"
)(
	input  wire [7:0] d,
	output wire [7:0] q,
	input  wire ce,
	input  wire rst,
	input  wire clk
);

	(* dont_touch="true", BEL={BEL, "/lc0"} *) SB_DFFER dffe_0 (
		.D(d[0]),
		.Q(q[0]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc1"} *) SB_DFFER dffe_1 (
		.D(d[1]),
		.Q(q[1]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc2"} *) SB_DFFER dffe_2 (
		.D(d[2]),
		.Q(q[2]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc3"} *) SB_DFFER dffe_3 (
		.D(d[3]),
		.Q(q[3]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc4"} *) SB_DFFER dffe_4 (
		.D(d[4]),
		.Q(q[4]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc5"} *) SB_DFFER dffe_5 (
		.D(d[5]),
		.Q(q[5]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc6"} *) SB_DFFER dffe_6 (
		.D(d[6]),
		.Q(q[6]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc7"} *) SB_DFFER dffe_7 (
		.D(d[7]),
		.Q(q[7]),
		.E(ce),
		.R(rst),
		.C(clk)
	);

endmodule // spi_dev_reg8
