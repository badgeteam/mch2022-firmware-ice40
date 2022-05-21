
`default_nettype none // Simplifies finding typos

module top(
  input clk_in,
  output [2:0] rgb // LED outputs. [0]: Blue, [1]: Red, [2]: Green.
);

  wire clk = clk_in; // Directly use the 12 MHz oscillator, no fancy PLL config

  // ----------------------------------------------------------
  //   Fading blinky
  // ----------------------------------------------------------

  // Predivider to select blink frequency

  reg [5:0] prediv = 0;
  always @(posedge clk) prediv <= prediv + 1;

  // Minsky circle algorithm

  reg [20:0] sine   = 0;
  reg [20:0] cosine = 1 << 19;

  always @(posedge clk)
  if (prediv == 0)
  begin
    cosine = $signed(cosine) - ($signed(  sine) >>> 17);
    sine   = $signed(  sine) + ($signed(cosine) >>> 17);
  end

  // Exponential function approximation

  wire  [7:0] scaled = 8'd167 + sine[20:13];
  wire [31:0] exp = {1'b1, scaled[2:0]} << scaled[7:3];

  // Sigma-delta modulator

  reg  [31:0] phase = 0;
  wire [32:0] phase_new = phase + exp;
  reg fading;

  always @(posedge clk) begin
    phase <= phase_new[31:0];
    fading <= phase_new[32];
  end

  // Set red, green and blue together for white:

  wire red   = fading;
  wire green = fading;
  wire blue  = fading;

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

  reg [2:0] LEDS;

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
