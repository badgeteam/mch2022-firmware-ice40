
// This is an absolute minimum to get RISC-V Playground simulated in Verilator!
// Mostly it replaces the real blocks with dummys that give constant output...

/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off PINMISSING */
/* verilator lint_off DECLFILENAME */

module SB_RGBA_DRV(
	input CURREN,
	input RGBLEDEN,
	input RGB0PWM,
	input RGB1PWM,
	input RGB2PWM,
	output RGB0,
	output RGB1,
	output RGB2
);
	parameter CURRENT_MODE = "0b0";
	parameter RGB0_CURRENT = "0b000000";
	parameter RGB1_CURRENT = "0b000000";
	parameter RGB2_CURRENT = "0b000000";
endmodule

module SB_SPRAM256KA (
	input [13:0] ADDRESS,
	input [15:0] DATAIN,
	input [3:0] MASKWREN,
	input WREN, CHIPSELECT, CLOCK, STANDBY, SLEEP, POWEROFF,
	output reg [15:0] DATAOUT
);
	reg [15:0] mem [0:16383];
	wire off = SLEEP || !POWEROFF;
	integer i;

	always @(negedge POWEROFF) begin
		for (i = 0; i <= 16383; i = i+1)
			mem[i] = 16'bx;
	end

	always @(posedge CLOCK, posedge off) begin
		if (off) begin
			DATAOUT <= 0;
		end else
		if (STANDBY) begin
			DATAOUT <= 16'bx;
		end else
		if (CHIPSELECT) begin
			if (!WREN) begin
				DATAOUT <= mem[ADDRESS];
			end else begin
				if (MASKWREN[0]) mem[ADDRESS][ 3: 0] <= DATAIN[ 3: 0];
				if (MASKWREN[1]) mem[ADDRESS][ 7: 4] <= DATAIN[ 7: 4];
				if (MASKWREN[2]) mem[ADDRESS][11: 8] <= DATAIN[11: 8];
				if (MASKWREN[3]) mem[ADDRESS][15:12] <= DATAIN[15:12];
				DATAOUT <= 16'bx;
			end
		end
	end
endmodule


module SB_IO (
	inout  PACKAGE_PIN,
	input  LATCH_INPUT_VALUE,
	input  CLOCK_ENABLE,
	input  INPUT_CLK,
	input  OUTPUT_CLK,
	input  OUTPUT_ENABLE,
	input  D_OUT_0,
	input  D_OUT_1,
	output D_IN_0,
	output D_IN_1
);
	parameter [5:0] PIN_TYPE = 6'b000000;
	parameter [0:0] PULLUP = 1'b0;
	parameter [0:0] NEG_TRIGGER = 1'b0;
	parameter IO_STANDARD = "SB_LVCMOS";

  assign D_IN_0 = 0;
  assign D_IN_1 = 0;

endmodule

module SB_LUT4 (
	output O,
	input I0,
	input I1,
	input I2,
	input I3
);
	parameter [15:0] LUT_INIT = 0;

	assign O = 0;
endmodule

/* verilator lint_on UNUSED */
/* verilator lint_on UNDRIVEN */
/* verilator lint_on PINMISSING */
/* verilator lint_on DECLFILENAME */
