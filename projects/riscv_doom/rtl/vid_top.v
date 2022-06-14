/*
 * vid_top.v
 *
 * Top-level for the video module
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_top (
	// LCD
	output wire  [7:0] lcd_d,
	output wire        lcd_rs,
	output wire        lcd_wr_n,
	output wire        lcd_cs_n,
	output wire        lcd_mode,
	output wire        lcd_rst_n,
	input  wire        lcd_fmark,

	// Wishbone
	input  wire [15:0] wb_addr,
	output reg  [31:0] wb_rdata,
	input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Signals
	// -------

	// Frame Buffer
	wire [13:0] fb_v_addr_0;
	wire [31:0] fb_v_data_1;
	wire        fb_v_re_0;
	wire [13:0] fb_a_addr_0;
	wire [31:0] fb_a_rdata_1;
	wire [31:0] fb_a_wdata_0;
	wire [ 3:0] fb_a_wmsk_0;
	wire        fb_a_we_0;
	wire        fb_a_rdy_0;

	// Palette
	wire [ 7:0] pal_w_addr;
	wire [15:0] pal_w_data;
	wire        pal_w_ena;

	wire [ 7:0] pal_r_addr_0;
	wire        pal_r_ena_0;
	wire [15:0] pal_r_data_1;

	// Bus interface
	wire        bus_clr;
	reg         bus_we_csr;
	reg         bus_we_lcd;
	wire [31:0] bus_rd_csr;

	// Video status/control
	reg  [15:0] vs_frame_cnt;
	reg         vs_in_vbl;
	reg         vc_cs;
	reg         vc_rst;

	// GPIO
	wire  [2:0] gpio_i;
	wire  [2:0] gpio_o;
	wire  [2:0] gpio_oe;

	// Pixel Pipeline
	reg         pp_start_pending;
	reg         pp_start;

	reg         pp_active_0;

	reg  [15:0] pp_addr_base_0;
	reg  [15:0] pp_addr_cur_0;
	reg  [ 9:0] pp_xcnt_0;
	wire        pp_xcnt_last_0;
	reg  [ 8:0] pp_ycnt_0;
	wire        pp_ycnt_last_0;
	reg   [2:0] pp_yscale_state_0;
	reg         pp_yscale_inc_0;

	reg   [1:0] pp_addr_lsb_1;
	reg   [7:0] pp_data_1;

	wire [15:0] pp_data_2;

	reg   [2:0] pp_valid_x;

	wire        pp_init;
	wire        pp_move;
	wire        pp_ready;

	// LCD PHY
	reg         phy_byte_toggle;
	wire        phy_do_load;

	wire        phy_ena;
	reg   [7:0] phy_data;
	reg         phy_rs;
	reg         phy_valid;
	wire        phy_ready;
	wire        phy_fmark_stb;


	// Frame Buffer
	// ------------

	vid_framebuf fb_I (
		.v_addr_0  (fb_v_addr_0),
		.v_data_1  (fb_v_data_1),
		.v_re_0    (fb_v_re_0),
		.a_addr_0  (fb_a_addr_0),
		.a_rdata_1 (fb_a_rdata_1),
		.a_wdata_0 (fb_a_wdata_0),
		.a_wmsk_0  (fb_a_wmsk_0),
		.a_we_0    (fb_a_we_0),
		.a_rdy_0   (fb_a_rdy_0),
		.clk       (clk)
	);


	// Palette
	// -------

	vid_palette pal_I (
		.w_addr_0 (pal_w_addr),
		.w_data_0 (pal_w_data),
		.w_ena_0  (pal_w_ena),
		.r_addr_0 (pal_r_addr_0),
		.r_ena_0  (pal_r_ena_0),
		.r_data_1 (pal_r_data_1),
		.clk      (clk)
	);


	// Bus Interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack & (~wb_addr[15] | fb_a_rdy_0);

	// Read Mux
	always @(*)
	begin
		wb_rdata = 32'h00000000;
		if (wb_ack)
			wb_rdata = wb_addr[15] ? fb_a_rdata_1 : bus_rd_csr;
	end

	// Frame Buffer write
	assign fb_a_addr_0  = wb_addr[13:0];
	assign fb_a_wdata_0 = wb_wdata;
	assign fb_a_wmsk_0  = wb_wmsk;
	assign fb_a_we_0    = wb_cyc & wb_we & ~wb_ack & wb_addr[15];

	// Palette write
	assign pal_w_addr = wb_addr[7:0];
	assign pal_w_data = { wb_wdata[23:19], wb_wdata[15:10], wb_wdata[7:3] };
	assign pal_w_ena  = wb_cyc & wb_we & ~wb_ack & (wb_addr[15:14] == 2'b01);

	// Strobes
	assign bus_clr = ~wb_cyc | wb_ack;

	always @(posedge clk)
		if (bus_clr) begin
			bus_we_csr <= 1'b0;
			bus_we_lcd <= 1'b0;
		end else begin
			bus_we_csr <= wb_we & (wb_addr[15:14] == 2'b00) & ~wb_addr[0];
			bus_we_lcd <= wb_we & (wb_addr[15:14] == 2'b00) &  wb_addr[0];
		end

	// CSR
	assign bus_rd_csr = {
		pp_start_pending,
		pp_active_0,
		phy_valid,
		9'h000,
		gpio_i,
		vs_in_vbl,
		vs_frame_cnt
	};


	// Video Status / Control
	// ----------------------

	// VSync
	always @(posedge clk)
		vs_in_vbl <= (vs_in_vbl & ~phy_fmark_stb) | (bus_we_csr & wb_wdata[16]);

	// Frame counter
	always @(posedge clk)
		if (rst)
			vs_frame_cnt <= 0;
		else
			vs_frame_cnt <= vs_frame_cnt + phy_fmark_stb;

	// Control bits
	always @(posedge clk or posedge rst)
		if (rst) begin
			vc_rst <= 1'b0;
			vc_cs  <= 1'b0;
		end else if (bus_we_csr) begin
			vc_rst <= wb_wdata[18];
			vc_cs  <= wb_wdata[17];
		end


	// GPIO for LCD control
	// --------------------

	// Instance
	SB_IO #(
		.PIN_TYPE(6'b1101_00),   // Reg input, Reg+RegOE output
		.PULLUP(1'b1),
		.IO_STANDARD("SB_LVCMOS")
	) iob_I[2:0] (
		.PACKAGE_PIN   ({lcd_mode, lcd_rst_n, lcd_cs_n}),
		.INPUT_CLK     (clk),
		.OUTPUT_CLK    (clk),
		.D_IN_0        (gpio_i),
		.D_OUT_0       (gpio_o),
		.OUTPUT_ENABLE (gpio_oe)
	);

	// `lcd_mode` is input only
	assign gpio_o[2]  = 1'b0;
	assign gpio_oe[2] = 1'b0;

	// Open Drain outputs
	assign gpio_o[1:0]  = 2'b00;
	assign gpio_oe[1:0] = { vc_rst, vc_cs };

	// Auto-enable PHY when mode=1
	assign phy_ena = gpio_i[2];


	// Control FSM
	// -----------

	// Start signal
	always @(posedge clk or posedge rst)
	begin
		if (rst) begin
			pp_start <= 1'b0;
			pp_start_pending <= 1'b0;
		end else begin
			pp_start         <= (pp_start_pending &  phy_fmark_stb) | (bus_we_lcd & wb_wdata[31] & ~wb_wdata[30]);
			pp_start_pending <= (pp_start_pending & ~phy_fmark_stb) | (bus_we_lcd & wb_wdata[31] &  wb_wdata[30]);
		end
	end

	// Active flah
	always @(posedge clk or posedge rst)
		if (rst)
			pp_active_0 <= 1'b0;
		else
			pp_active_0 <= (pp_active_0 & ~(pp_move & pp_xcnt_last_0 & pp_ycnt_last_0)) | pp_start;

	// Valid flag
	always @(*)
		pp_valid_x[0] = pp_active_0;

	always @(posedge clk or posedge rst)
		if (rst)
			pp_valid_x[2:1] <= 0;
		else if (pp_move)
			pp_valid_x[2:1] <= pp_valid_x[1:0];

	// Control
	assign pp_init  = ~pp_active_0;
	assign pp_move  = (pp_active_0 & ~pp_valid_x[2]) | (pp_active_0 & pp_ready) | (pp_valid_x[2] & pp_ready);


	// Video Pipeline
	// --------------

	// Address counter
		// * Scan each column (240px), sometimes skipping the increment
		//   of the address to double the line (200 -> 240 px)
		// * Once column is done, increment base address by 1 to go to
		//   the next columns

		// FIXME: Check if yosys implements those counters optimally

	always @(posedge clk)
	begin
		if (pp_init) begin
			// Initial state
			pp_addr_base_0    <= 16'h0001;
			pp_addr_cur_0     <= 16'h0000;
			pp_xcnt_0         <= 10'h13e; // 320 - 2
			pp_ycnt_0         <=  9'h0ee; // 240 - 2
			pp_yscale_state_0 <=  3'b000;
			pp_yscale_inc_0   <=  1'b1;
		end else if (pp_move) begin
			// Addresses
			pp_addr_base_0 <= pp_addr_base_0 + pp_ycnt_last_0;
			pp_addr_cur_0  <= pp_ycnt_last_0 ? pp_addr_base_0 : (pp_addr_cur_0 + (pp_yscale_inc_0 ? 16'd320 : 16'd0));

			// Pixel counters
			pp_xcnt_0      <= pp_xcnt_0 + {10{pp_ycnt_last_0}};
			pp_ycnt_0      <= pp_ycnt_last_0 ? 9'h0ee : (pp_ycnt_0 - 1);

			// Scaling state
			case (pp_yscale_state_0)
				3'h0:    { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b1, 3'h1 };
				3'h1:    { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b1, 3'h2 };
				3'h2:    { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b0, 3'h3 };
				3'h3:    { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b1, 3'h4 };
				3'h4:    { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b1, 3'h5 };
				3'h5:    { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b1, 3'h0 };
				default: { pp_yscale_inc_0, pp_yscale_state_0 } <= { 1'b1, 4'h0 };
			endcase;
		end
	end

	assign pp_xcnt_last_0 = pp_xcnt_0[9];
	assign pp_ycnt_last_0 = pp_ycnt_0[8];

	// Fetch Frame Buffer
	assign fb_v_addr_0 = pp_addr_cur_0[15:2];
	assign fb_v_re_0   = pp_move;

	always @(posedge clk)
		if (pp_move)
			pp_addr_lsb_1 <= pp_addr_cur_0[1:0];

	always @(*)
		case (pp_addr_lsb_1)
			2'b00:   pp_data_1 = fb_v_data_1[ 7: 0];
			2'b01:   pp_data_1 = fb_v_data_1[15: 8];
			2'b10:   pp_data_1 = fb_v_data_1[23:16];
			2'b11:   pp_data_1 = fb_v_data_1[31:24];
			default: pp_data_1 = 8'hxx;
		endcase

	// Fetch palette
	assign pal_r_addr_0 = pp_data_1;
	assign pal_r_ena_0  = pp_move;
	assign pp_data_2 = pal_r_data_1;


	// LCD PHY
	// -------

	// Data feed
	always @(posedge clk)
		if (rst) begin
			phy_data  <= 8'h00;
			phy_rs    <= 1'b0;
			phy_valid <= 1'b0;
		end else begin
			if (bus_we_lcd) begin
				// Force-Load from bus
				phy_data  <= wb_wdata[7:0];
				phy_rs    <= wb_wdata[8];
				phy_valid <= 1'b1;
			end else if (phy_do_load) begin
				phy_data  <= phy_byte_toggle ? pp_data_2[7:0] : pp_data_2[15:8];
				phy_rs    <= 1'b1;
				phy_valid <= pp_valid_x[2];
			end else if (phy_ready) begin
				phy_valid <= 1'b0;
			end
		end

	always @(posedge clk)
		if (rst)
			phy_byte_toggle <= 1'b0;
		else if (phy_do_load)
			phy_byte_toggle <= phy_byte_toggle ? 1'b0 : pp_valid_x[2];

	assign phy_do_load = ~phy_valid | phy_ready;
	assign pp_ready    =  phy_do_load & phy_byte_toggle;


	// Instance
	lcd_phy #(
		.SPEED(1)
	) phy_I (
		.lcd_d         (lcd_d),
		.lcd_rs        (lcd_rs),
		.lcd_wr_n      (lcd_wr_n),
		.lcd_fmark     (lcd_fmark),
		.phy_ena       (phy_ena),
		.phy_data      (phy_data),
		.phy_rs        (phy_rs),
		.phy_valid     (phy_valid),
		.phy_ready     (phy_ready),
		.phy_fmark_stb (phy_fmark_stb),
		.clk           (clk),
		.rst           (rst)
	);

endmodule // vid_top
