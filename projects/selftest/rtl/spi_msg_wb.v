/*
 * spi_msg_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_msg_wb #(
	parameter [7:0] CMD_BYTE = 8'h10
)(
	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire  [1:0] wb_addr,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// SPI protocol wrapper interface
	input  wire  [7:0] pw_wdata,
	input  wire        pw_wcmd,
	input  wire        pw_wstb,

	input  wire        pw_end,

	output reg         pw_req,
	input  wire        pw_gnt,

	output wire  [7:0] pw_rdata,
	output wire        pw_rstb,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Bus
	wire        bus_clr;
	reg         bus_we_csr;
	reg         bus_we_data;
	reg         bus_re_data;

	wire [31:0] bus_rd_csr;
	wire [31:0] bus_rd_data;

	// SPI -> CPU FIFO
	wire  [7:0] scf_wdata;
	wire        scf_wen;
	wire        scf_full;

	wire  [7:0] scf_rdata;
	wire        scf_ren;
	wire        scf_empty;

	// SPI
	reg         spi_active;
	reg         spi_cmd_pending;


	// Bus interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	// Clear
	assign bus_clr = ~wb_cyc | wb_ack;

	// Read Mux
	always @(posedge clk)
		if (bus_clr)
			wb_rdata <= 32'h00000000;
		else
			wb_rdata <= wb_addr[0] ? bus_rd_data : bus_rd_csr;

	// Strobes
	always @(posedge clk)
		if (bus_clr) begin
			bus_we_csr  <= 1'b0;
			bus_we_data <= 1'b0;
			bus_re_data <= 1'b0;
		end else begin
			bus_we_csr  <=  wb_we & ~wb_addr[0];
			bus_we_data <=  wb_we &  wb_addr[0];
			bus_re_data <= ~wb_we &  wb_addr[0];
		end

	// CSR
	assign bus_rd_csr = {
		24'h000000,
		2'b00,
		pw_gnt,
		spi_cmd_pending
	};

	// FIFO reads
	assign bus_rd_data = {
		scf_empty,
		23'h000000,
		scf_rdata
	};

	assign scf_ren = bus_re_data & ~wb_rdata[31];


	// FIFO
	// ----

	// Instance
	fifo_sync_ram #(
		.DEPTH(512),
		.WIDTH(8)
	) fifo_I (
		.wr_data  (scf_wdata),
		.wr_ena   (scf_wen),
		.wr_full  (scf_full),
		.rd_data  (scf_rdata),
		.rd_ena   (scf_ren),
		.rd_empty (scf_empty),
		.clk      (clk),
		.rst      (rst)
	);


	// SPI pass-through
	// ----------------

	// SPI Command tracking
	always @(posedge clk)
		if (rst)
			spi_active <= 1'b0;
		else
			spi_active <= (spi_active | (pw_wstb & pw_wcmd & (pw_wdata == CMD_BYTE))) & ~pw_end;

	// Write to FIFO
	assign scf_wdata = pw_wdata;
	assign scf_wen   = pw_wstb & spi_active & ~scf_full;

	// Command Pending flag
	always @(posedge clk)
		if (rst)
			spi_cmd_pending <= 1'b0;
		else
			spi_cmd_pending <= (spi_cmd_pending & ~(bus_we_csr & wb_wdata[0])) | scf_wen;

	// Response writes from CPU
	always @(posedge clk)
		if (rst)
			pw_req <= 1'b0;
		else
			pw_req <= (pw_req & ~(bus_we_csr & wb_wdata[3])) | (bus_we_csr & wb_wdata[2]);

	assign pw_rdata = wb_wdata[7:0];
	assign pw_rstb  = bus_we_data;

endmodule // spi_msg_wb
