
`default_nettype none

`define cfg_divider       208  // 24 MHz / 115200 = 208.33

`include "common-verilog/uart-fifo.v"
`include "common-verilog/j1-universal-16kb-quickstore.v"

module top(input clk_in, // 12 MHz

           output uart_tx,
           input  uart_rx,

           inout [7:0] pmod,

           // LCD
           output reg  [7:0] lcd_d,
           output reg        lcd_rs,
           output            lcd_wr_n,
           output reg        lcd_cs_n,
           output reg        lcd_rst_n,
           input  wire       lcd_fmark,
           input             lcd_mode,

           inout [2:0] rgb // LED outputs. [0]: Blue, [1]: Red, [2]: Green.
);

  // ######   Clock   #########################################

  wire clk; // 24 MHz

  SB_PLL40_PAD  #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
                  .DIVR(0),
                  .DIVF(63),
                  .DIVQ(5),
                  .FILTER_RANGE(1),
                 ) pll (
                         .PACKAGEPIN(clk_in),
                         .PLLOUTCORE(clk),
                         .RESETB(1'b1),
                         .BYPASS(1'b0)
                        );

  // ######   Reset logic   ###################################

  wire reset_button = 1'b1; // No reset button on this board

  reg [15:0] reset_cnt = 0;
  wire resetq = &reset_cnt;

  always @(posedge clk) begin
    if (reset_button) reset_cnt <= reset_cnt + !resetq;
    else        reset_cnt <= 0;
  end

  // ######   Bus   ###########################################

  wire io_rd, io_wr;
  wire [15:0] io_addr;
  wire [15:0] io_dout;
  wire [15:0] io_din;

  reg interrupt = 0;

  // ######   Processor   #####################################

  j1 #( .MEMWORDS(6144) ) _j1( // 12 kb Memory

    .clk(clk),
    .resetq(resetq),

    .io_rd(io_rd),
    .io_wr(io_wr),
    .io_dout(io_dout),
    .io_din(io_din),
    .io_addr(io_addr),

    .interrupt_request(interrupt)
  );

  // ######   Ticks   #########################################

  reg [15:0] ticks;

  wire [16:0] ticks_plus_1 = ticks + 1;

  always @(posedge clk)
    if (io_wr & io_addr[14])
      ticks <= io_dout;
    else
      ticks <= ticks_plus_1;

  always @(posedge clk) // Generate interrupt on ticks overflow
    interrupt <= ticks_plus_1[16];

  // ######   Cycles   ########################################

  reg [15:0] cycles;

  always @(posedge clk) cycles <= cycles + 1;

  // ######   PMOD   ##########################################

  reg  [7:0] pmod_dir;   // 1:output, 0:input
  reg  [7:0] pmod_out;
  wire [7:0] pmod_in;

  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa0  (.PACKAGE_PIN(pmod[0]),  .D_OUT_0(pmod_out[0]),  .D_IN_0(pmod_in[0]),  .OUTPUT_ENABLE(pmod_dir[0]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa1  (.PACKAGE_PIN(pmod[1]),  .D_OUT_0(pmod_out[1]),  .D_IN_0(pmod_in[1]),  .OUTPUT_ENABLE(pmod_dir[1]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa2  (.PACKAGE_PIN(pmod[2]),  .D_OUT_0(pmod_out[2]),  .D_IN_0(pmod_in[2]),  .OUTPUT_ENABLE(pmod_dir[2]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa3  (.PACKAGE_PIN(pmod[3]),  .D_OUT_0(pmod_out[3]),  .D_IN_0(pmod_in[3]),  .OUTPUT_ENABLE(pmod_dir[3]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa4  (.PACKAGE_PIN(pmod[4]),  .D_OUT_0(pmod_out[4]),  .D_IN_0(pmod_in[4]),  .OUTPUT_ENABLE(pmod_dir[4]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa5  (.PACKAGE_PIN(pmod[5]),  .D_OUT_0(pmod_out[5]),  .D_IN_0(pmod_in[5]),  .OUTPUT_ENABLE(pmod_dir[5]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa6  (.PACKAGE_PIN(pmod[6]),  .D_OUT_0(pmod_out[6]),  .D_IN_0(pmod_in[6]),  .OUTPUT_ENABLE(pmod_dir[6]),  .INPUT_CLK(clk) );
  SB_IO #(.PIN_TYPE(6'b1010_00)) ioa7  (.PACKAGE_PIN(pmod[7]),  .D_OUT_0(pmod_out[7]),  .D_IN_0(pmod_in[7]),  .OUTPUT_ENABLE(pmod_dir[7]),  .INPUT_CLK(clk) );

  // ######   SRAM   ############################################

  reg  [15:0] sram_addr;

  wire sram_wr = io_wr & io_addr[11] & (io_addr[7:4] == 1);

  wire [15:0] sram_in_bank0, sram_in_bank1, sram_in_bank2, sram_in_bank3;

    SB_SPRAM256KA rambank0 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b00)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank0)
);

    SB_SPRAM256KA rambank1 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b01)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank1)
);

    SB_SPRAM256KA rambank2 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b10)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank2)
);

    SB_SPRAM256KA rambank3 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b11)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank3)
);

  wire [15:0] sram_in = sram_in_bank3 | sram_in_bank2 | sram_in_bank1 | sram_in_bank0;

  // ######   UART   ##########################################

  wire uart0_valid, uart0_busy;
  wire [7:0] uart0_data;
  wire uart0_wr = io_wr & io_addr[12];
  wire uart0_rd = io_rd & io_addr[12];

  buart _uart0 (
     .clk(clk),
     .resetq(resetq),
     .rx(uart_rx),
     .tx(uart_tx),
     .rd(uart0_rd),
     .wr(uart0_wr),
     .valid(uart0_valid),
     .busy(uart0_busy),
     .tx_data(io_dout[7:0]),
     .rx_data(uart0_data));

  // ######   LEDs   ##########################################

  reg [3:0] LEDs; // [6:4]: IN [2:0] Constant Current Drivers

  reg [15:0] sdm_red,   phase_red;   reg sdm_red_out;   always @(posedge clk) {sdm_red_out,   phase_red}   <= phase_red   + sdm_red;
  reg [15:0] sdm_green, phase_green; reg sdm_green_out; always @(posedge clk) {sdm_green_out, phase_green} <= phase_green + sdm_green;
  reg [15:0] sdm_blue,  phase_blue;  reg sdm_blue_out;  always @(posedge clk) {sdm_blue_out,  phase_blue}  <= phase_blue  + sdm_blue;

  wire red   = LEDs[0] | sdm_red_out;
  wire green = LEDs[1] | sdm_green_out;
  wire blue  = LEDs[2] | sdm_blue_out;

  wire red_in, green_in, blue_in;

  SB_IO #(.PIN_TYPE(6'b1010_01)) rgb1 (.PACKAGE_PIN(rgb[1]),  .D_OUT_0(1'b0),  .D_IN_0(red_in),   .OUTPUT_ENABLE(1'b0) );
  SB_IO #(.PIN_TYPE(6'b1010_01)) rgb2 (.PACKAGE_PIN(rgb[2]),  .D_OUT_0(1'b0),  .D_IN_0(green_in), .OUTPUT_ENABLE(1'b0) );
  SB_IO #(.PIN_TYPE(6'b1010_01)) rgb0 (.PACKAGE_PIN(rgb[0]),  .D_OUT_0(1'b0),  .D_IN_0(blue_in),  .OUTPUT_ENABLE(1'b0) );

  // Instantiate iCE40 LED driver hard logic.
  //
  // Note that it's possible to drive the LEDs directly,
  // however that is not current-limited and results in
  // overvolting the red LED.
  //
  // See also:
  // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668

  SB_RGBA_DRV #(
      .CURRENT_MODE("0b1"),       // half current
      .RGB0_CURRENT("0b000011"),  // 4 mA
      .RGB1_CURRENT("0b000011"),  // 4 mA
      .RGB2_CURRENT("0b000011")   // 4 mA
  ) RGBA_DRIVER (
      .CURREN(1'b1),
      .RGBLEDEN(1'b1),
      .RGB1PWM(red),
      .RGB2PWM(green),
      .RGB0PWM(blue),
      .RGB1(rgb[1]),
      .RGB2(rgb[2]),
      .RGB0(rgb[0])
  );

  // ######   RING OSCILLATOR   ###############################

  wire [1:0] buffers_in, buffers_out;
  assign buffers_in = {buffers_out[0:0], ~buffers_out[1]};
  SB_LUT4 #(
          .LUT_INIT(16'd2)
  ) buffers [1:0] (
          .O(buffers_out),
          .I0(buffers_in),
          .I1(1'b0),
          .I2(1'b0),
          .I3(1'b0)
  );

  wire random = ~buffers_out[1];

  // ######   LCD   ###########################################

  // Software control of special wires

  reg [1:0] lcd_ctrl = 2'b01;
  assign {lcd_rst_n, lcd_cs_n} = lcd_ctrl;

  // Set WR in the second half of the clock cycle using DDR pin mode to allow the data lines to settle

  SB_IO #(.PIN_TYPE(6'b0100_01)) lcdwrn (.OUTPUT_CLK(clk), .PACKAGE_PIN(lcd_wr_n), .D_OUT_0(1'b0), .D_OUT_1(lcd_write), .OUTPUT_ENABLE(1'b1));
  reg lcd_write = 0;

  // Framebuffer & font data

  reg [10:0] lcd_addr;
  reg [7:0] characters [3*512-1:0]; // [1199:0] is sufficient, but RAM blocks come in 512 bytes...
  reg [7:0]       font [1023:0]; initial $readmemh("font-c64-ascii.hex", font);

  reg [7:0] read_char;
  reg [7:0] read_font;

  // Color registers for a beautiful output

  reg [15:0] color_fg0 = 16'hFD20; // Orange
  reg [15:0] color_bg0 = 16'h000F; // Navy
  reg [15:0] color_fg1 = 16'h07FF; // Cyan
  reg [15:0] color_bg1 = 16'h000F; // Navy

  // Internal signals for textmode generation

  reg toggle = 0;
  reg fmark_sync1 = 0;
  reg fmark_sync2 = 0;
  reg updating = 0;

  reg [8:0] xpos; // 0 to 320-1
  reg [7:0] ypos; // 0 to 240-1

  reg [7:0] char;
  reg [7:0] bitmap;
  reg [8:0] data0, data1;

  reg [2:0] fontrow;
  reg colorswitch;
  reg [10:0] characterindex;

  always @(posedge clk) begin

    // Reads from font data set & character buffer

    char   <= characters[toggle ? characterindex : lcd_addr            ]; // 7-Bit ASCII. Using char[7] for alternate colors.
    bitmap <=       font[toggle ? lcd_addr       : {char[6:0], fontrow}]; // 8x8 pixel font bitmap data.

    case (toggle)
      0: read_font <= bitmap; // Software can read these values three clock cycles after setting the address.
      1: read_char <= char;
    endcase

    toggle <= ~toggle; // Toggle between high and low part of data to LCD and between logic and software read access.

    characterindex <= 0;
    fontrow <= 0;

    // Synchronise incoming asynchronous VSYNC signal to clk

    fmark_sync1 <= lcd_fmark;
    fmark_sync2 <= fmark_sync1;

    // Logik to push data to LCD

    if (fmark_sync2 & ~updating) // VSYNC active and not yet updating?
    begin
      xpos <= 0;
      ypos <= 1;

      data0 <= {1'b0, 8'h00}; //   NOP command
      data1 <= {1'b0, 8'h2C}; // RAMWR command

      lcd_write <= 0;       // Nothing to write
      updating <= toggle; // Start when toggle is high, updating starts with toggle low in next cycle.
    end
    else
    begin
      if (updating) // Currently updating? Push data. One more pair of data is pushed for RAMWR command.
      begin
        lcd_write <= 1;

        case (toggle)
          0: begin
               {lcd_rs, lcd_d} <= data0;
               colorswitch <= char[7]; // Using MSB of character to switch to a different set of colors
               characterindex <= xpos[8:3] + 40 * ypos[7:3];
             end

          1: begin
               {lcd_rs, lcd_d} <= data1;

               {data1, data0} <= bitmap[~xpos[2:0]] ?
                             colorswitch ? {1'b1, color_fg1[7:0], 1'b1, color_fg1[15:8]} :
                                           {1'b1, color_fg0[7:0], 1'b1, color_fg0[15:8]} :
                             colorswitch ? {1'b1, color_bg1[7:0], 1'b1, color_bg1[15:8]} :
                                           {1'b1, color_bg0[7:0], 1'b1, color_bg0[15:8]} ;

               fontrow <= ypos[2:0];

               if (ypos == 239) begin xpos <= xpos + 1; ypos <= 0; end else ypos <= ypos + 1;
               updating <= ~((xpos == 320) & (ypos == 1));
             end
        endcase

      end
      else // Software control of the LCD wires for initialisation sequence or if software wants to slowly draw graphics
      begin
        if (io_wr & io_addr[11] & (io_addr[7:4] == 10)) begin
          {lcd_rs, lcd_d}  <= io_dout ^ 9'h100; // Data written with 9th bit set is written in command mode.
          lcd_write        <= 1;
        end
        else
          lcd_write <= 0;
      end
    end
  end

  // ######   IO Ports   ######################################

  /*        Bit READ            WRITE

    + ...0                      Write as usual
    + ...1                      _C_lear bits
    + ...2                      _S_et bits
    + ...3                      _T_oggle bits

      0008  3   Unused

      0010  4   \
      0020  5    \  Selector bits
      0040  6    /  for further decoding
      0080  7   /

      0100  8   IN                          Input
      0200  9   OUT             OUT (cst)   Output
      0400  10  DIR             DIR (cst)   Direction
      0800  11  Leds, Memory & LCD

      0800      RAM addr        RAM addr
      0810      RAM(addr)       RAM(addr)

      0820      LCD addr        LCD addr
      0830      Font(addr)      Font(addr)  -- Readback three cycles after setting access addr
      0840      Text(addr)      Text(addr)  -- Readback three cycles after setting access addr
      0850      Color FG0       Color FG0   -- Foreground color 0
      0860      Color BG0       Color BG0   -- Background color 0
      0870      Color FG1       Color FG1   -- Foreground color 1
      0880      Color BG1       Color BG1   -- Background color 1
      0890      LCD Ctrl        LCD Ctrl
      08A0                      LCD Data (writeonly)

      08B0      LEDs            LEDs (cst)
      08C0      SDM Red         SDM Red
      08D0      SDM Green       SDM Green
      08E0      SDM Blue        SDM Blue

      1000  12  UART RX         UART TX
      2000  13  UART Flags
      4000  14  Ticks           Set Ticks
      8000  15  Cycles
  */

  assign io_din =

    (io_addr[ 8] ?                       pmod_in                                    : 16'd0) |
    (io_addr[ 9] ?                       pmod_out                                   : 16'd0) |
    (io_addr[10] ?                       pmod_dir                                   : 16'd0) |

    (io_addr[11] & (io_addr[7:4] ==  0) ?  sram_addr                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  1) ?  sram_in                                  : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  2) ?  lcd_addr                                 : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  3) ?  read_font                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  4) ?  read_char                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  5) ?  color_fg0                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  6) ?  color_bg0                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  7) ?  color_fg1                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  8) ?  color_bg1                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] ==  9) ?  {updating,fmark_sync2,lcd_mode,lcd_ctrl} : 16'd0) |
    //                              10  ?  lcd_data, writeonly
    (io_addr[11] & (io_addr[7:4] == 11) ?  {blue_in, green_in, red_in, LEDs}        : 16'd0) |
    (io_addr[11] & (io_addr[7:4] == 12) ?  sdm_red                                  : 16'd0) |
    (io_addr[11] & (io_addr[7:4] == 13) ?  sdm_green                                : 16'd0) |
    (io_addr[11] & (io_addr[7:4] == 14) ?  sdm_blue                                 : 16'd0) |

    (io_addr[12] ?                       uart0_data                                 : 16'd0) |
    (io_addr[13] ?                       {random, uart0_valid, !uart0_busy}         : 16'd0) |
    (io_addr[14] ?                       ticks                                      : 16'd0) |
    (io_addr[15] ?                       cycles                                     : 16'd0) ;


  always @(posedge clk) begin


    if (io_wr & io_addr[ 9] & (io_addr[1:0] == 0))  pmod_out  <=               io_dout;
    if (io_wr & io_addr[ 9] & (io_addr[1:0] == 1))  pmod_out  <=  pmod_out  & ~io_dout; // Clear
    if (io_wr & io_addr[ 9] & (io_addr[1:0] == 2))  pmod_out  <=  pmod_out  |  io_dout; // Set
    if (io_wr & io_addr[ 9] & (io_addr[1:0] == 3))  pmod_out  <=  pmod_out  ^  io_dout; // Invert

    if (io_wr & io_addr[10] & (io_addr[1:0] == 0))  pmod_dir  <=               io_dout;
    if (io_wr & io_addr[10] & (io_addr[1:0] == 1))  pmod_dir  <=  pmod_dir  & ~io_dout; // Clear
    if (io_wr & io_addr[10] & (io_addr[1:0] == 2))  pmod_dir  <=  pmod_dir  |  io_dout; // Set
    if (io_wr & io_addr[10] & (io_addr[1:0] == 3))  pmod_dir  <=  pmod_dir  ^  io_dout; // Invert


    if (io_wr & io_addr[11] & (io_addr[7:4] ==  0)) sram_addr <= io_dout;
    //                                          1   SRAM write needs special logic, elsewhere
    if (io_wr & io_addr[11] & (io_addr[7:4] ==  2)) lcd_addr  <= io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] ==  3))       font[lcd_addr] <= io_dout[7:0];
    if (io_wr & io_addr[11] & (io_addr[7:4] ==  4)) characters[lcd_addr] <= io_dout[7:0];

    if (io_wr & io_addr[11] & (io_addr[7:4] ==  5)) color_fg0 <= io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] ==  6)) color_bg0 <= io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] ==  7)) color_fg1 <= io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] ==  8)) color_bg1 <= io_dout;

    if (io_wr & io_addr[11] & (io_addr[7:4] ==  9)) lcd_ctrl <= io_dout;
    //                                         10   lcd_data write needs special logic, elsewhere

    if (io_wr & io_addr[11] & (io_addr[7:4] == 11) & (io_addr[1:0] == 0))  LEDs      <=               io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] == 11) & (io_addr[1:0] == 1))  LEDs      <=  LEDs      & ~io_dout; // Clear
    if (io_wr & io_addr[11] & (io_addr[7:4] == 11) & (io_addr[1:0] == 2))  LEDs      <=  LEDs      |  io_dout; // Set
    if (io_wr & io_addr[11] & (io_addr[7:4] == 11) & (io_addr[1:0] == 3))  LEDs      <=  LEDs      ^  io_dout; // Invert

    if (io_wr & io_addr[11] & (io_addr[7:4] == 12)) sdm_red   <= io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] == 13)) sdm_green <= io_dout;
    if (io_wr & io_addr[11] & (io_addr[7:4] == 14)) sdm_blue  <= io_dout;

  end

endmodule
