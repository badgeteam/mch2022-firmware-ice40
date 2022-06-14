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
	// UART (to RP2040)
	output wire       uart_tx,

	// SPI Slave (to ESP32)
	input  wire       spi_mosi,
	output wire       spi_miso,
	input  wire       spi_clk,
	input  wire       spi_cs_n,

	// IRQ
	output wire       irq_n,

	// RGB Leds
	output wire [2:0] rgb,

	// Clock
	input  wire       clk_in
);

	localparam integer WN = 2;
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

	// Button reports
	wire [15:0] btn_rpt_state;
	wire [15:0] btn_rpt_change;
	wire        btn_rpt_stb;

	// UART sender
	reg   [7:0] uart_data;
	reg         uart_valid;
	wire        uart_ack;

	// Clock / Reset
	wire        clk;
	wire        rst;


	// SPI WB "All-in-one"
	// -------------------

	// Example of SPI interface using the "all-in-one"
	// SPI-to-wishbone wrapper
	//
	// It's easy and compact to use, but only does bus
	// accesses

`ifdef EZ_WRAPPER

	// EZ core
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

	// Not supported here, the all-in-one is wishbone access only
	assign btn_rpt_state  = 0;
	assign btn_rpt_change = 0;
	assign btn_rpt_stb    = 0;
`endif


	// SPI Flexible
	// ------------

	// This example uses the individual SPI core components
	// which is more flexible and allows multiple connections to the
	// protocol wrapper. Here there is a command decoder for the button
	// state reports and the wishbone interface.

`ifndef EZ_WRAPPER

	// Signals
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

	wire [3:0] pw_irq;
	wire       irq;

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
		.pw_irq        (pw_irq),
		.irq           (irq),
		.clk           (clk),
		.rst           (rst)
	);

	// Command decoder for the F4 command
	// (button state reports from ESP32)
	spi_dev_scmd #(
		.CMD_BYTE (8'hf4),
		.CMD_LEN  (4)
	) scmd_f4_I (
		.pw_wdata (pw_wdata),
		.pw_wcmd  (pw_wcmd),
		.pw_wstb  (pw_wstb),
		.pw_end   (pw_end),
		.cmd_data ({btn_rpt_state, btn_rpt_change}),
		.cmd_stb  (btn_rpt_stb),
		.clk      (clk),
		.rst      (rst)
	);

	// Wishbone bridge
	spi_dev_to_wb #(
		.WB_N(WN)
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

	assign pw_irq = 4'b0000;

	assign irq_n = irq ? 1'b0 : 1'bz;

`endif


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


	// SPRAM [1]
	// -----

	ice40_spram_wb #(
		.AW(14),
		.DW(32),
		.ZERO_RDATA(1)
	) spram_I (
		.wb_addr    (wb_addr[13:0]),
		.wb_rdata   (wb_rdata[1]),
		.wb_wdata   (wb_wdata),
		.wb_wmsk    (4'h0),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[1]),
		.wb_ack     (wb_ack[1]),
		.clk        (clk),
		.rst        (rst)
	);


	// UART
	// ----
	// Send key presses to UART for debug

	// Data Gen
	always @(posedge clk)
	begin
		// Data
		if (btn_rpt_stb) begin
			casez (btn_rpt_change[3:0])
				4'bzzz1: uart_data <= btn_rpt_state[0] ? "D" : "d";
				4'bzz1z: uart_data <= btn_rpt_state[1] ? "U" : "u";
				4'bz1zz: uart_data <= btn_rpt_state[2] ? "L" : "l";
				4'b1zzz: uart_data <= btn_rpt_state[3] ? "R" : "r";
				default: uart_data <= 8'hxx;
			endcase
		end

		// Valid
		uart_valid <= (uart_valid & ~uart_ack) | (btn_rpt_stb & |btn_rpt_change[3:0]);
	end

	// Core
	uart_tx #(
		.DIV_WIDTH(8)
	) uart_I (
		.tx    (uart_tx),
		.data  (uart_data),
		.valid (uart_valid),
		.ack   (uart_ack),
		.div   (8'd28), // 30M / (28 + 2) = 1 MBaud
		.clk   (clk),
		.rst   (rst)
	);

	// Clock/Reset Generation
	// ----------------------

	sysmgr sysmgr_I (
		.clk_in (clk_in),
		.clk    (clk),
		.rst    (rst)
	);

endmodule // top
