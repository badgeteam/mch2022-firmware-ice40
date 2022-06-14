/*
 * misc_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module misc_wb #(
	parameter integer N = 12
)(
	// GPIO
	inout  wire [N-1:0] gpio_pads,
	output wire [N-1:0] gpio_in,

	// LCD fmark
	input  wire        lcd_fmark,

	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire [ 2:0] wb_addr,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Bus IF
	wire bus_clr;
	reg  bus_we_gpio_oe;
	reg  bus_we_gpio_o;

	// GPIO IOB
	reg  [N-1:0] gpio_oe;
	reg  [N-1:0] gpio_o;
	wire [N-1:0] gpio_i;

	// Counters
	reg   [31:0] cnt_cycle;
	reg   [15:0] cnt_frame;


	// Bus interface
	// -------------

		// ACK & Clear
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	assign bus_clr = ~wb_cyc | wb_ack;

	// Write Enables
	always @(posedge clk)
		if (bus_clr) begin
			bus_we_gpio_oe <= 1'b0;
			bus_we_gpio_o  <= 1'b0;
		end else begin
			bus_we_gpio_oe <= wb_we & (wb_addr[2:0] == 3'b000);
			bus_we_gpio_o  <= wb_we & (wb_addr[2:0] == 3'b001);
		end

	// Registers
	always @(posedge clk)
		if (rst)
			gpio_oe <= 0;
		else if (bus_we_gpio_oe)
			gpio_oe <= wb_wdata[N-1:0];

	always @(posedge clk)
		if (rst)
			gpio_o <= 0;
		else if (bus_we_gpio_o)
			gpio_o <= wb_wdata[N-1:0];

	// Read-Mux
	always @(posedge clk)
		if (bus_clr)
			wb_rdata <= 0;
		else
			casez (wb_addr[2:0])
				3'b000:  wb_rdata <= { {(32-N){1'b0}}, gpio_oe };
				3'b001:  wb_rdata <= { {(32-N){1'b0}}, gpio_o  };
				3'b010:  wb_rdata <= { {(32-N){1'b0}}, gpio_i  };
				3'b1z0:  wb_rdata <= cnt_cycle;
				3'b1z1:  wb_rdata <= { 16'h0000, cnt_frame };
				default: wb_rdata <= 32'hxxxxxxxx;
			endcase


	// Counters
	// --------

	// Cycle counter
	always @(posedge clk)
		if (rst)
			cnt_cycle <= 0;
		else
			cnt_cycle <= cnt_cycle + 1;

	// Frame mark counter
	always @(posedge clk)
		if (rst)
			cnt_frame <= 0;
		else
			cnt_frame <= cnt_frame + lcd_fmark;


	// IOBs
	// ----

	SB_IO #(
		.PIN_TYPE(6'b1101_00),   // Reg input, Reg+RegOE output
		.PULLUP(1'b1),
		.IO_STANDARD("SB_LVCMOS")
	) iob_I[N-1:0] (
		.PACKAGE_PIN   (gpio_pads),
		.INPUT_CLK     (clk),
		.OUTPUT_CLK    (clk),
		.D_IN_0        (gpio_i),
		.D_OUT_0       (gpio_o),
		.OUTPUT_ENABLE (gpio_oe)
	);

	assign gpio_in = gpio_i;

endmodule // misc_wb
