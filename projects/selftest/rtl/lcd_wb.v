/*
 * lcd_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module lcd_wb #(
	parameter [7:0] CMD_BYTE = 8'hf2
)(
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

	// SPI protocol wrapper interface
	input  wire  [7:0] pw_wdata,
	input  wire        pw_wcmd,
	input  wire        pw_wstb,

	input  wire        pw_end,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Bus
	wire       bus_clr;
	reg        bus_we_csr;
	reg        bus_we_mux;
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

	// SPI access
	reg        spi_active;
	reg  [1:0] spi_state;
	reg  [1:0] spi_state_nxt;

	reg  [8:0] spi_data_len;
	reg        spi_data_inf;
	wire       spi_data_last;

	reg  [7:0] spi_lcd_data;
	reg        spi_lcd_rs;
	reg        spi_lcd_valid;

	// PHY muxing
	reg        mux_sel;
	reg        mux_req;

	wire [7:0] pmux_data[0:1];
	wire       pmux_rs[0:1];
	wire       pmux_valid[0:1];


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
			wb_rdata <= wb_addr[0] ? { 30'h00000000, mux_sel, mux_req } : { cp_active_0, 31'h00000000 };

	// Write strobes
	always @(posedge clk)
		if (bus_clr) begin
			bus_we_csr <= 1'b0;
			bus_we_mux <= 1'b0;
			bus_we_mem <= 1'b0;
		end else begin
			bus_we_csr <= wb_we & ~wb_addr[9] & ~wb_addr[0];
			bus_we_mux <= wb_we & ~wb_addr[9] &  wb_addr[0];
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
	assign pmux_data[0]  = cp_data_1;
	assign pmux_rs[0]    = (cp_state_1 == ST_DATA);
	assign pmux_valid[0] = (cp_state_1 == ST_CMD) || (cp_state_1 == ST_DATA);


	// SPI pass-through
	// ----------------

	// SPI Command tracking
	always @(posedge clk)
		if (rst)
			spi_active <= 1'b0;
		else
			spi_active <= (spi_active | (pw_wstb & pw_wcmd & (pw_wdata == CMD_BYTE))) & ~pw_end;

	// State tracking
	always @(posedge clk or posedge rst)
		if (rst)
			spi_state <= ST_LEN;
		else if (pw_wstb)
			spi_state <= spi_state_nxt;

	always @(*)
	begin
		// Default sequence
		case (spi_state)
			ST_LEN:  spi_state_nxt = ST_CMD;
			ST_CMD:  spi_state_nxt = spi_data_last ? ST_LEN : ST_DATA;
			ST_DATA: spi_state_nxt = spi_data_last ? ST_LEN : ST_DATA;
			default: spi_state_nxt = spi_state;
		endcase

		// Reset
		if (pw_wcmd)
			spi_state_nxt = ST_LEN;
	end

	// Data length tracking
	always @(posedge clk or posedge rst)
	begin
		if (rst) begin
			spi_data_len <= 0;
			spi_data_inf <= 1'b0;
		end else if (pw_wstb) begin
			spi_data_len <= ((spi_state == ST_LEN) ? { 1'b0, pw_wdata } : spi_data_len) - 1;
			spi_data_inf <=  (spi_state == ST_LEN) ? &pw_wdata : spi_data_inf;
		end
	end

	assign spi_data_last = spi_data_len[8] & ~spi_data_inf;

	// Register data
	always @(posedge clk)
		if (pw_wstb) begin
			spi_lcd_data <= pw_wdata;
			spi_lcd_rs   <= spi_state == ST_DATA;
		end

	always @(posedge clk)
		spi_lcd_valid <=
			(spi_lcd_valid & ~phy_ready) |
			(pw_wstb & spi_active & (
				(spi_state == ST_CMD) |
				(spi_state == ST_DATA)
			));

	// PHY control
	assign pmux_data[1]  = spi_lcd_data;
	assign pmux_rs[1]    = spi_lcd_rs;
	assign pmux_valid[1] = spi_lcd_valid;


	// PHY Muxing
	// ----------

	// Control register
	always @(posedge clk)
		if (rst)
			mux_req <= 1'b0;
		else
			mux_req <= (bus_we_mux & wb_wdata[0]) | (~bus_we_mux & mux_req);

	always @(posedge clk)
		if (rst)
			mux_sel <= 1'b0;
		else
			mux_sel <= (spi_active | cp_active_0 | phy_valid) ? mux_sel : mux_req;

	// Actual muxing
	assign phy_data  = pmux_data[mux_sel];
	assign phy_rs    = pmux_rs[mux_sel];
	assign phy_valid = pmux_valid[mux_sel];

endmodule // lcd_wb
