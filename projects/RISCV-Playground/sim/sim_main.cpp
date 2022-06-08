
#include <stdio.h>
#include "Vriscv_playground.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vriscv_playground* riscv_playground = new Vriscv_playground;
    int i;

    riscv_playground->lcd_mode = 1;

    riscv_playground->v__DOT__serial_valid = 1;   // Pretend to always have a character waiting
    riscv_playground->v__DOT__serial_busy  = 0;   // Pretend to never be busy

    for (i = 0; ; i++) {
      riscv_playground->clk_in = 1;
      riscv_playground->eval();
      riscv_playground->clk_in = 0;
      riscv_playground->eval();

      if (riscv_playground->v__DOT__serial_wr) {
        putchar(riscv_playground->v__DOT__mem_wdata & 0xFF);
      }
      if (riscv_playground->v__DOT__serial_rd) {
        int data=getchar();
        if (data ==  27) break;
        if (data == EOF) break;
        if (data == 127) { data=8; } // Replace DEL with Backspace

        riscv_playground->v__DOT__io_rdata = data | 0x100; // Place character directly into the io read wires
      }
    }

    printf("Simulation ended after %d cycles\n", i);
    delete riscv_playground;

    exit(0);
}
