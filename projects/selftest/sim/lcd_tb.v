/*
 * lcd_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Test bench for the LCD modules
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module lcd_tb;

	// Signals
	// -------

	// LCD signals
	wire [7:0] lcd_d;
	wire       lcd_rs;
	wire       lcd_wr_n;
	wire       lcd_fmark;

	// LCD PHY
	wire  [7:0] lcd_phy_data;
	wire        lcd_phy_rs;
	wire        lcd_phy_valid;
	wire        lcd_phy_ready;
	wire        lcd_phy_fmark_stb;

	// Wishbone bus
	reg  [15:0] wb_addr;
	wire [31:0] wb_rdata;
	reg  [31:0] wb_wdata;
	reg         wb_cyc;
	reg         wb_we;
	wire        wb_ack;

	// Protocol Wrapper IF
	reg   [7:0] pw_wdata;
	reg         pw_wcmd;
	reg         pw_wstb;
	reg         pw_end;

	// Clock / Reset
	reg         clk = 1'b0;
	reg         rst = 1'b1;


	// Setup recording
	// ---------------

	initial begin
		$dumpfile("lcd_tb.vcd");
		$dumpvars(0,lcd_tb);
		# 200000 $finish;
	end


	// Clock / Reset
	// -------------

	initial begin
		# 200 rst = 0;
	end

	always #10 clk = !clk;


	// DUTs
	// ----

	// Simple controller
	lcd_wb lcd_ctrl (
		.phy_data      (lcd_phy_data),
		.phy_rs        (lcd_phy_rs),
		.phy_valid     (lcd_phy_valid),
		.phy_ready     (lcd_phy_ready),
		.phy_fmark_stb (lcd_phy_fmark_stb),
		.wb_wdata      (wb_wdata),
		.wb_rdata      (wb_rdata),
		.wb_addr       (wb_addr[9:0]),
		.wb_we         (wb_we),
		.wb_cyc        (wb_cyc),
		.wb_ack        (wb_ack),
		.pw_wdata      (pw_wdata),
		.pw_wcmd       (pw_wcmd),
		.pw_wstb       (pw_wstb),
		.pw_end        (pw_end),
		.clk           (clk),
		.rst           (rst)
	);

	// PHY
	lcd_phy #(
		.SPEED(0)
	) lcd_phy_I (
		.lcd_d         (lcd_d),
		.lcd_rs        (lcd_rs),
		.lcd_wr_n      (lcd_wr_n),
		.lcd_fmark     (lcd_fmark),
		.phy_data      (lcd_phy_data),
		.phy_rs        (lcd_phy_rs),
		.phy_valid     (lcd_phy_valid),
		.phy_ready     (lcd_phy_ready),
		.phy_fmark_stb (lcd_phy_fmark_stb),
		.clk           (clk),
		.rst           (rst)
	);


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
		// Defaults
		wb_addr  <= 16'hxxxx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		pw_wdata <= 8'hxx;
		pw_wcmd  <= 1'bx;
		pw_wstb  <= 1'b0;
		pw_end   <= 1'b0;

		// Wait for reset
		@(negedge rst);
		@(posedge clk);

		// Issue commands
		wb_write(16'h0200, 32'h00000001);
		wb_write(16'h0201, 32'h000000a5);
		wb_write(16'h0202, 32'h00000011);
		wb_write(16'h0203, 32'h00000000);
		wb_write(16'h0204, 32'h000000aa);
		wb_write(16'h0205, 32'h00000000);
		wb_write(16'h0206, 32'h000000bb);
		wb_write(16'h0207, 32'h00000003);
		wb_write(16'h0208, 32'h0000005a);
		wb_write(16'h0209, 32'h00000011);
		wb_write(16'h020a, 32'h00000022);
		wb_write(16'h020b, 32'h00000033);

		wb_write(16'h0000, 32'h000b0000);

		wb_write(16'h0001, 32'h00000001);

		repeat (20)
			@(posedge clk);

		pw_write(1, 8'hf2);
		pw_write(0, 8'h01);
		pw_write(0, 8'ha5);
		pw_write(0, 8'h11);
		pw_write(0, 8'h00);
		pw_write(0, 8'haa);
		pw_write(0, 8'h00);
		pw_write(0, 8'hbb);
		pw_write(0, 8'h03);
		pw_write(0, 8'h5a);
		pw_write(0, 8'h11);
		pw_write(0, 8'h22);
		pw_write(0, 8'h33);
		pw_write(0, 8'hff);
		pw_write(0, 8'h5a);
		pw_write(0, 8'h11);
		pw_write(0, 8'h22);
		pw_write(0, 8'h33);

		@(posedge clk);
		pw_end <= 1'b1;
		@(posedge clk);
		pw_end <= 1'b0;

		pw_write(1, 8'hf2);
		pw_write(0, 8'hff);
		pw_write(0, 8'h5a);
		pw_write(0, 8'h11);
		pw_write(0, 8'h22);
		pw_write(0, 8'h33);

		@(posedge clk);
		pw_end <= 1'b1;
		@(posedge clk);
		pw_end <= 1'b0;

	end

endmodule // lcd_tb
