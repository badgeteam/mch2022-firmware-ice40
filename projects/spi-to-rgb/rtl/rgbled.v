module rgbled (
  input clk,
  input rst,

  input test_mode,

  // Input data RGB
  input in_r, // On of off
  input in_g,
  input in_b,

  // Output to the LED pins
  output led_r,
  output led_g,
  output led_b
);

  wire w_cycle_r, w_cycle_g, w_cycle_b;
  wire w_led_r, w_led_g, w_led_b;
  wire nrst;

  assign nrst = ~rst;

  // Cycle speeds of the RGB colors (All primes)
  parameter
  p_speed_r = 20'hff,
  p_speed_g = 20'hff,
  p_speed_b = 20'hff;

  // RGB IP
  SB_RGBA_DRV #(
  .CURRENT_MODE("0b1"),
  .RGB0_CURRENT("0b000001"),
  .RGB1_CURRENT("0b000001"),
  .RGB2_CURRENT("0b000001")
  ) u_rgb_drv (
    .RGB0(led_r),
    .RGB1(led_g),
    .RGB2(led_b),
    .RGBLEDEN(1'b1),
    .RGB0PWM(w_led_r),
    .RGB1PWM(w_led_g),
    .RGB2PWM(w_led_b),
    .CURREN(1'b1)
  );

  // RED
  cycle #(
  .START_POS(0)
  ) red_cycle (
    .i_clk(clk),
    .i_rst(rst),
    .i_speed(p_speed_r),
    .o_led(w_cycle_r)
  );

  // GREEN
  cycle #(
  .START_POS(512)
  ) green_cycle (
    .i_clk(clk),
    .i_rst(rst),
    .i_speed(p_speed_g),
    .o_led(w_cycle_g)
  );

  // BLUE
  cycle #(
  .START_POS(1024)
  ) blue_cycle (
    .i_clk(clk),
    .i_rst(rst),
    .i_speed(p_speed_b),
    .o_led(w_cycle_b)
  );

  // Whitch between input and cycle mode
  always @(posedge clk) begin
    if (rst) begin
      w_led_r <= 1'b0;
      w_led_g <= 1'b0;
      w_led_b <= 1'b0;
    end else if (test_mode) begin
      w_led_r <= w_cycle_r;
      w_led_g <= w_cycle_g;
      w_led_b <= w_cycle_b;
    end else begin
      w_led_r <= in_r;
      w_led_g <= in_g;
      w_led_b <= in_b;
    end
  end

endmodule
