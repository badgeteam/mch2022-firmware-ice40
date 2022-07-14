
module celement(input reset, input A1, input A2, output Z);

  SB_LUT4 #( .LUT_INIT(16'h00E8) ) _C (
        .O(Z),
        .I0(A1),
        .I1(A2),
        .I2(Z),
        .I3(reset)
  );

endmodule
