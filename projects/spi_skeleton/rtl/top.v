/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Top-level module for MCH2022 SPI skeleton
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module top (
	// SPI Slave (to ESP32)
	input  wire       spi_mosi,
	output wire       spi_miso,
	input  wire       spi_clk,
	input  wire       spi_cs_n,

	// RGB Leds
	output wire [2:0] rgb,

	// Clock
	input  wire       clk_in
);

	localparam integer WN = 1;
	genvar i;


	// Signals
	// -------

	// Wishbone
	wire   [23:0] wb_addr;
	wire   [31:0] wb_rdata [0:WN-1];
	wire   [31:0] wb_wdata;
	wire [WN-1:0] wb_cyc;
	wire          wb_we;
	wire [WN-1:0] wb_ack;

	wire [(32*WN)-1:0] wb_rdata_flat;

	// Clock / Reset
	wire        clk;
	wire        rst;


	// SPI
	// ---

	spi_dev_ezwb #(
		.WB_N(WN)
	) spi_dev_I (
		.spi_mosi (spi_mosi),
		.spi_miso (spi_miso),
		.spi_clk  (spi_clk),
		.spi_cs_n (spi_cs_n),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata_flat),
		.wb_addr  (wb_addr),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.clk      (clk),
		.rst      (rst)
	);

	for (i=0; i<WN; i=i+1)
		assign wb_rdata_flat[i*32+:32] = wb_rdata[i];


	// RGB LEDs [0]
	// --------

	ice40_rgb_wb #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_I (
		.pad_rgb    (rgb),
		.wb_addr    (wb_addr[4:0]),
		.wb_rdata   (wb_rdata[0]),
		.wb_wdata   (wb_wdata),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[0]),
		.wb_ack     (wb_ack[0]),
		.clk        (clk),
		.rst        (rst)
	);


	// Clock/Reset Generation
	// ----------------------

	sysmgr sysmgr_I (
		.clk_in (clk_in),
		.clk    (clk),
		.rst    (rst)
	);

endmodule // top
