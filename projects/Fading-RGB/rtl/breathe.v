
`default_nettype none // Simplifies finding typos

module breathe(
  input clk,
  output reg breathe_sin,
  output reg breathe_cos
);

parameter PREDIVIDER = 5;

  // Predivider to select blink frequency

  reg [PREDIVIDER:0] prediv = 0;
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

  wire  [7:0] scaled_sin = 8'd167 + sine[20:13];
  wire [31:0] exp_sin = {1'b1, scaled_sin[2:0]} << scaled_sin[7:3];

  wire  [7:0] scaled_cos = 8'd167 + cosine[20:13];
  wire [31:0] exp_cos = {1'b1, scaled_cos[2:0]} << scaled_cos[7:3];

  // Sigma-delta modulator

  reg  [31:0] phase_sin = 0;
  reg  [31:0] phase_cos = 0;

  wire [32:0] phase_sin_new = phase_sin + exp_sin;
  wire [32:0] phase_cos_new = phase_cos + exp_cos;

  always @(posedge clk) begin
    phase_sin <= phase_sin_new[31:0];
    phase_cos <= phase_cos_new[31:0];

    breathe_sin <= phase_sin_new[32];
    breathe_cos <= phase_cos_new[32];
  end

endmodule

