/*
 * spi_dev_to_wb_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module spi_dev_to_wb_tb;

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;

	reg   [7:0] pw_wdata;
	reg         pw_wcmd;
	reg         pw_wstb;
	reg         pw_end;

	wire [31:0] wb_wdata;
	wire [95:0] wb_rdata;
	wire [23:0] wb_addr;
	wire        wb_we;
	wire  [2:0] wb_cyc;
	reg   [2:0] wb_ack;

	// Setup recording
	initial begin
		$dumpfile("spi_dev_to_wb_tb.vcd");
		$dumpvars(0,spi_dev_to_wb_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk = !clk;

	// DUT
	spi_dev_to_wb #(
		.WB_N(3)
	) dut_I (
		.pw_wdata (pw_wdata),
		.pw_wcmd  (pw_wcmd),
		.pw_wstb  (pw_wstb),
		.pw_end   (pw_end),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata),
		.wb_addr  (wb_addr),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.clk      (clk),
		.rst      (rst)    
	);

	// Fake WB responder
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	assign wb_rdata[31: 0] = (~wb_we & wb_ack[0]) ? 32'h600dbabe : 32'h00000000;
	assign wb_rdata[63:32] = (~wb_we & wb_ack[1]) ? 32'hbaadbabe : 32'h00000000;
	assign wb_rdata[95:64] = (~wb_we & wb_ack[2]) ? 32'hcafebabe : 32'h00000000;

	// Stimulus
	task pw_write;
		input       cmd;
		input [7:0] data;
		begin

			pw_wdata <= data;
			pw_wcmd  <= cmd;
			pw_wstb  <= 1'b1;

			@(posedge clk);

			pw_wdata <= 8'hxx;
			pw_wcmd  <= 1'bx;
			pw_wstb  <= 1'b0;

			@(posedge clk);
			@(posedge clk);

		end
	endtask

	initial begin
		// Default
		pw_wdata <= 8'hxx;
		pw_wcmd  <= 1'bx;
		pw_wstb  <= 1'b0;
		pw_end   <= 1'b0;

		// Wait for reset
		@(negedge rst);
		@(posedge clk);

		// Issue command
		pw_write(1, 8'hf0);

		pw_write(1, 8'ha1); // Mode W, Auto-increment, Device 1
		pw_write(1, 8'h12);
		pw_write(1, 8'h34);
		pw_write(1, 8'h56);

		pw_write(1, 8'hb0);
		pw_write(1, 8'h0b);
		pw_write(1, 8'h1e);
		pw_write(1, 8'h50);

		pw_write(1, 8'hca);
		pw_write(1, 8'hfe);
		pw_write(1, 8'hba);
		pw_write(1, 8'hbe);

		@(posedge clk);
		pw_end <= 1'b1;
		@(posedge clk);
		pw_end <= 1'b0;

		// Issue command
		pw_write(1, 8'hf0);

		pw_write(0, 8'h82); // Mode W, No-increment, Device 2
		pw_write(0, 8'h12);
		pw_write(0, 8'h34);
		pw_write(0, 8'h56);

		pw_write(0, 8'hb0);
		pw_write(0, 8'h0b);
		pw_write(0, 8'h1e);
		pw_write(0, 8'h50);

		pw_write(0, 8'hca);
		pw_write(0, 8'hfe);
		pw_write(0, 8'hba);
		pw_write(0, 8'hbe);

		@(posedge clk);
		pw_end <= 1'b1;
		@(posedge clk);
		pw_end <= 1'b0;

		// Issue command
		pw_write(1, 8'hf0);

		pw_write(0, 8'hc2); // Mode W, Re-address, Device 2
		pw_write(0, 8'h22);
		pw_write(0, 8'h22);
		pw_write(0, 8'h22);

		pw_write(0, 8'hb0);
		pw_write(0, 8'h0b);
		pw_write(0, 8'h1e);
		pw_write(0, 8'h50);

		pw_write(0, 8'hc0); // Mode W, Re-address, Device 0
		pw_write(0, 8'h11);
		pw_write(0, 8'h11);
		pw_write(0, 8'h11);

		pw_write(0, 8'hca);
		pw_write(0, 8'hfe);
		pw_write(0, 8'hba);
		pw_write(0, 8'hbe);

		pw_write(0, 8'h40); // Mode R, Re-address, Device 0
		pw_write(0, 8'h11);
		pw_write(0, 8'h11);
		pw_write(0, 8'h11);

		pw_write(0, 8'hca);
		pw_write(0, 8'hfe);
		pw_write(0, 8'hba);
		pw_write(0, 8'hbe);

		@(posedge clk);
		pw_end <= 1'b1;
		@(posedge clk);
		pw_end <= 1'b0;
	end

endmodule // spi_dev_to_wb_tb
