
`default_nettype none // Simplifies finding typos

module top(
  input clk_in,
  output [2:0] rgb // LED outputs. [0]: Green, [1]: Red, [2]: Blue.
);

  wire clk = clk_in; // Directly use the 12 MHz oscillator, no fancy PLL config

  // ----------------------------------------------------------
  //   Simple gray counter blinky
  // ----------------------------------------------------------

  reg [31:0] counter;

  always @(posedge clk) counter <= counter + 1;

  wire red, green, blue;

  assign {blue, green, red} = counter[25:23] ^ counter[25:24];

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
      .RGB0PWM(green),
      .RGB1PWM(red),
      .RGB2PWM(blue),      
      .RGB0(rgb[0]),
      .RGB1(rgb[1]),
      .RGB2(rgb[2])
  );

endmodule
