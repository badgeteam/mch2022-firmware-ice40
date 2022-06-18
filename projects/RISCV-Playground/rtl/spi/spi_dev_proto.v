/*
 * spi_dev_proto.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spi_dev_proto #(
	parameter integer NO_RESP = 0	// Disable responses support, saves a BRAM
)(
	// Interface to raw core
	input  wire [7:0] usr_mosi_data,
	input  wire       usr_mosi_stb,

	output wire [7:0] usr_miso_data,
	input  wire       usr_miso_ack,

	input  wire       csn_state,
	input  wire       csn_rise,
	input  wire       csn_fall,

	// Protocol wrapper interface
		// Write/Request IF
	output wire [7:0] pw_wdata,
	output wire       pw_wcmd,
	output wire       pw_wstb,

	output wire       pw_end,

		// Read/Response IF
	input  wire       pw_req,
	output reg        pw_gnt,

	input  wire [7:0] pw_rdata,
	input  wire       pw_rstb,

		// IRQ status bits and IRQ output
	input  wire [3:0] pw_irq,
	output reg        irq,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam [7:0] CMD_NOP      = 8'hff;
	localparam [7:0] CMD_RESP_ACK = 8'hfe;


	// Signals
	// -------

	// SPI Dev core IF
	reg        sd_first_rx;
	reg        sd_first_tx;
	reg        sd_cmd_is_resp_ack;
	reg        sd_was_resp_valid;

	wire [7:0] sd_status;

	// Response buffer
	reg        rb_wbuf;
	reg  [7:0] rb_waddr;
	wire [7:0] rb_wdata;
	wire       rb_wena;

	reg        rb_rbuf;
	reg  [7:0] rb_raddr;
	wire [7:0] rb_rdata;
	wire       rb_rena;

	// Response "FIFO"
	reg        rf_push;
	reg        rf_pop;

	reg  [1:0] rf_cnt;
	reg        rf_full;
	reg        rf_valid;

	// Misc
	reg        has_resp_data;


	// SPI dev core IF
	// ---------------

	// Track first RX/TX bytes
	always @(posedge clk)
		if (rst) begin
			sd_first_tx <= 1'b1;
			sd_first_rx <= 1'b1;
		end else begin
			sd_first_tx <= (sd_first_tx & ~usr_miso_ack) | csn_rise;
			sd_first_rx <= (sd_first_rx & ~usr_mosi_stb) | csn_rise;
		end

	// MISO data
	assign usr_miso_data = sd_first_tx ? sd_status : rb_rdata;

	// Status byte
	assign sd_status = {
		rf_valid,	//   [7] Response pending
		3'b000,		// [6:4] RFU
		pw_irq		// [3:0] IRQs status
	};

	// Read from response data buffer
	always @(posedge clk)
		rb_raddr <= (rb_raddr + usr_miso_ack) & {8{~csn_state}};

	assign rb_rena = usr_miso_ack;

	// Dequeue response
	always @(posedge clk)
		if (usr_mosi_stb & sd_first_rx)
			sd_cmd_is_resp_ack <= usr_mosi_data == CMD_RESP_ACK;

	always @(posedge clk)
		if (usr_miso_ack & sd_first_tx)
			sd_was_resp_valid <= rf_valid;

	always @(posedge clk)
		rf_pop <= csn_rise & sd_cmd_is_resp_ack & sd_was_resp_valid;

	// IRQ handling
	always @(posedge clk)
		irq <= |pw_irq;


	// Response buffer
	// ---------------

	// Data
	if (NO_RESP == 0)
		ram_sdp #(
			.AWIDTH(9),
			.DWIDTH(8)
		) resp_buf_I (
			.wr_addr ({rb_wbuf, rb_waddr}),
			.wr_data (rb_wdata),
			.wr_ena  (rb_wena),
			.rd_addr ({rb_rbuf, rb_raddr}),
			.rd_data (rb_rdata),
			.rd_ena  (rb_rena),
			.clk     (clk)
		);

	// Ping-pong logic
	always @(posedge clk)
		if (rst | NO_RESP) begin
			rf_cnt   <= 2'b00;
			rf_full  <= 1'b0;
			rf_valid <= 1'b0;
		end else begin
			casez ({rf_push, rf_pop, rf_cnt})
				// No move
				4'b00zz: { rf_full, rf_valid, rf_cnt } <= { rf_cnt[1], |rf_cnt, rf_cnt };

				// Pop only
				4'b0100: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b0, 2'b00 }; // Shouldn't happen
				4'b0101: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b0, 2'b00 };
				4'b0110: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b1, 2'b01 };

				// Push only
				4'b1000: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b1, 2'b01 };
				4'b1001: { rf_full, rf_valid, rf_cnt } <= { 1'b1, 1'b1, 2'b10 };
				4'b1010: { rf_full, rf_valid, rf_cnt } <= { 1'b1, 1'b1, 2'b10 }; // Shouldn't happen

				// Push/pop
				4'b1100: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b1, 2'b01 }; // Shouldn't happen
				4'b1101: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b1, 2'b01 };
				4'b1110: { rf_full, rf_valid, rf_cnt } <= { 1'b0, 1'b1, 2'b01 }; // Shouldn't happen

				// Catch-all
				default: { rf_full, rf_valid, rf_cnt } <= { 1'bx, 1'bx, 2'bxx };
			endcase
		end

	always @(posedge clk)
		if (rst) begin
			rb_wbuf <= 1'b0;
			rb_rbuf <= 1'b0;
		end else begin
			rb_wbuf <= rb_wbuf ^ (rf_push & ~rf_full);
			rb_rbuf <= rb_rbuf ^ (rf_pop  &  rf_valid);
		end


	// Write/Request IF
	// ----------------

	assign pw_wdata = usr_mosi_data;
	assign pw_wcmd  = sd_first_rx;
	assign pw_wstb  = usr_mosi_stb;
	assign pw_end   = csn_rise;


	// Read/Response IF
	// ----------------

	// Request / Grant
	always @(posedge clk)
		pw_gnt <= pw_req & ~rf_full & ~rf_push;

	always @(posedge clk)
		rf_push <= pw_gnt & ~pw_req & has_resp_data;

	// Write to buffer
	always @(posedge clk)
		rb_waddr <= (rb_waddr + pw_rstb) & {8{pw_gnt}};

	assign rb_wdata = pw_rdata;
	assign rb_wena  = pw_rstb;

	// Any data ?
	always @(posedge clk)
		has_resp_data <= (has_resp_data | pw_rstb) & pw_req;

endmodule // spi_dev_proto
