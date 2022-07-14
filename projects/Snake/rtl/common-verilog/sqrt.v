
// Fast integer square root. Algorithm from the book "Hacker's Delight".

module sqrt(
  input             resetn,     // Reset, active low
  input             clk,        // Clock
  input             calculate,  // Set high for one clock cycle to start calculation
  input      [31:0] square,     // Unsigned 32 bit integer
  output reg [31:0] root,       // Result
  output            busy        // High while calculation in progress
);

  reg [31:0] x, mask;

  assign busy = |mask;

  always @(posedge clk) begin
    if (~resetn) begin
        root <= 0;
        mask <= 0;
    end else begin

      if (calculate) begin

        x    <= square;
        root <= 0;
        mask <= 32'h40000000;

      end else
      if (busy) begin

        if (x >= (root|mask)) begin
          x    <= x - (root|mask);
          root <=     (root >> 1) | mask;
        end else begin
          root <=      root >> 1;
        end

        mask <= mask >> 2;
      end
    end
  end

endmodule
