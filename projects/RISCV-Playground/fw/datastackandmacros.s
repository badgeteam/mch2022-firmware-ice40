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

# -----------------------------------------------------------------------------
# Bit-position equates (for setting or clearing a single bit)
# -----------------------------------------------------------------------------

  .equ  BIT0,    0x00000001
  .equ  BIT1,    0x00000002
  .equ  BIT2,    0x00000004
  .equ  BIT3,    0x00000008
  .equ  BIT4,    0x00000010
  .equ  BIT5,    0x00000020
  .equ  BIT6,    0x00000040
  .equ  BIT7,    0x00000080
  .equ  BIT8,    0x00000100
  .equ  BIT9,    0x00000200
  .equ  BIT10,   0x00000400
  .equ  BIT11,   0x00000800
  .equ  BIT12,   0x00001000
  .equ  BIT13,   0x00002000
  .equ  BIT14,   0x00004000
  .equ  BIT15,   0x00008000
  .equ  BIT16,   0x00010000
  .equ  BIT17,   0x00020000
  .equ  BIT18,   0x00040000
  .equ  BIT19,   0x00080000
  .equ  BIT20,   0x00100000
  .equ  BIT21,   0x00200000
  .equ  BIT22,   0x00400000
  .equ  BIT23,   0x00800000
  .equ  BIT24,   0x01000000
  .equ  BIT25,   0x02000000
  .equ  BIT26,   0x04000000
  .equ  BIT27,   0x08000000
  .equ  BIT28,   0x10000000
  .equ  BIT29,   0x20000000
  .equ  BIT30,   0x40000000
  .equ  BIT31,   0x80000000

# -----------------------------------------------------------------------------
# Register definitions for more readable opcode assembly
# -----------------------------------------------------------------------------

.equ reg_loop_index, 3
.equ reg_loop_limit, 4

.equ reg_tos, 8
.equ reg_psp, 9

.equ reg_tmp1, 15
.equ reg_tmp2, 14

# -----------------------------------------------------------------------------
# Macros for return stack and data stack
# -----------------------------------------------------------------------------

.macro push register
  addi sp, sp, -4
  sw \register, 0(sp)
.endm

.macro pop register
  lw \register, 0(sp)
  addi sp, sp, 4
.endm


.macro pushdouble register1 register2
  addi sp, sp, -8
  sw \register1, 4(sp)
  sw \register2, 0(sp)
.endm

.macro popdouble register1 register2
  lw \register1, 0(sp)
  lw \register2, 4(sp)
  addi sp, sp, 8
.endm


.macro push_x1_x10
  addi sp, sp, -8
  sw x1,  4(sp)
  sw x10, 0(sp)
.endm
.macro pop_x1_x10
  lw x1,  4(sp)
  lw x10, 0(sp)
  addi sp, sp, 8
.endm


.macro push_x10_x11
  addi sp, sp, -8
  sw x10,  4(sp)
  sw x11, 0(sp)
.endm
.macro pop_x10_x11
  lw x10,  4(sp)
  lw x11, 0(sp)
  addi sp, sp, 8
.endm


.macro push_x1_x10_x11
  addi sp, sp, -12
  sw x1,  8(sp)
  sw x10, 4(sp)
  sw x11, 0(sp)
.endm
.macro pop_x1_x10_x11
  lw x1,  8(sp)
  lw x10, 4(sp)
  lw x11, 0(sp)
  addi sp, sp, 12
.endm


.macro push_x10_x12
  addi sp, sp, -12
  sw x10, 8(sp)
  sw x11, 4(sp)
  sw x12, 0(sp)
.endm
.macro pop_x10_x12
  lw x10,  8(sp)
  lw x11, 4(sp)
  lw x12, 0(sp)
  addi sp, sp, 12
.endm


.macro push_x1_x10_x12
  addi sp, sp, -16
  sw x1,  12(sp)
  sw x10, 8(sp)
  sw x11, 4(sp)
  sw x12, 0(sp)
.endm
.macro pop_x1_x10_x12
  lw x1,  12(sp)
  lw x10, 8(sp)
  lw x11, 4(sp)
  lw x12, 0(sp)
  addi sp, sp, 16
.endm


.macro push_x10_x13
  addi sp, sp, -16
  sw x10, 12(sp)
  sw x11, 8(sp)
  sw x12, 4(sp)
  sw x13, 0(sp)
.endm
.macro pop_x10_x13
  lw x10,  12(sp)
  lw x11, 8(sp)
  lw x12, 4(sp)
  lw x13, 0(sp)
  addi sp, sp, 16
.endm


.macro push_x1_x10_x13
  addi sp, sp, -20
  sw x1,  16(sp)
  sw x10, 12(sp)
  sw x11, 8(sp)
  sw x12, 4(sp)
  sw x13, 0(sp)
.endm
.macro pop_x1_x10_x13
  lw x1,  16(sp)
  lw x10, 12(sp)
  lw x11, 8(sp)
  lw x12, 4(sp)
  lw x13, 0(sp)
  addi sp, sp, 20
.endm

.macro push_x3_x4_x5_x6_x7
  addi sp, sp, -20
  sw x3, 16(sp)
  sw x4, 12(sp)
  sw x5, 8(sp)
  sw x6, 4(sp)
  sw x7, 0(sp)
.endm
.macro pop_x3_x4_x5_x6_x7
  lw x3, 16(sp)
  lw x4, 12(sp)
  lw x5, 8(sp)
  lw x6, 4(sp)
  lw x7, 0(sp)
  addi sp, sp, 20
.endm


.macro push_x1_x5_x6_x10_x13
  addi sp, sp, -28
  sw x1,  24(sp)
  sw x5,  20(sp)
  sw x6,  16(sp)
  sw x10, 12(sp)
  sw x11, 8(sp)
  sw x12, 4(sp)
  sw x13, 0(sp)
.endm
.macro pop_x1_x5_x6_x10_x13
  lw x1,  24(sp)
  lw x5,  20(sp)
  lw x6,  16(sp)
  lw x10, 12(sp)
  lw x11, 8(sp)
  lw x12, 4(sp)
  lw x13, 0(sp)
  addi sp, sp, 28
.endm

.macro push_x1_x5_x6_x7_x10_x13
  addi sp, sp, -32
  sw x1,  28(sp)
  sw x5,  24(sp)
  sw x6,  20(sp)
  sw x7,  16(sp)
  sw x10, 12(sp)
  sw x11, 8(sp)
  sw x12, 4(sp)
  sw x13, 0(sp)
.endm
.macro pop_x1_x5_x6_x7_x10_x13
  lw x1,  28(sp)
  lw x5,  24(sp)
  lw x6,  20(sp)
  lw x7,  16(sp)
  lw x10, 12(sp)
  lw x11, 8(sp)
  lw x12, 4(sp)
  lw x13, 0(sp)
  addi sp, sp, 32
.endm

.macro pushdatos
  addi x9, x9, -4
  sw x8, 0(x9)
.endm

.macro dup
  addi x9, x9, -4
  sw x8, 0(x9)
.endm

.macro over
  addi x9, x9, -4
  sw x8, 0(x9)
  lw x8, 4(x9)
.endm

.macro ddup # l(0) h(x8) -- l(8) h(4) l(0) h(x8)
  lw x15, 0(x9)
  addi x9, x9, -8
  sw x8, 4(x9)
  sw x15, 0(x9)
.endm

.macro swap
  mv x15, x8
  lw x8, 0(x9)
  sw x15, 0(x9)
.endm

.macro drop
  lw x8, 0(x9)
  addi x9, x9, 4
.endm

.macro nip
  addi x9, x9, 4
.endm

.macro ddrop
  lw x8, 4(x9)
  addi x9, x9, 8
.endm

.macro to_r
  push x8
  drop
.endm

.macro r_from
  pushdatos
  pop x8
.endm

.macro to_r_2
  addi sp, sp, -8
  sw x8, 0(sp)
  lw x8, 0(x9)
  sw x8, 4(sp)
  ddrop
.endm

.macro r_from_2
  addi x9, x9, -8
  sw x8, 4(x9)

  lw x8, 4(sp)
  sw x8, 0(x9)
  lw x8, 0(sp)

  addi sp, sp, 8
.endm

.macro r_fetch_2
  addi x9, x9, -8
  sw x8, 4(x9)

  lw x8, 4(sp)
  sw x8, 0(x9)
  lw x8, 0(sp)
.endm

.macro r_drop_2
  addi sp, sp, 8
.endm

.macro pushdaconst constant # Push constant on Datastack
  pushdatos
  li x8, \constant
.endm


.ifdef within_os

# Within OS: Forth dictionary points are handled by linker

    .macro laf register, address
      la \register, \address
    .endm

    .macro pushdaaddrf address # Push address constant on Datastack
      pushdatos
      la x8, \address
    .endm

.else

# Embedded: Forth dictionary points are handled by dictionary structure, which appear as constants to the assembler

    .macro laf register, address
      li \register, \address
    .endm

    .macro pushdaaddrf address # Push address constant on Datastack
      pushdatos
      li x8, \address
    .endm

.endif

.macro pushdaaddr address # Push address constant on Datastack
  pushdatos
  la x8, \address
.endm

.macro pushda register # Push register on Datastack
  pushdatos
  mv x8, \register
.endm

.macro popda register # Pop register from Datastack
  mv \register, x8
  drop
.endm

.macro popdanos register # Pop register from next element on Datastack
  lw \register, 0(x9)
  addi x9, x9, 4
.endm

.macro pushdadouble register1 register2 # Push register on Datastack
  addi x9, x9, -8
  sw x8, 4(x9)
  sw \register1, 0(x9)
  mv x8, \register2
.endm

.macro popdadouble register1 register2 # Pop register from Datastack
  mv \register1, x8
  lw \register2, 0(x9)
  lw x8, 4(x9)
  addi x9, x9, 8
.endm

.macro popdatriple register1 register2 register3 # Pop register from Datastack
  mv \register1, x8
  lw \register2, 0(x9)
  lw \register3, 4(x9)
  lw x8, 8(x9)
  addi x9, x9, 12
.endm

.macro inv register
  .ifdef mipscore
  nor \register, \register, zero
  .else
  xori \register, \register, -1
  .endif
.endm
