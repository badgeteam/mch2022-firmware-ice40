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
#  Multiplication, Division and Remainder available as opcodes in MIPS
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "*" # ( x1 x2 -- x1*x2 )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  mul x8, x15, x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "um*" # ( u1 u2 -- ud )
um_star:
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  multu x15, x8
  mflo x14
  sw x14, 0(x9)
  mfhi x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "m*" # ( n1 n2 -- d )
m_star:
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  mult x15, x8
  mflo x14
  sw x14, 0(x9)
  mfhi x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "/" # ( n1 n2 -- n1/n2 )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  .word 0x0000001A | reg_tmp1 << 21 | reg_tos << 16 # div x15, x8
  mflo x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "mod" # ( n1 n2 -- n1%n2 )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  .word 0x0000001A | reg_tmp1 << 21 | reg_tos << 16 # div x15, x8
  mfhi x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "u/mod" # ( u1 u2 -- rem quot )
u_divmod:
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  .word 0x0000001B | reg_tmp1 << 21 | reg_tos << 16 # divu x15, x8
  mfhi x14
  sw x14, 0(x9)
  mflo x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "/mod" # ( n1 n2 -- rem quot )
divmod:
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  .word 0x0000001A | reg_tmp1 << 21 | reg_tos << 16 # div x15, x8
  mfhi x14
  sw x14, 0(x9)
  mflo x8
  ret
