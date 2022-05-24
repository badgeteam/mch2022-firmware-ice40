
module cordic(
  input             resetn,     // Reset, active low
  input             clk,        // Clock
  input             calculate,  // Set high for one clock cycle to start calculation
  input      [31:0] angle,      // Desired angle in S1.30 fixpoint format, range +-1.74, slightly more than +-Pi/2
  output reg [31:0] cos,        // Cosine, S1.30
  output reg [31:0] sin,        // Sine,   S1.30
  output reg        busy        // High while calculation in progress
);

  // Constants generated with GNU Octave:
  // format bank
  // transpose(2^30*atan(2.^-linspace(0, 31, 32)))
  // Decimal digits truncated without rounding.

  wire [31:0] beta [31:0];

  assign beta[ 0] = 32'd843314856 ;
  assign beta[ 1] = 32'd497837829 ;
  assign beta[ 2] = 32'd263043836 ;
  assign beta[ 3] = 32'd133525158 ;
  assign beta[ 4] = 32'd67021686 ;
  assign beta[ 5] = 32'd33543515 ;
  assign beta[ 6] = 32'd16775850 ;
  assign beta[ 7] = 32'd8388437 ;
  assign beta[ 8] = 32'd4194282 ;
  assign beta[ 9] = 32'd2097149 ;
  assign beta[10] = 32'd1048575 ;
  assign beta[11] = 32'd524287 ;
  assign beta[12] = 32'd262143 ;
  assign beta[13] = 32'd131072 ;
  assign beta[14] = 32'd65536 ;
  assign beta[15] = 32'd32768 ;
  assign beta[16] = 32'd16384 ;
  assign beta[17] = 32'd8192 ;
  assign beta[18] = 32'd4096 ;
  assign beta[19] = 32'd2048 ;
  assign beta[20] = 32'd1024 ;
  assign beta[21] = 32'd512 ;
  assign beta[22] = 32'd256 ;
  assign beta[23] = 32'd128 ;
  assign beta[24] = 32'd64 ;
  assign beta[25] = 32'd32 ;
  assign beta[26] = 32'd16 ;
  assign beta[27] = 32'd8 ;
  assign beta[28] = 32'd4 ;
  assign beta[29] = 32'd2 ;
  assign beta[30] = 32'd1 ;
  assign beta[31] = 32'd0 ;

  reg [31:0] phi;
  reg [4:0] count;

  wire [31:0] cos_arshift = $signed(cos) >>> count;
  wire [31:0] sin_arshift = $signed(sin) >>> count;

  always @(posedge clk) begin
    if (~resetn) begin
        cos  <= 0;
        sin  <= 0;
        busy <= 0;
    end else begin

      if (calculate) begin

        cos   <= 32'd652032874; // Cancel gain of algorithm by initialising with 2^30*prod(1./sqrt(1+2.^(-2*linspace(0, 31, 32))))
        sin   <= 0;
        phi   <= angle;         // Latch initial angle, as it might only be stable while calculate signal is high
        count <= 0;
        busy  <= 1;

      end else
      if (busy) begin
        cos <= cos + (phi[31] ?  sin_arshift : -sin_arshift);
        sin <= sin + (phi[31] ? -cos_arshift :  cos_arshift);
        phi <= phi + (phi[31] ?  beta[count] : -beta[count]);

        busy  <= ~(count == 31);
        count <= count + 1;
      end
    end
  end

endmodule
