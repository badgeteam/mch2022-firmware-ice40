/*
 * spi_link.v
 *
 * Link to the ESP32 via SPI
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none


module spi_link (
	// SPI Slave (to ESP32)
	input  wire        spi_mosi,
	output wire        spi_miso,
	input  wire        spi_clk,
	input  wire        spi_cs_n,

	// IRQ
	output wire        irq_n,

	// Wishbone
	input  wire  [2:0] wb_addr,
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

	// Raw core IF
	wire [7:0] usr_mosi_data;
	wire       usr_mosi_stb;

	wire [7:0] usr_miso_data;
	wire       usr_miso_ack;

	wire       csn_state;
	wire       csn_rise;
	wire       csn_fall;

	// Protocol IF
	wire [7:0] pw_wdata;
	wire       pw_wcmd;
	wire       pw_wstb;
	wire       pw_end;

	wire       pw_req;
	wire       pw_gnt;
	wire [7:0] pw_rdata;
	wire       pw_rstb;

	wire [3:0] pw_irq;
	wire       irq;

	// Button reports
	wire [15:0] btn_rpt_state;
	wire [15:0] btn_rpt_change;
	wire        btn_rpt_stb;

	reg  [15:0] btn_rpt_state_cur;

	// File Reader IF
	reg  [31:0] frd_req_file_id;
	reg  [31:0] frd_req_offset;
	reg  [10:0] frd_req_len;
	reg         frd_req_valid;
	wire        frd_req_ready;

	wire  [7:0] frd_rsp_data;
	wire        frd_rsp_valid;
	wire        frd_rsp_ready;


	// Bus interface
	// -------------

	wire        bus_clr;
	reg         bus_we_fid;
	reg         bus_we_ofs;
	reg         bus_we_len;
	reg         bus_re_dat;
	wire [31:0] bus_rd_csr;

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	// Clear
	assign bus_clr = ~wb_cyc | wb_ack;

	// Read/Write strobes
	always @(posedge clk)
		if (bus_clr) begin
			bus_we_fid <= 1'b0;
			bus_we_ofs <= 1'b0;
			bus_we_len <= 1'b0;
			bus_re_dat <= 1'b0;
		end else begin
			bus_we_fid <=  wb_we & (wb_addr[2:0] == 3'b001);
			bus_we_ofs <=  wb_we & (wb_addr[2:0] == 3'b010);
			bus_we_len <=  wb_we & (wb_addr[2:0] == 3'b011);
			bus_re_dat <= ~wb_we & (wb_addr[2:0] == 3'b100);
		end

	// Read mux
	always @(posedge clk)
		if (bus_clr)
			wb_rdata = 32'h00000000;
		else
			wb_rdata = wb_addr[2] ? { frd_rsp_valid, 23'h000000, frd_rsp_data } : bus_rd_csr;

	// CSR
	assign bus_rd_csr = {
		frd_rsp_valid,
		frd_req_valid,
		14'h0000,
		btn_rpt_state_cur
	};

	// FIFO read
	assign frd_rsp_ready = bus_re_dat & wb_rdata[31];


	// File reads
	// ----------

	// Request
	always @(posedge clk)
		if (bus_we_fid)
			frd_req_file_id <= wb_wdata;

	always @(posedge clk)
		if (bus_we_ofs)
			frd_req_offset <= wb_wdata;
		else if (frd_req_valid & frd_req_ready)
			frd_req_offset <= frd_req_offset + frd_req_len + 1;

	always @(posedge clk)
		if (bus_we_len)
			frd_req_len <= wb_wdata[10:0];

	always @(posedge clk)
		frd_req_valid <= (frd_req_valid & ~frd_req_ready) | bus_we_len;


	// SPI device
	// ----------

	// Device Core
	spi_dev_core core_I (
		.spi_miso      (spi_miso),
		.spi_mosi      (spi_mosi),
		.spi_clk       (spi_clk),
		.spi_cs_n      (spi_cs_n),
		.usr_mosi_data (usr_mosi_data),
		.usr_mosi_stb  (usr_mosi_stb),
		.usr_miso_data (usr_miso_data),
		.usr_miso_ack  (usr_miso_ack),
		.csn_state     (csn_state),
		.csn_rise      (csn_rise),
		.csn_fall      (csn_fall),
		.clk           (clk),
		.rst           (rst)
	);

	// Protocol wrapper
	spi_dev_proto proto_I (
		.usr_mosi_data (usr_mosi_data),
		.usr_mosi_stb  (usr_mosi_stb),
		.usr_miso_data (usr_miso_data),
		.usr_miso_ack  (usr_miso_ack),
		.csn_state     (csn_state),
		.csn_rise      (csn_rise),
		.csn_fall      (csn_fall),
		.pw_wdata      (pw_wdata),
		.pw_wcmd       (pw_wcmd),
		.pw_wstb       (pw_wstb),
		.pw_end        (pw_end),
		.pw_req        (pw_req),
		.pw_gnt        (pw_gnt),
		.pw_rdata      (pw_rdata),
		.pw_rstb       (pw_rstb),
		.pw_irq        (pw_irq),
		.irq           (irq),
		.clk           (clk),
		.rst           (rst)
	);

	assign pw_irq[3:1] = 3'b000;
	assign irq_n = irq ? 1'b0 : 1'bz;

	// Command decoder for the F4 command
	// (button state reports from ESP32)
	spi_dev_scmd #(
		.CMD_BYTE (8'hf4),
		.CMD_LEN  (4)
	) scmd_f4_I (
		.pw_wdata (pw_wdata),
		.pw_wcmd  (pw_wcmd),
		.pw_wstb  (pw_wstb),
		.pw_end   (pw_end),
		.cmd_data ({btn_rpt_state, btn_rpt_change}),
		.cmd_stb  (btn_rpt_stb),
		.clk      (clk),
		.rst      (rst)
	);

	always @(posedge clk)
		if (btn_rpt_stb)
			btn_rpt_state_cur <= btn_rpt_state;

	// File Reader
	spi_dev_fread #(
		.INTERFACE("FIFO"),
		.BUFFER_DEPTH(1024)
	) fread_I (
		.pw_wdata     (pw_wdata),
		.pw_wcmd      (pw_wcmd),
		.pw_wstb      (pw_wstb),
		.pw_end       (pw_end),
		.pw_req       (pw_req),
		.pw_gnt       (pw_gnt),
		.pw_rdata     (pw_rdata),
		.pw_rstb      (pw_rstb),
		.pw_irq       (pw_irq[0]),
		.req_file_id  (frd_req_file_id),
		.req_offset   (frd_req_offset),
		.req_len      (frd_req_len),
		.req_valid    (frd_req_valid),
		.req_ready    (frd_req_ready),
		.resp_data    (frd_rsp_data),
		.resp_valid   (frd_rsp_valid),
		.resp_ready   (frd_rsp_ready),
		.clk          (clk),
		.rst          (rst)
	);

endmodule // spi_link
