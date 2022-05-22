/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Top-level module for MCH2022 self test bitstream
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module top (
	// UART (to RP2040)
	output wire       uart_tx,
	input  wire       uart_rx,

	// IRQ (to ESP32)
	output wire       irq_n,

	// SPI Slave (to ESP32)
	input  wire       spi_mosi,
	output wire       spi_miso,
	input  wire       spi_clk,
	input  wire       spi_cs_n,

	// PSRAM
	inout  wire [3:0] ram_io,
	output wire       ram_clk,
	output wire       ram_cs_n,

	// LCD
	output wire [7:0] lcd_d,
	output wire       lcd_rs,
	output wire       lcd_wr_n,
	output wire       lcd_cs_n,
	output wire       lcd_mode,
	output wire       lcd_rst_n,
	input  wire       lcd_fmark,

	// PMOD
	inout  wire [7:0] pmod,

	// RGB Leds
	output wire [2:0] rgb,

	// Clock
	input  wire       clk_in
);

	localparam integer WN  = 6;
	genvar i;


	// Signals
	// -------

	// Wishbone
	wire   [15:0] wb_addr;
	wire   [31:0] wb_rdata [0:WN-1];
	wire   [31:0] wb_wdata;
	wire    [3:0] wb_wmsk;
	wire [WN-1:0] wb_cyc;
	wire          wb_we;
	wire [WN-1:0] wb_ack;

	wire [(32*WN)-1:0] wb_rdata_flat;

	// Memory interface
	wire [31:0] mi_addr;
	wire [ 6:0] mi_len;
	wire        mi_rw;
	wire        mi_valid;
	wire        mi_ready;

	wire [31:0] mi_wdata;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// QPI PHY
	wire [15:0] qpi_phy_io_i;
	wire [15:0] qpi_phy_io_o;
	wire [ 3:0] qpi_phy_io_oe;
	wire [ 3:0] qpi_phy_clk_o;
	wire        qpi_phy_cs_o;

	// LCD PHY
	wire  [7:0] lcd_phy_data;
	wire        lcd_phy_rs;
	wire        lcd_phy_valid;
	wire        lcd_phy_ready;
	wire        lcd_phy_fmark_stb;

	// Clock / Reset
	wire        clk_1x;
	wire        clk_4x;
	wire        sync_4x;
	wire        rst;


	// SoC
	// ---

	soc_picorv32_base #(
		.WB_N     (WN),
		.WB_DW    (32),
		.WB_AW    (16),
		.BRAM_AW  (11), // 8k
		.SPRAM_AW (0)   // No SPRAM
	) base_I (
		.wb_addr  (wb_addr),
		.wb_rdata (wb_rdata_flat),
		.wb_wdata (wb_wdata),
		.wb_wmsk  (wb_wmsk),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.clk      (clk_1x),
		.rst      (rst)
	);

	for (i=0; i<WN; i=i+1)
		assign wb_rdata_flat[i*32+:32] = wb_rdata[i];


	// GPIO [0]
	// ----

	gpio_wb #(
		.N(12)
	) gpio_I (
		.gpio({
			irq_n,		// [11]
			lcd_cs_n,	// [10]
			lcd_mode,	// [ 9]
			lcd_rst_n,	// [ 8]
			pmod		// [ 7:0]
		}),
		.wb_addr  (wb_addr[1:0]),
		.wb_rdata (wb_rdata[0]),
		.wb_we    (wb_we),
		.wb_wdata (wb_wdata),
		.wb_cyc   (wb_cyc[0]),
		.wb_ack   (wb_ack[0]),
		.clk      (clk_1x),
		.rst      (rst)
	);


	// UART [1]
	// ----

	uart_wb #(
		.DIV_WIDTH(12),
		.DW(32)
	) uart_I (
		.uart_tx  (uart_tx),
		.uart_rx  (uart_rx),
		.wb_addr  (wb_addr[1:0]),
		.wb_rdata (wb_rdata[1]),
		.wb_we    (wb_we),
		.wb_wdata (wb_wdata),
		.wb_cyc   (wb_cyc[1]),
		.wb_ack   (wb_ack[1]),
		.clk      (clk_1x),
		.rst      (rst)
	);


	// RGB LEDs [2]
	// --------

	ice40_rgb_wb #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_I (
		.pad_rgb    (rgb),
		.wb_addr    (wb_addr[4:0]),
		.wb_rdata   (wb_rdata[2]),
		.wb_wdata   (wb_wdata),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[2]),
		.wb_ack     (wb_ack[2]),
		.clk        (clk_1x),
		.rst        (rst)
	);


	// QSPI controller [3]
	// ---------------

	// Controller
	qpi_memctrl #(
		.CMD_READ   (8'hEB),
		.CMD_WRITE  (8'h02),
		.DUMMY_CLK  (6),
		.PAUSE_CLK  (8),
		.FIFO_DEPTH (1),
		.N_CS       (1),
		.PHY_SPEED  (4),
		.PHY_WIDTH  (1),
		.PHY_DELAY  (4)
	) memctrl_I (
		.phy_io_i   (qpi_phy_io_i),
		.phy_io_o   (qpi_phy_io_o),
		.phy_io_oe  (qpi_phy_io_oe),
		.phy_clk_o  (qpi_phy_clk_o),
		.phy_cs_o   (qpi_phy_cs_o),
		.mi_addr_cs (2'b00),
		.mi_addr    ({mi_addr[21:0], 2'b00 }),	/* 32 bits aligned */
		.mi_len     (mi_len),
		.mi_rw      (mi_rw),
		.mi_valid   (mi_valid),
		.mi_ready   (mi_ready),
		.mi_wdata   (mi_wdata),
		.mi_wack    (mi_wack),
		.mi_wlast   (mi_wlast),
		.mi_rdata   (mi_rdata),
		.mi_rstb    (mi_rstb),
		.mi_rlast   (mi_rlast),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata[3]),
		.wb_addr    (wb_addr[4:0]),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[3]),
		.wb_ack     (wb_ack[3]),
		.clk        (clk_1x),
		.rst        (rst)
	);

	// PHY
	qpi_phy_ice40_4x #(
		.N_CS     (1),
		.WITH_CLK (1),
	) phy_I (
		.pad_io    (ram_io),
		.pad_clk   (ram_clk),
		.pad_cs_n  (ram_cs_n),
		.phy_io_i  (qpi_phy_io_i),
		.phy_io_o  (qpi_phy_io_o),
		.phy_io_oe (qpi_phy_io_oe),
		.phy_clk_o (qpi_phy_clk_o),
		.phy_cs_o  (qpi_phy_cs_o),
		.clk_1x    (clk_1x),
		.clk_4x    (clk_4x),
		.clk_sync  (sync_4x)
	);


	// Memory Tester [4]
	// -------------

	memtest #(
		.ADDR_WIDTH(32)
	) memtest_I (
		.mi_addr  (mi_addr),
		.mi_len   (mi_len),
		.mi_rw    (mi_rw),
		.mi_valid (mi_valid),
		.mi_ready (mi_ready),
		.mi_wdata (mi_wdata),
		.mi_wack  (mi_wack),
		.mi_rdata (mi_rdata),
		.mi_rstb  (mi_rstb),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[4]),
		.wb_addr  (wb_addr[8:0]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[4]),
		.wb_ack   (wb_ack[4]),
		.clk      (clk_1x),
		.rst      (rst)
	);


	// LCD [5]
	// ---

	// Simple controller
	lcd_wb lcd_ctrl (
		.phy_data      (lcd_phy_data),
		.phy_rs        (lcd_phy_rs),
		.phy_valid     (lcd_phy_valid),
		.phy_ready     (lcd_phy_ready),
		.phy_fmark_stb (lcd_phy_fmark_stb),
		.wb_wdata      (wb_wdata),
		.wb_rdata      (wb_rdata[5]),
		.wb_addr       (wb_addr[9:0]),
		.wb_we         (wb_we),
		.wb_cyc        (wb_cyc[5]),
		.wb_ack        (wb_ack[5]),
		.clk           (clk_1x),
		.rst           (rst)
	);

	// PHY
	lcd_phy #(
		.SPEED(1)
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
		.clk           (clk_1x),
		.rst           (rst)
	);


	// SPI Loopback
	// ------------

	spi_loopback spi_lb_I (
		.spi_mosi (spi_mosi),
		.spi_miso (spi_miso),
		.spi_clk  (spi_clk),
		.spi_cs_n (spi_cs_n),
		.clk      (clk_1x),
		.rst      (rst)
	);


	// Clock/Reset Generation
	// ----------------------

	sysmgr sysmgr_I (
		.clk_in  (clk_in),
		.clk_1x  (clk_1x),
		.clk_4x  (clk_4x),
		.sync_4x (sync_4x),
		.rst     (rst)
	);

endmodule // top
