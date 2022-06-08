#
#    Mecrisp-Quintus - A native code Forth implementation for RISC-V
#    Copyright (C) 2018  Matthias Koch
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Interrupt handler for RISC-V

.macro initinterrupt Name:req, Asmname:req, Routine:req, Alignment

#------------------------------------------------------------------------------
  Definition Flag_visible|Flag_variable, "irq-\Name" # ( -- addr )
  CoreVariable irq_hook_\Name
#------------------------------------------------------------------------------
  pushdatos
  laf x8, irq_hook_\Name
  ret
  .word \Routine  # Startwert für unbelegte Interrupts   Start value for unused interrupts

  .ifb \Alignment
    .align 2
  .else
    .align \Alignment
  .endif

\Asmname:

  addi sp, sp, -13*4
  sw x1,  12*4(sp)
  laf x1, irq_hook_\Name
  j irq_common

.endm

#------------------------------------------------------------------------------
irq_common: # Common framework for all interrupt entries
#------------------------------------------------------------------------------

  sw x14, 11*4(sp) # Required for Forth core...
  sw x15, 10*4(sp)

  sw x16,  9*4(sp) # Required for Acrobatics only...
  sw x17,  8*4(sp)
  sw x18,  7*4(sp)
  sw x19,  6*4(sp)
  sw x20,  5*4(sp)
  sw x21,  4*4(sp)
  sw x22,  3*4(sp)
  sw x23,  2*4(sp)
  sw x24,  1*4(sp)
  sw x25,  0*4(sp)

  lw x1, 0(x1)
  jalr x1, x1, 0

  lw x25,  0*4(sp) # Required for Acrobatics only...
  lw x24,  1*4(sp)
  lw x23,  2*4(sp)
  lw x22,  3*4(sp)
  lw x21,  4*4(sp)
  lw x20,  5*4(sp)
  lw x19,  6*4(sp)
  lw x18,  7*4(sp)
  lw x17,  8*4(sp)
  lw x16,  9*4(sp)

  lw x15, 10*4(sp) # Required for Forth core...
  lw x14, 11*4(sp)
  lw x1,  12*4(sp)

  addi sp, sp, 13*4

  mret
