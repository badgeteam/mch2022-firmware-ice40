/*
 * lcd_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module lcd_wb (
	// LCD PHY
	output wire  [7:0] phy_data,
	output wire        phy_rs,
	output wire        phy_valid,
	input  wire        phy_ready,

	input  wire        phy_fmark_stb,

	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire  [9:0] wb_addr,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Bus
	wire       bus_clr;
	reg        bus_we_csr;
	reg        bus_we_mem;

	// RAM
	wire [8:0] mw_addr;
	wire [7:0] mw_data;
	wire       mw_ena;

	wire [8:0] mr_addr;
	wire [7:0] mr_data;
	wire       mr_ena;

	// Command player
	wire       cp_ce_0;
	wire       cp_active_0;
	reg  [8:0] cp_addr_0;
	reg  [9:0] cp_len_0;

	wire       cp_ce_1;
	wire [7:0] cp_data_1;
	reg        cp_valid_1;

	reg  [1:0] cp_state_1;
	reg  [1:0] cp_state_nxt_1;
	reg  [8:0] cp_data_len_1;

	localparam [1:0]
		ST_LEN  = 2'b00,
		ST_CMD  = 2'b10,
		ST_DATA = 2'b11;
	

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
			wb_rdata <= { cp_active_0, 31'h00000000 };

	// Write strobes
	always @(posedge clk)
		if (bus_clr) begin
			bus_we_csr <= 1'b0;
			bus_we_mem <= 1'b0;
		end else begin
			bus_we_csr <= wb_we & ~wb_addr[9];
			bus_we_mem <= wb_we &  wb_addr[9];
		end


	// Memory
	// ------

	// Bus writes
	assign mw_addr = wb_addr[8:0];
	assign mw_data = wb_wdata[7:0];
	assign mw_ena  = bus_we_mem;

	// Instance
	ram_sdp #(
		.AWIDTH(9),
		.DWIDTH(8)
	) mem_I (
		.wr_addr (mw_addr),
		.wr_data (mw_data),
		.wr_ena  (mw_ena),
		.rd_addr (mr_addr),
		.rd_data (mr_data),
		.rd_ena  (mr_ena),
		.clk     (clk)
	);


	// Command Player
	// --------------

	// Pipeline control
	assign cp_ce_0 = bus_we_csr | (cp_active_0 & cp_ce_1);
	assign cp_ce_1 = cp_valid_1 ? (phy_ready | ~phy_valid) : 1'b1;

	// Stage 0: Length
	always @(posedge clk or posedge rst)
		if (rst) begin
			cp_addr_0 <= 0;
			cp_len_0  <= 0;
		end else if (cp_ce_0) begin
			cp_addr_0 <= bus_we_csr ? wb_wdata[8:0]            : (cp_addr_0 + 1);
			cp_len_0  <= bus_we_csr ? {1'b1, wb_wdata[24:16] } : (cp_len_0  - 1);
		end

	assign cp_active_0 = cp_len_0[9];

	// Stage 1: Memory read
	assign mr_ena  = cp_ce_1;
	assign mr_addr = cp_addr_0;
	assign cp_data_1 = mr_data;

	always @(posedge clk or posedge rst)
		if (rst)
			cp_valid_1 <= 1'b0;
		else if (cp_ce_1)
			cp_valid_1 <= cp_active_0;

	// Stage 1: State tracking
	always @(posedge clk or posedge rst)
		if (rst)
			cp_state_1 <= ST_LEN;
		else if (cp_ce_1)
			cp_state_1 <= cp_state_nxt_1;

	always @(*)
	begin
		// Default sequence
		case (cp_state_1)
			ST_LEN:  cp_state_nxt_1 = ST_CMD;
			ST_CMD:  cp_state_nxt_1 = cp_data_len_1[8] ? ST_LEN : ST_DATA;
			ST_DATA: cp_state_nxt_1 = cp_data_len_1[8] ? ST_LEN : ST_DATA;
			default: cp_state_nxt_1 = cp_state_1;
		endcase

		// Reset
		if (~cp_valid_1)
			cp_state_nxt_1 = ST_LEN;
	end

	always @(posedge clk or posedge rst)
	begin
		if (rst)
			cp_data_len_1 <= 0;
		else if (cp_ce_1)
			cp_data_len_1 <= ((cp_state_1 == ST_LEN) ? { 1'b0, cp_data_1 } : cp_data_len_1) - 1;
	end

	// Stage 1: PHY control
	assign phy_data  = cp_data_1;
	assign phy_rs    = (cp_state_1 == ST_DATA);
	assign phy_valid = (cp_state_1 == ST_CMD) || (cp_state_1 == ST_DATA);

endmodule // lcd_wb
