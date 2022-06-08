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

# Vergleichsoperatoren
# Comparision operators

# -----------------------------------------------------------------------------
  Definition Flag_foldable_1|Flag_inline, "0=" # ( x -- ? )
# -----------------------------------------------------------------------------
  sltiu x8, x8, 1
  sub x8, zero, x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_1|Flag_inline, "0<>" # ( x -- ? )
# -----------------------------------------------------------------------------
  sltiu x8, x8, 1
  addi x8, x8, -1
  ret


# -----------------------------------------------------------------------------
  Definition Flag_foldable_1|Flag_inline, "0<" # ( n -- ? )
# -----------------------------------------------------------------------------
  srai x8, x8, 31
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, ">=" # ( x1 x2 -- ? )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  slt x8, x15, x8
  addi x8, x8, -1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "<=" # ( x1 x2 -- ? )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  slt x8, x8, x15
  addi x8, x8, -1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "<" # ( x1 x2 -- ? )
                      # Checks if x2 is less than x1.
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  slt x8, x15, x8
  sub x8, zero, x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, ">" # ( x1 x2 -- ? )
                      # Checks if x2 is greater than x1.
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  slt x8, x8, x15
  sub x8, zero, x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "u>=" # ( u1 u2 -- ? )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  sltu x8, x15, x8
  addi x8, x8, -1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "u<=" # ( u1 u2 -- ? )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  sltu x8, x8, x15
  addi x8, x8, -1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "u<" # ( u1 u2 -- ? )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  sltu x8, x15, x8
  sub x8, zero, x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "u>" # ( u1 u2 -- ? )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  sltu x8, x8, x15
  sub x8, zero, x8
  ret

# -----------------------------------------------------------------------------
  # Definition Flag_inline|Flag_opcodierbar_GleichUngleich, "<>" # ( x1 x2 -- ? )
  Definition Flag_foldable_2|Flag_inline, "<>" # ( x1 x2 -- ? )
                       # Compares the top two stack elements for inequality.
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  xor x8, x8, x15
  sltiu x8, x8, 1
  addi x8, x8, -1
  ret

# -----------------------------------------------------------------------------
  # Definition Flag_inline|Flag_opcodierbar_GleichUngleich, "=" # ( x1 x2 -- ? )
  Definition Flag_foldable_2|Flag_inline, "=" # ( x1 x2 -- ? )
                      # Compares the top two stack elements for equality.
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  xor x8, x8, x15
  sltiu x8, x8, 1
  sub x8, zero, x8
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "min" # ( x1 x2 -- x3 )
                        # x3 is the lesser of x1 and x2.
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  blt x8, x15, 1f
    mv x8, x15
1:ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "max" # ( x1 x2 -- x3 )
                        # x3 is the greater of x1 and x2.
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  blt x15, x8, 1f
    mv x8, x15
1:ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "umin" # ( u1 u2 -- u1|u2 )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  bltu x8, x15, 1f
    mv x8, x15
1:ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "umax" # ( u1 u2 -- u1|u2 )
# -----------------------------------------------------------------------------
  lw x15, 0(x9)
  addi x9, x9, 4
  bltu x15, x8, 1f
    mv x8, x15
1:ret
