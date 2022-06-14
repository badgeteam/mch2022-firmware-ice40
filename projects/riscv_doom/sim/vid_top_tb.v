/*
 * vid_top_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`timescale 1 ns / 100 ps
`default_nettype none

module vid_top_tb;

	// Signals
	// -------

	// LCD signals
	wire [7:0] lcd_d;
	wire       lcd_rs;
	wire       lcd_wr_n;
	wire       lcd_cs_n;
	wire       lcd_mode;
	wire       lcd_rst_n;
	wire       lcd_fmark;

	reg [19:0] fmark_cnt;

	// Wishbone bus
	reg  [15:0] wb_addr;
	wire [31:0] wb_rdata;
	reg  [31:0] wb_wdata;
	reg         wb_cyc;
	reg         wb_we;
	wire        wb_ack;

	// Clock / Reset
	reg         clk = 1'b0;
	reg         rst = 1'b1;


	// Setup recording
	// ---------------

	initial begin
		$dumpfile("vid_top_tb.vcd");
		$dumpvars(0,vid_top_tb);
		# 20000000 $finish;
	end


	// Clock / Reset
	// -------------

	initial begin
		# 200 rst = 0;
	end

	always #16.6 clk = !clk;


	// DUT
	// ---

	vid_top dut_I (
		.lcd_d     (lcd_d),
		.lcd_rs    (lcd_rs),
		.lcd_wr_n  (lcd_wr_n),
		.lcd_cs_n  (lcd_cs_n),
		.lcd_mode  (lcd_mode),
		.lcd_rst_n (lcd_rst_n),
		.lcd_fmark (lcd_fmark),
		.wb_addr   (wb_addr),
		.wb_rdata  (wb_rdata),
		.wb_wdata  (wb_wdata),
		.wb_wmsk   (4'h0),
		.wb_we     (wb_we),
		.wb_cyc    (wb_cyc),
		.wb_ack    (wb_ack),
		.clk       (clk),
		.rst       (rst)
	);


    pullup(lcd_cs_n);
    pullup(lcd_rst_n);

	assign lcd_mode = 1'b1;

	always @(posedge clk)
		if (rst)
			fmark_cnt <= 20'hff000;
		else
			fmark_cnt <= fmark_cnt + 1;
	
	assign lcd_fmark = &fmark_cnt[19:8];


	// Commands
	// --------

	task wb_write;
		input [15:0] addr;
		input [31:0] data;
		begin
			wb_addr  <= addr;
			wb_wdata <= data;
			wb_we    <= 1'b1;
			wb_cyc   <= 1'b1;

			while (~wb_ack)
				@(posedge clk);

			wb_addr  <= 4'hx;
			wb_wdata <= 32'hxxxxxxxx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;

			@(posedge clk);
		end
	endtask

	initial begin
		// Defaults
		wb_addr  <= 16'hxxxx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		// Wait for reset
		@(negedge rst);
		@(posedge clk);

		// Issue commands
		repeat (20)
			@(posedge clk);

		wb_write(16'h0000, 32'h00010000);
		wb_write(16'h0001, 32'hc000002c);

		wb_write(16'h8000, 32'h01020304);
		wb_write(16'h9040, 32'h05060708);

		wb_write(16'h4000, 32'h00ff0000);
		wb_write(16'h4001, 32'h0000ff00);
		wb_write(16'h4002, 32'h00ffff00);
		wb_write(16'h4003, 32'h000000ff);



	end

endmodule // vid_top_tb
