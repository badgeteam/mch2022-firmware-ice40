`default_nettype none

module stack2(
  input wire clk,
  output wire [WIDTH-1:0] rd,
  input wire we,
  input wire [1:0] delta,
  input wire [WIDTH-1:0] wd
);

  parameter DEPTH = 16;
  parameter WIDTH = 16;
  localparam BITS = (WIDTH * DEPTH) - 1;

  reg [BITS:0] stack;

  always @(posedge clk) begin
    casez ({we, delta})

      default: stack <= stack;                                                                                                     //  3 2 1 0
      3'b0_01: stack <= { stack[BITS-WIDTH:0], stack[WIDTH-1:0] };                                                                 //  2 1 0 0
   // 3'b0_10: stack <= { {(WIDTH/8){4'h5}}, {(WIDTH/8){4'ha}}, {(WIDTH/8){4'h5}}, {(WIDTH/8){4'ha}}, stack[BITS:2*WIDTH] };       //  x x 3 2
      3'b0_11: stack <= {                                       {(WIDTH/8){4'h5}}, {(WIDTH/8){4'ha}}, stack[BITS:WIDTH]   };       //  x 3 2 1
                                                                                                                                   //
      3'b1_00: stack <= { stack[BITS:WIDTH], wd };                                                                                 //  3 2 1 d
      3'b1_01: stack <= { stack[BITS-WIDTH:0], wd };                                                                               //  2 1 0 d
   // 3'b1_10: stack <= { {(WIDTH/8){4'h5}}, {(WIDTH/8){4'ha}}, {(WIDTH/8){4'h5}}, {(WIDTH/8){4'ha}}, stack[BITS:3*WIDTH], wd };   //  x x 3 d
      3'b1_11: stack <= {                                       {(WIDTH/8){4'h5}}, {(WIDTH/8){4'ha}}, stack[BITS:2*WIDTH], wd };   //  x 3 2 d

    endcase
  end

  assign rd = stack[WIDTH-1:0];

endmodule
