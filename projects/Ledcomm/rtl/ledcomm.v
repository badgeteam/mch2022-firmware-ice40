
   /***************************************************************************/
   // Ledcomm <-> UART Modem.
   /***************************************************************************/

`default_nettype none // Simplifies finding typos

`include "uart-fifo.v"
`include "ledcommflow.v"

module top(

   input clk_in, // 12 MHz

   output uart_tx,
   input  uart_rx,

   inout [7:0] pmod,

   output [2:0] rgb // LED outputs. [0]: Blue, [1]: Red, [2]: Green.
);

   /***************************************************************************/
   // Clock.
   /***************************************************************************/

   wire clk = clk_in; // Directly use 12 MHz

   /***************************************************************************/
   // Reset logic.
   /***************************************************************************/

   wire reset_button = 1'b1; // No reset button on this board

   reg [15:0] reset_cnt = 0;
   wire resetq = &reset_cnt;

   always @(posedge clk) begin
     if (reset_button) reset_cnt <= reset_cnt + !resetq;
     else        reset_cnt <= 0;
   end

   /***************************************************************************/
   // UART.
   /***************************************************************************/

   wire serial_valid;
   wire serial_busy;
   wire [7:0] serial_data;

   reg serial_wr = 0;
   reg serial_rd = 0;

   buart #(
     .FREQ_MHZ(12),
     .BAUDS(1200)
   ) the_buart (
      .clk(clk),
      .resetq(resetq),
      .rx(uart_rx),
      .tx(uart_tx),
      .rd(serial_rd),
      .wr(serial_wr),
      .valid(serial_valid),
      .busy(serial_busy),
      .tx_data(ledcomm_data[7:0]),
      .rx_data(serial_data)
   );

   /***************************************************************************/
   // Ledcomm.
   /***************************************************************************/

   reg ledcomm_darkness = 0;

   reg [15:0] ledcomm_timebase = 16'd600; // Default: 600 / 12 MHz = 50 us
   reg [15:0] ledcomm_charging =  16'd12; // Default:  12 / 12 MHz =  1 us

   wire ledcomm_anode_out;
   wire ledcomm_cathode_in;
   wire ledcomm_cathode_out;
   wire ledcomm_cathode_dir;

   assign pmod[0] = ledcomm_anode_out;

   SB_IO #(.PIN_TYPE(6'b1010_01)) _iocathode (
      .PACKAGE_PIN(pmod[1]),
      .D_OUT_0(ledcomm_cathode_out),
      .D_IN_0(ledcomm_cathode_in),
      .OUTPUT_ENABLE(ledcomm_cathode_dir)
   );

   reg ledcomm_wr = 0;
   reg ledcomm_rd = 0;

   wire [15:0] ledcomm_data;

   wire ledcomm_busy;
   wire ledcomm_valid;
   wire ledcomm_link;

   ledcommflow _ledcomm(

      .Anode_OUT  (ledcomm_anode_out  ),
      .Kathode_IN (ledcomm_cathode_in ),
      .Kathode_OUT(ledcomm_cathode_out),
      .Kathode_DIR(ledcomm_cathode_dir),

      .clk(clk),
      .resetq(resetq),

      .wr(ledcomm_wr),
      .rd(ledcomm_rd),
      .tx_data(serial_data),
      .rx_data(ledcomm_data),
      .busy(ledcomm_busy),
      .valid(ledcomm_valid),

      .Verbindungbesteht(ledcomm_link), // Link up?

      .Dunkelheit(ledcomm_darkness),    // Shall we wait in darkness when no link has been detected yet?

      .Basiszeit(ledcomm_timebase),     // Number of clock cycles for timebase
      .Ladezeit(ledcomm_charging)       // Number of clock cycles for reverse charging the junction capacitance
   );

   /***************************************************************************/
   // Flow between both.
   /***************************************************************************/

   reg [1:0] state_ledcomm_uart;
   reg [1:0] state_uart_ledcomm;

   always @(posedge clk) begin

     ledcomm_rd <= 0;
     ledcomm_wr <= 0;

     serial_rd <= 0;
     serial_wr <= 0;

     if (~resetq) begin
       state_ledcomm_uart <= 0;
       state_uart_ledcomm <= 0;

     end else begin

       case (state_ledcomm_uart)
         0 : begin if (serial_valid & ~ledcomm_busy) state_ledcomm_uart <= 1; end
         1 : begin ledcomm_wr <= ledcomm_link;       state_ledcomm_uart <= 2; end
         2 : begin serial_rd  <= 1;                  state_ledcomm_uart <= 3; end
         3 : begin                                   state_ledcomm_uart <= 0; end
       endcase

       case (state_uart_ledcomm)
         0 : begin if (ledcomm_valid & ~serial_busy) state_uart_ledcomm <= 1; end
         1 : begin serial_wr  <= 1;                  state_uart_ledcomm <= 2; end
         2 : begin ledcomm_rd <= 1;                  state_uart_ledcomm <= 3; end
         3 : begin                                   state_uart_ledcomm <= 0; end
       endcase

     end
   end

   /***************************************************************************/
   // Show status.
   /***************************************************************************/

   always @(posedge clk) begin
     if (ledcomm_rd) sdm_red  <= 16'h8000; else sdm_red  <= sdm_red  - |sdm_red;
     if (ledcomm_wr) sdm_blue <= 16'h8000; else sdm_blue <= sdm_blue - |sdm_blue;
     sdm_green <= ledcomm_link ? 16'h0010 : 16'h1000;
   end

   /***************************************************************************/
   // LEDs.
   /***************************************************************************/

   reg [15:0] sdm_red,   phase_red;   reg sdm_red_out;   always @(posedge clk) {sdm_red_out,   phase_red}   <= phase_red   + sdm_red;
   reg [15:0] sdm_green, phase_green; reg sdm_green_out; always @(posedge clk) {sdm_green_out, phase_green} <= phase_green + sdm_green;
   reg [15:0] sdm_blue,  phase_blue;  reg sdm_blue_out;  always @(posedge clk) {sdm_blue_out,  phase_blue}  <= phase_blue  + sdm_blue;

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
       .RGB1PWM(sdm_red_out),
       .RGB2PWM(sdm_green_out),
       .RGB0PWM(sdm_blue_out),
       .RGB1(rgb[1]),
       .RGB2(rgb[2]),
       .RGB0(rgb[0])
   );

endmodule
