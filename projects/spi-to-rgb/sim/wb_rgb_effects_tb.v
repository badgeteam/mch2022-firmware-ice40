/*
 * wb_rgb_effects_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Test bench for the Wishbone to RGB effects module
 *
 * Copyright (C) 2022  Paul Honig <paul@etv.cx>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module wb_rgb_effects_tb;

    // Signals
    wire    [2:0] rgb_leds_o;

    // Wishbone bus
    reg    [15:0] wb_addr;
    wire   [31:0] wb_rdata;
    reg    [31:0] wb_wdata;
    reg           wb_cyc;
    reg           wb_we;
    wire          wb_ack;

    // Clock / Reset
    reg         clk = 1'b0;
    reg         rst = 1'b0;


    // Setup recording
    // ---------------

    initial begin
        $dumpfile("wb_rgb_effects_tb.vcd");
        $dumpvars(0,wb_rgb_effects_tb);
        # 400000 $finish;
    end

    // Clock / Reset
    // -------------

    initial begin
        # 200 rst = 1;
    end

    always #10 clk = !clk;

    // RGB Effects 
    wb_rgb_effects wb_rgb_effects_inst (
        .clk(clk),
        .rst(rst),
        .wb_addr(wb_addr[1:0]),
        .wb_rdata(wb_rdata),
        .wb_wdata(wb_wdata),
        .wb_cyc(wb_cyc),
        .wb_we(wb_we),
        .wb_ack(wb_ack),
        .rgb_leds_o(rgb_leds_o)
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

    initial begin
        // Defaults
        wb_addr  <= 16'hxxxx;
        wb_wdata <= 32'hxxxxxxxx;
        wb_we    <= 1'bx;
        wb_cyc   <= 1'b0;

        // Wait for reset
        @(posedge rst);
        @(negedge clk);

        // Issue commands
        wb_write(16'h0000, 32'h00000003); // Enable output and start cycle demo
        wb_write(16'h0001, 32'h00040404); // Enable output and start cycle demo
        #100000 @(posedge clk);
        wb_write(16'h0001, 32'h000f0f0f); // Enable output and start cycle demo
        #100000 @(posedge clk);
        wb_write(16'h0000, 32'h00000005); // Enable output and start cycle demo
        wb_write(16'h0001, 32'h00000011); // Enable output and start cycle demo
        #25000 @(posedge clk);
        wb_write(16'h0001, 32'h00000088); // Enable output and start cycle demo
        #25000 @(posedge clk);
        wb_write(16'h0001, 32'h000000ff); // Enable output and start cycle demo
        #25000 @(posedge clk);
        wb_write(16'h0001, 32'h00004400); // Enable output and start cycle demo
        #25000 @(posedge clk);
        wb_write(16'h0001, 32'h00440000); // Enable output and start cycle demo
        // wb_write(16'h0201, 32'h000000a5);
        // wb_write(16'h0202, 32'h00000011);
        // wb_write(16'h0203, 32'h00000000);
        // wb_write(16'h0204, 32'h000000aa);
        // wb_write(16'h0205, 32'h00000000);
        // wb_write(16'h0206, 32'h000000bb);
        // wb_write(16'h0207, 32'h00000003);
        // wb_write(16'h0208, 32'h0000005a);
        // wb_write(16'h0209, 32'h00000011);
        // wb_write(16'h020a, 32'h00000022);
        // wb_write(16'h020b, 32'h00000033);

        // wb_write(16'h0000, 32'h000b0000);

    end


endmodule   