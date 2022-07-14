module DEFF(
  input  clock, resetq, in,
  output out
);

  reg trig1, trig2;

  assign out = trig1^trig2;

  always @(posedge clock, negedge resetq) begin
    if (~resetq)  trig1 <= 0;
    else  trig1 <= in^trig2;
  end

  always @(negedge clock, negedge resetq) begin
    if (~resetq)  trig2 <= 0;
    else  trig2 <= in^trig1;
  end
endmodule


// By Serge Goncharov
// https://stackoverflow.com/questions/19605881/triggering-signal-on-both-edges-of-the-clock
