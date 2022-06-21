/*
 * spi_dev_fread.v
 *
 * vim: ts=4 sw=4
 *
 * "fread" command support allowing the FPGA to request some
 * data from file from the ESP32.
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_fread #(
	parameter INTERFACE = "STREAM",	// "STREAM", "FIFO", "RAM"
	parameter integer BUFFER_DEPTH = 512, // for "FIFO" and "RAM" modes
	parameter [7:0] CMD_GET_BYTE = 8'hf8,
	parameter [7:0] CMD_PUT_BYTE = 8'hf9,

	// auto-set
	parameter integer BL = $clog2(BUFFER_DEPTH) - 1
)(
	// Protocol wrapper interface
	input  wire  [7:0] pw_wdata,
	input  wire        pw_wcmd,
	input  wire        pw_wstb,

	input  wire        pw_end,

	output wire        pw_req,
	input  wire        pw_gnt,

	output reg   [7:0] pw_rdata,
	output reg         pw_rstb,

	// External status indicator
	output wire        pw_irq,

	// "fread" request submit interface
	input  wire [31:0] req_file_id,
	input  wire [31:0] req_offset,
	input  wire [10:0] req_len,
	input  wire        req_valid,
	output wire        req_ready,

	// "fread" response stream/fifo interface
	output wire  [7:0] resp_data,
	output wire        resp_valid,
	input  wire        resp_ready, // Only used for "FIFO"

	// "fread" response RAM interface
	output reg         resp_done,
	output wire  [7:0] resp_rdata_1,
	input  wire [BL:0] resp_raddr_0,
	input  wire        resp_ren_0,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	reg       cmd_stb_get;
	reg       cmd_stb_put;
	reg       cmd_active_get;
	reg       cmd_active_put;

	reg [3:0] tx_sel;
	wire      tx_sel_valid;
	wire      tx_stb;


	// Command decoder
	// ---------------

	// Command match
	always @(posedge clk)
	begin
		cmd_stb_get <= pw_wstb & pw_wcmd & (pw_wdata == CMD_GET_BYTE);
		cmd_stb_put <= pw_wstb & pw_wcmd & (pw_wdata == CMD_PUT_BYTE);
	end

	// Command active tracking
	always @(posedge clk)
		if (rst) begin
			cmd_active_get <= 1'b0;
			cmd_active_put <= 1'b0;
		end else begin
			cmd_active_get <= (cmd_active_get & ~pw_end) | cmd_stb_get;
			cmd_active_put <= (cmd_active_put & ~pw_end) | cmd_stb_put;
		end


	// Send requests
	// -------------

	// Signal request upstream
	assign pw_irq = req_valid;

	// Request access to response buffer
	assign pw_req = cmd_active_get;

	// Ack request when sent
	assign req_ready = pw_end & cmd_active_get;

	// Write control
	always @(posedge clk)
	begin
		if (~pw_gnt)
			tx_sel <= 4'h0;
		else
			tx_sel <= tx_sel + tx_sel_valid;
	end

	assign tx_sel_valid = (tx_sel <= 4'h9);
	assign tx_stb = pw_gnt & tx_sel_valid;

	// Mux (should actually be smaller than a shift reg)
	always @(posedge clk)
	begin
		// Mux itself
		casez (tx_sel)
			4'h0:    pw_rdata <= req_file_id[31:24];
			4'h1:    pw_rdata <= req_file_id[23:16];
			4'h2:    pw_rdata <= req_file_id[15: 8];
			4'h3:    pw_rdata <= req_file_id[ 7: 0];
			4'h4:    pw_rdata <= req_offset[31:24];
			4'h5:    pw_rdata <= req_offset[23:16];
			4'h6:    pw_rdata <= req_offset[15: 8];
			4'h7:    pw_rdata <= req_offset[ 7: 0];
			4'h8:    pw_rdata <= { 5'b00000, req_len[10:8] };
			4'h9:    pw_rdata <= req_len[7:0];
			default: pw_rdata <= 8'hxx;
		endcase

		// Pipe for write signal
		pw_rstb <= tx_stb;
	end


	// Response interfaces
	// -------------------

	generate

		// Stream
		// ------

		if (INTERFACE == "STREAM")
		begin

			// Direct forward
			assign resp_data  = pw_wdata;
			assign resp_valid = cmd_active_put & pw_wstb;

		end


		// FIFO
		// ----

		if (INTERFACE == "FIFO")
		begin : fifo

			// Local signals
			wire [7:0] rf_wrdata;
			wire       rf_wren;
			wire       rf_full;

			wire [7:0] rf_rddata;
			wire       rf_rden;
			wire       rf_empty;

			// Write
			assign rf_wrdata = pw_wdata;
			assign rf_wren = ~rf_full & cmd_active_put & pw_wstb;

			// Instance
			fifo_sync_ram #(
				.DEPTH(BUFFER_DEPTH),
				.WIDTH(8)
			) fifo_I (
				.wr_data  (rf_wrdata),
				.wr_ena   (rf_wren),
				.wr_full  (rf_full),
				.rd_data  (rf_rddata),
				.rd_ena   (rf_rden),
				.rd_empty (rf_empty),
				.clk      (clk),
				.rst      (rst)
			);

			// Read
			assign resp_data  =  rf_rddata;
			assign resp_valid = ~rf_empty;
			assign rf_rden = ~rf_empty & resp_ready;

		end


		// RAM
		// ---

		if (INTERFACE == "RAM")
		begin

			// Local signals
			reg [BL:0] rr_wraddr;
			wire [7:0] rr_wrdata;
			wire       rr_wren;

			// State tracking
			always @(posedge clk)
				if (rst)
					resp_done <= 1'b0;
				else
					resp_done <= (resp_done & ~(req_valid & req_ready)) | (cmd_active_put & pw_end);

			// Write
			assign rr_wrdata = pw_wdata;
			assign rr_wren   = pw_wstb & cmd_active_put;

			always @(posedge clk)
				if (cmd_stb_put)
					rr_wraddr <= 0;
				else
					rr_wraddr <= rr_wraddr + pw_wstb;

			// RAM instance
			ram_sdp #(
				.AWIDTH(BL+1),
				.DWIDTH(8)
			) ram_I (
				.wr_addr (rr_wraddr),
				.wr_data (rr_wrdata),
				.wr_ena  (rr_wren),
				.rd_addr (resp_raddr_0),
				.rd_data (resp_rdata_1),
				.rd_ena  (resp_ren_0),
				.clk     (clk)
			);

		end

	endgenerate

endmodule // spi_dev_fread
