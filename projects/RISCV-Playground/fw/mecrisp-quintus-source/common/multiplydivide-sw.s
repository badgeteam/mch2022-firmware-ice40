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
#  Multiplication, Division and Remainder implemented in software for RV32I.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "*" # ( x1 x2 -- x1*x2 )
# -----------------------------------------------------------------------------
  push x1
  call um_star
  drop
  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "um*" # ( u1 u2 -- ud )
um_star:
# -----------------------------------------------------------------------------
  push_x10_x12

  # x10 # Result high
  # x11 # Result low
  # x12 # 1. Factor
  #  x8 # 2. Factor
  # x15 # Counter

  lw x12, 0(x9)

  # Multiply x12 * x8, Result in x10:x11
  li x10, 0  # Clear result-high
  li x11, 0  # Clear result-low
  li x15, 32 # Set loop counter

1:srli x14, x11, 31 # Last Result * 2
  add x11, x11, x11
  add x10, x10, x10
  or x10, x10, x14

  srai x14, x8, 31
  slli x8, x8, 1
  beq x14, zero, 2f

    # x10:x11 + 0:x12
    add x11, x11, x12
    sltu x14, x11, x12
    add x10, x10, x14

2:addi x15, x15, -1
  bne x15, zero, 1b

  sw x11, 0(x9) # Result low
  mv x8, x10    #        high

  pop_x10_x12
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "m*" # ( n1 n2 -- d )
m_star:
# -----------------------------------------------------------------------------
  push_x1_x10

  mv x10, x8

    srai x15, x8, 31 # Turn MSB into 0xffffffff or 0x00000000
    add x8, x8, x15
    xor x8, x8, x15

  swap
  xor x10, x10, x8

    srai x15, x8, 31 # Turn MSB into 0xffffffff or 0x00000000
    add x8, x8, x15
    xor x8, x8, x15

  call um_star

  bge x10, zero, 1f
    call dnegate

1:pop_x1_x10
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "/" # ( n1 n2 -- n1/n2 )
# -----------------------------------------------------------------------------
  push x1
  call divmod
  nip
  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "mod" # ( n1 n2 -- n1%n2 )
# -----------------------------------------------------------------------------
  push x1
  call divmod
  drop
  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "u/mod" # ( u1 u2 -- rem quot )
u_divmod:
# -----------------------------------------------------------------------------
  push x10
  popda x10

  # Catch divide by zero...
  bne x10, zero, 1f
    li x15, -1           # Ergebnis -1, um mit dem RISC-V-Verhalten konsistent zu sein. Für ARM: Ergebnis Null.
    j u_divmod_finished  # Alles ist Rest
1:

  li x14, 1    # Zähler
  li x15, 0    # Ergebnis

  # Shift left the denominator until it is greater than the numerator
  bgeu x10, x8, 3f
  blt x10, zero, 3f # Don't shift if denominator would overflow

2:  slli x14, x14, 1
    slli x10, x10, 1
    blt x10, zero, 3f
    bltu x10, x8, 2b

3:bltu x8, x10, 4f    # if (num>denom)
    sub x8, x8, x10      # numerator -= denom
    or x15, x15, x14     # result(x15) |= bitmask(x14)

4:srli x10, x10, 1    # denom(x10) >>= 1
  srli x14, x14, 1    # bitmask(x14) >>= 1
  bne x14, zero, 3b

u_divmod_finished:
  pushda x15
  pop x10
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2, "/mod" # ( n1 n2 -- rem quot )
divmod:
# -----------------------------------------------------------------------------
  push x1
  #  x8         # Divisor
  lw x15, 0(x9) # Dividend

  bge x15, zero, divmod_plus # Prüfe den Dividenden
  sub x15, zero, x15
  sw x15, 0(x9)

divmod_minus:
    bge x8, zero, divmod_minus_plus

divmod_minus_minus:
      sub x8, zero, x8
      call u_divmod
      lw x15, 0(x9)
      sub x15, zero, x15
      sw x15, 0(x9)
      j divmod_finished

divmod_minus_plus:
      call u_divmod
      lw x15, 0(x9)
      sub x15, zero, x15
      sw x15, 0(x9)
      sub x8, zero, x8
      j divmod_finished

divmod_plus:
    bge x8, zero, divmod_plus_plus

divmod_plus_minus:
      sub x8, zero, x8
      call u_divmod
      sub x8, zero, x8
      j divmod_finished

divmod_plus_plus:
      call u_divmod

divmod_finished:
  pop x1
  ret
