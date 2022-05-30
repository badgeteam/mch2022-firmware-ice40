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
	// GPIO pads
	inout  wire [N-1:0] gpio,

	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire [ 1:0] wb_addr,
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
			bus_we_gpio_oe <= wb_we & (wb_addr[1:0] == 2'b00);
			bus_we_gpio_o  <= wb_we & (wb_addr[1:0] == 2'b01);
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
			casez (wb_addr[1:0])
				2'b00:   wb_rdata <= { {(32-N){1'b0}}, gpio_oe };
				2'b01:   wb_rdata <= { {(32-N){1'b0}}, gpio_o  };
				2'b10:   wb_rdata <= { {(32-N){1'b0}}, gpio_i  };
				default: wb_rdata <= 32'hxxxxxxxx;
			endcase


	// IOBs
	// ----

	SB_IO #(
		.PIN_TYPE(6'b1101_00),   // Reg input, Reg+RegOE output
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_I[N-1:0] (
		.PACKAGE_PIN   (gpio),
		.INPUT_CLK     (clk),
		.OUTPUT_CLK    (clk),
		.D_IN_0        (gpio_i),
		.D_OUT_0       (gpio_o),
		.OUTPUT_ENABLE (gpio_oe)
	);

endmodule // misc_wb
