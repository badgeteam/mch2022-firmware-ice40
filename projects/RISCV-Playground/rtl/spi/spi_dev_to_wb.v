/*
 * spi_dev_to_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_to_wb #(
	parameter integer WB_N = 3,
	parameter [7:0] CMD_BYTE = 8'hf0,

	// auto
	parameter integer DL = (32*WB_N)-1,
	parameter integer CL = WB_N-1
)(
	// Protocol wrapper interface
	input  wire  [7:0] pw_wdata,
	input  wire        pw_wcmd,
	input  wire        pw_wstb,

	input  wire        pw_end,

	output wire        pw_req,
	input  wire        pw_gnt,

	output wire  [7:0] pw_rdata,
	output wire        pw_rstb,

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

	// FSM
	localparam [1:0]
		ST_IDLE = 0,
		ST_ADDR = 1,
		ST_DATA = 2,
		ST_WAIT = 3;

	reg   [1:0] state;
	reg   [1:0] state_nxt;

	// Control
	wire        ctrl_cmd_match;
	reg         ctrl_active;
	wire        ctrl_complete;
	reg   [2:0] ctrl_mode;
	reg         ctrl_data_ld;
	reg         ctrl_addr_ld;
	reg         ctrl_addr_inc;
	reg         ctrl_addr_ce;
	reg         ctrl_addr_first;

	// Write Shift
	reg  [31:0] ws_data;
	reg   [1:0] ws_cnt;
	wire        ws_cnt_last;

	// Wishbone control
	reg  [31:0] wb_rdata_i;
	reg  [31:0] wb_rdata_r;

	reg  [CL:0] wb_cyc_pre;
	wire        wb_ack_i;
	reg         wb_ack_r;


	// Control
	// -------

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next-state logic
	always @(*)
	begin
		// Default is to stay put
		state_nxt = state;

		// Transitions
		case (state)
			ST_IDLE:
				if (pw_wstb & ctrl_cmd_match)
					state_nxt = ST_ADDR;

			ST_ADDR:
				if (pw_wstb & ws_cnt_last)
					state_nxt = ST_DATA;
				else if (ctrl_complete)
					state_nxt = ST_IDLE;

			ST_DATA:
				if (pw_wstb & ws_cnt_last)
					state_nxt = ST_WAIT;
				else if (ctrl_complete)
					state_nxt = ST_IDLE;

			ST_WAIT:
				if (wb_ack_r)
					state_nxt = ctrl_mode[1] ? ST_ADDR : ST_DATA;

		endcase
	end

	// Misc control signals
	assign ctrl_cmd_match = pw_wcmd & (pw_wdata == CMD_BYTE);

	always @(posedge clk)
		ctrl_active <= (ctrl_active & ~pw_end) | (pw_wstb & ctrl_cmd_match);

	assign ctrl_complete = ~ctrl_active & ~rs_valid[3];

	always @(posedge clk)
	begin
		ctrl_data_ld <= pw_wstb & ws_cnt_last & (state == ST_DATA);
		ctrl_addr_ld <= pw_wstb & ws_cnt_last & (state == ST_ADDR);
		ctrl_addr_ce <= pw_wstb & ws_cnt_last & (
				(state == ST_ADDR) |
				((state == ST_DATA) & ~ctrl_addr_first & (ctrl_mode[1:0] == 2'b01))
			);
		ctrl_addr_first <= (ctrl_addr_first | ctrl_addr_ld) & ~ctrl_data_ld;
	end

	// Latch mode
	always @(posedge clk)
		if (ctrl_addr_ld)
			ctrl_mode <= ws_data[31:29];

	// Request
	assign pw_req = (state != ST_IDLE);


	// Shift registers
	// ---------------

	// Write shift reg
	always @(posedge clk)
		if (pw_wstb)
			ws_data <= { ws_data[23:0], pw_wdata };

	always @(posedge clk)
		if (state == ST_IDLE)
			ws_cnt <= 2'b00;
		else
			ws_cnt <= {
				ws_cnt[1] ^ (pw_wstb & ws_cnt[0]),
				ws_cnt[0] ^  pw_wstb
			};

	assign ws_cnt_last = (ws_cnt == 2'b11);

	// Read shift reg
	reg [31:0] rs_data;
	reg  [3:0] rs_valid;

	always @(posedge clk)
		if (wb_ack_r) begin
			rs_data  <= wb_rdata_r;
			rs_valid <= {4{~ctrl_mode[2] | (ctrl_mode[1:0] == 2'b11)}};
		end else begin
			rs_data  <= { rs_data[23:0], 8'h00 };
			rs_valid <= { rs_valid[2:0],  1'b0 };
		end

	assign pw_rdata = rs_data[31:24];
	assign pw_rstb  = rs_valid[3];


	// Wishbone
	// --------

	// Write data
	always @(posedge clk)
		if (ctrl_data_ld)
			wb_wdata <= ws_data;

	// Read data
	always @(*)
	begin : rdata
		integer i;

		wb_rdata_i = 32'h00000000;

		for (i=0; i<WB_N; i=i+1)
			wb_rdata_i = wb_rdata_i | wb_rdata[32*i+:32];
	end

	always @(posedge clk)
		wb_rdata_r <= wb_rdata_i;

	// Address
	always @(posedge clk)
		if (ctrl_addr_ce)
			// Written to gain 21 LCs on iCE40 'cause synth ain't that smart
			wb_addr <= ctrl_addr_ld ? ws_data : (wb_addr + {32{ctrl_addr_ld}} + (!ctrl_addr_ld));
			//wb_addr <= ctrl_addr_ld ? ws_data : (wb_addr + 1);

	// Write Enable
	assign wb_we = ctrl_mode[2];

	// Pre-decode
	always @(posedge clk)
		if (ctrl_addr_ld) begin
			wb_cyc_pre <= 1 << ws_data[27:24];
		end

	// Cycle
	always @(posedge clk)
		if (rst)
			wb_cyc <= 0;
		else
			wb_cyc <= (wb_cyc | (wb_cyc_pre & {WB_N{ctrl_data_ld}})) & ~wb_ack;

	// Ack register
	assign wb_ack_i = |wb_ack;

	always @(posedge clk)
		wb_ack_r <= wb_ack_i;

endmodule // spi_dev_to_wb
