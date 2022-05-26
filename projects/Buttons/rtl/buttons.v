
`default_nettype none // Simplifies finding typos

module top(
  input clk_in,

  input  spi_mosi,
  output spi_miso,
  input  spi_clk,
  input  spi_cs_n,

  output [2:0] rgb // LED outputs. [0]: Blue, [1]: Red, [2]: Green.
);

  // ----------------------------------------------------------
  //  Clock
  // ----------------------------------------------------------

  wire clk; // 48 MHz

  SB_PLL40_PAD  #(.FEEDBACK_PATH("SIMPLE"),
                  .DIVR(4'b0000),         // DIVR =  0
                  .DIVF(7'b0111111),      // DIVF = 63
                  .DIVQ(3'b100),          // DIVQ =  4
                  .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
                 ) pll (
                         .PACKAGEPIN(clk_in),
                         .PLLOUTCORE(clk),
                         .RESETB(1'b1),
                         .BYPASS(1'b0)
                        );

  // ----------------------------------------------------------
  //   Reset logic
  // ----------------------------------------------------------

  wire reset_button = 1'b1; // No reset button on this board

  reg [15:0] reset_cnt = 0;
  wire resetq = &reset_cnt;

  always @(posedge clk) begin
    if (reset_button) reset_cnt <= reset_cnt + !resetq;
    else        reset_cnt <= 0;
  end

  // ----------------------------------------------------------
  //   SPI interface
  // ----------------------------------------------------------

  wire csn_state, csn_rise, csn_fall;

  wire [7:0] usr_miso_data = 8'h00;
  wire [7:0] usr_mosi_data;
  wire usr_mosi_stb, usr_miso_ack;

  spi_dev_core _communication (

    .clk (clk),
    .rst (~resetq),

    .usr_mosi_data (usr_mosi_data),
    .usr_mosi_stb  (usr_mosi_stb),
    .usr_miso_data (usr_miso_data),
    .usr_miso_ack  (usr_miso_ack),

    .csn_state (csn_state),
    .csn_rise  (csn_rise),
    .csn_fall  (csn_fall),

    // Interface to SPI wires

    .spi_miso (spi_miso),
    .spi_mosi (spi_mosi),
    .spi_clk  (spi_clk),
    .spi_cs_n (spi_cs_n)
  );

  // A very simple SPI protocol implementation that looks for 0xF4 messages
  // and captures the following 4 bytes.

  reg [5*8-1:0] incoming_data;
  reg [4*8-1:0] buttonstate;

  always @(posedge clk)
  begin
    if          (csn_fall) incoming_data <= 0;
    else if (usr_mosi_stb) incoming_data <= {incoming_data[4*8-1:0], usr_mosi_data};

    if (csn_rise & (incoming_data[5*8-1:4*8] == 8'hf4)) buttonstate <= incoming_data[4*8-1:0];
  end

  // Data contents:
  //      | buttonstate[31:16]  | buttonstate[15:0]
  // 0xF4 | 2 bytes button mask | 2 bytes button state

  // ----------------------------------------------------------
  //   Sigma-Delta-Modulators on LEDs
  // ----------------------------------------------------------

  always @(posedge clk) begin
    sdm_red   <= {buttonstate[ 3:0], 12'd0};
    sdm_green <= {buttonstate[ 7:4], 12'd0};
    sdm_blue  <= {buttonstate[11:8], 12'd0};
  end

  wire red, green, blue;

  reg [15:0] sdm_red,   phase_red;   reg sdm_red_out;   always @(posedge clk) {sdm_red_out,   phase_red}   <= phase_red   + sdm_red;
  reg [15:0] sdm_green, phase_green; reg sdm_green_out; always @(posedge clk) {sdm_green_out, phase_green} <= phase_green + sdm_green;
  reg [15:0] sdm_blue,  phase_blue;  reg sdm_blue_out;  always @(posedge clk) {sdm_blue_out,  phase_blue}  <= phase_blue  + sdm_blue;

  assign {blue, green, red} = {sdm_blue_out, sdm_green_out, sdm_red_out};

  // ----------------------------------------------------------
  // Instantiate iCE40 LED driver hard logic.
  // ----------------------------------------------------------
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
      .RGB0(rgb[0]),
      .RGB1(rgb[1]),
      .RGB2(rgb[2])
  );

endmodule
