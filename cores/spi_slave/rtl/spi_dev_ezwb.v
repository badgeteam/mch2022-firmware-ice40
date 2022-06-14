/*
 * spi_dev_ezwb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_ezwb #(
	parameter integer WB_N = 3,

	// auto
	parameter integer DL = (32*WB_N)-1,
	parameter integer CL = WB_N-1
)(
	// SPI interface
	output wire        spi_miso,
	input  wire        spi_mosi,
	input  wire        spi_clk,
	input  wire        spi_cs_n,

	// Wishbone
	output reg  [31:0] wb_wdata,
	input  wire [DL:0] wb_rdata,
	output reg  [23:0] wb_addr,
	output wire        wb_we,
	output reg  [CL:0] wb_cyc,
	input  wire [CL:0] wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Raw core IF
	wire [7:0] usr_mosi_data;
	wire       usr_mosi_stb;

	wire [7:0] usr_miso_data;
	wire       usr_miso_ack;

	wire       csn_state;
	wire       csn_rise;
	wire       csn_fall;

	// Protocol IF
	wire [7:0] pw_wdata;
	wire       pw_wcmd;
	wire       pw_wstb;

	wire       pw_end;

	wire       pw_req;
	wire       pw_gnt;

	wire [7:0] pw_rdata;
	wire       pw_rstb;


	// Cores
	// -----

	// Device Core
	spi_dev_core core_I (
		.spi_miso      (spi_miso),
		.spi_mosi      (spi_mosi),
		.spi_clk       (spi_clk),
		.spi_cs_n      (spi_cs_n),
		.usr_mosi_data (usr_mosi_data),
		.usr_mosi_stb  (usr_mosi_stb),
		.usr_miso_data (usr_miso_data),
		.usr_miso_ack  (usr_miso_ack),
		.csn_state     (csn_state),
		.csn_rise      (csn_rise),
		.csn_fall      (csn_fall),
		.clk           (clk),
		.rst           (rst)
	);

	// Protocol wrapper
	spi_dev_proto proto_I (
		.usr_mosi_data (usr_mosi_data),
		.usr_mosi_stb  (usr_mosi_stb),
		.usr_miso_data (usr_miso_data),
		.usr_miso_ack  (usr_miso_ack),
		.csn_state     (csn_state),
		.csn_rise      (csn_rise),
		.csn_fall      (csn_fall),
		.pw_wdata      (pw_wdata),
		.pw_wcmd       (pw_wcmd),
		.pw_wstb       (pw_wstb),
		.pw_end        (pw_end),
		.pw_req        (pw_req),
		.pw_gnt        (pw_gnt),
		.pw_rdata      (pw_rdata),
		.pw_rstb       (pw_rstb),
		.pw_irq        (4'h0),
		.irq           (),
		.clk           (clk),
		.rst           (rst)
	);

	// Wishbone bridge
	spi_dev_to_wb #(
		.WB_N(WB_N)
	) wb_I (
		.pw_wdata (pw_wdata),
		.pw_wcmd  (pw_wcmd),
		.pw_wstb  (pw_wstb),
		.pw_end   (pw_end),
		.pw_req   (pw_req),
		.pw_gnt   (pw_gnt),
		.pw_rdata (pw_rdata),
		.pw_rstb  (pw_rstb),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata),
		.wb_addr  (wb_addr),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.clk      (clk),
		.rst      (rst)
	);

endmodule // spi_dev_ezwb
