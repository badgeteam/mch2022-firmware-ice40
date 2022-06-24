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

# Stackjongleure
# Stack jugglers

# Stack pointers

# -----------------------------------------------------------------------------
  Definition Flag_inline, "sp@" # ( -- a-addr )
# -----------------------------------------------------------------------------
  pushdatos
  mv x8, x9
  ret

# -----------------------------------------------------------------------------
  Definition Flag_inline, "sp!" # ( a-addr -- )
# -----------------------------------------------------------------------------
  mv x9, x8
  drop
  ret

# -----------------------------------------------------------------------------
  Definition Flag_inline, "rp@" # ( -- a-addr )
# -----------------------------------------------------------------------------
  pushdatos
  mv x8, sp
  ret

# -----------------------------------------------------------------------------
  Definition Flag_inline, "rp!" # ( a-addr -- )
# -----------------------------------------------------------------------------
  mv sp, x8
  drop
  ret

# Stack juggling

# -----------------------------------------------------------------------------
  Definition Flag_foldable_1|Flag_inline, "dup" # ( x -- x x )
dup_einsprung:
# -----------------------------------------------------------------------------
  dup
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_1|Flag_inline, "drop" # ( x -- )
drop_einsprung:
# -----------------------------------------------------------------------------
  drop
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_1|Flag_inline, "?dup" # ( x -- 0 | x x )
# -----------------------------------------------------------------------------
  beq x8, zero, 1f
    pushdatos
1:ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "swap" # ( x y -- y x )
# -----------------------------------------------------------------------------
  swap
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "nip" # ( x y -- x )
# -----------------------------------------------------------------------------
  nip
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "over" # ( x y -- x y x )
# -----------------------------------------------------------------------------
over_einsprung:
  pushdatos
  lw x8, 4(x9)
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_2|Flag_inline, "tuck" # ( x1 x2 -- x2 x1 x2 )
# -----------------------------------------------------------------------------
tuck:
  lw x15, 0(x9)
  addi x9, x9, -4
  sw x8, 4(x9)
  sw x15, 0(x9)
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_3, "rot" # ( x w y -- w y x )
# -----------------------------------------------------------------------------
rot:
  lw x15, 0(x9)
  lw x14, 4(x9)
  sw x8, 0(x9)
  sw x15, 4(x9)
  mv x8, x14
  ret

# -----------------------------------------------------------------------------
  Definition Flag_foldable_3, "-rot" # ( x w y -- y x w )
# -----------------------------------------------------------------------------
minusrot:
  lw x15, 0(x9)
  lw x14, 4(x9)
  sw x14, 0(x9)
  sw x8, 4(x9)
  mv x8, x15
  ret

# -----------------------------------------------------------------------------
  Definition Flag_inline, "pick" # ( xu .. x1 x0 u -- xu ... x1 x0 xu )
# -----------------------------------------------------------------------------
pick:
  sll x8, x8, 2
  add x8, x8, x9
  lw x8, 0(x8)
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "depth" # ( -- Zahl der Elemente, die vorher auf den Datenstack waren )
                                  # ( -- Number of elements that have been on datastack before )
# -----------------------------------------------------------------------------
  # Berechne den Stackfüllstand
  laf x15, datenstackanfang # Anfang laden  Calculate stack fill gauge
  sub x15, x15, x9          # und aktuellen Stackpointer abziehen
  pushdatos
  srai x8, x15, 2 # Durch 4 teilen  Divide through 4 Bytes/element.
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "rdepth"
# -----------------------------------------------------------------------------
  # Berechne den Stackfüllstand
  laf x15, returnstackanfang # Anfang laden  Calculate stack fill gauge
  sub x15, x15, sp          # und aktuellen Stackpointer abziehen
  pushdatos
  srai x8, x15, 2 # Durch 4 teilen  Divide through 4 Bytes/element.
  ret

#------------------------------------------------------------------------------
  Definition Flag_inline, ">r" # Legt das oberste Element des Datenstacks auf den Returnstack.
#------------------------------------------------------------------------------
  push x8
  drop
  ret

#------------------------------------------------------------------------------
  Definition Flag_inline, "r>" # Holt das zwischengespeicherte Element aus dem Returnstack zurück
#------------------------------------------------------------------------------
  pushdatos
  pop x8
  ret

#------------------------------------------------------------------------------
  Definition Flag_inline, "r@" # Kopiert das oberste Element des Returnstacks auf den Datenstack
#------------------------------------------------------------------------------
  pushdatos
  lw x8, 0(sp)
  ret

#------------------------------------------------------------------------------
  Definition Flag_inline, "rdrop" # Entfernt das oberste Element des Returnstacks
#------------------------------------------------------------------------------
  addi sp, sp, 4
  ret

# -----------------------------------------------------------------------------
  Definition Flag_inline, "rpick" # ( u -- xu R: xu .. x1 x0 -- xu ... x1 x0 )
# -----------------------------------------------------------------------------
  sll x8, x8, 2
  add x8, x8, sp
  lw x8, 0(x8)
  ret

# # -----------------------------------------------------------------------------
#   Definition Flag_visible, "roll" # ( xu xu-1 ... x0 u -- xu-1 ... x0 xu )
# roll:
# # -----------------------------------------------------------------------------
#   # 2 ROLL is equivalent to ROT, 1 ROLL is equivalent to SWAP and 0 ROLL is a null operation.
#   # TOS enthält das Element, welches am Ende nach oben rutschen soll.
#
#   cmp tos, #0 # No moves ?
#   bne 1f
#     drop
#     bx lr
#
# 1:lsls r0, tos, #2
#   ldr r1, [psp, r0] # Pick final TOS value temporarily into r1
#
#   # One element is removed from the stack, let all other values fall down one place
#
#   # (  5  4  3  2  1   TOS: 4)
#   # (  5     3  2  1 )
#   # (  5  3  2  1    )
#   # ( 16 12  8  4  0
#
#
#   # TOS contains number of moves, r0 number of bytes offset from stack pointer
#
#   # Wo fange ich an ?
#   # In der Lücke, die sich aufgetan hat. Lasse nachrutschen !
#   # Also holen: Eine Stelle über der Lücke
#   # Einfügen direkt in der Lücke.
#
#   # Lückenadresse = psp + r0
#
#   # Lege von psp + r0 - 4 an die Stelle psp + r0.
#
#     adds r0, psp
#
# 2:  subs r3, r0, #4   # Dies hier noch ein bisschen verschönern ! Funktioniert aber schonmal.
#     ldr r2, [r3]
#     str r2, [r0]
#     subs r0, #4
#
#     subs tos, #1
#     bne 2b
#
#   adds psp, #4 # Element entfernen
#
# 3:# Finished shifting of stack. Load result into TOS.
#   movs tos, r1
#   bx lr
#
# # -----------------------------------------------------------------------------
#   Definition Flag_visible, "-roll" # ( xu-1 ... x0 xu u -- xu xu-1 ... x0 u )
# minusroll: # Kehrt die Wirkung von roll um.
# # -----------------------------------------------------------------------------
#   # 2 ROLL is equivalent to ROT, 1 ROLL is equivalent to SWAP and 0 ROLL is a null operation.
#   # TOS enthält das Element, welches am Ende nach oben rutschen soll.
#
#   cmp tos, #0 # No moves ?
#   bne 1f
#     drop
#     bx lr
#
#
# 1:# TOS contains number of moves.
#
#   ldr r0, [psp] # Das jetztige NOS soll später in die Lücke hinein, wird aber überschrieben.
#
#   # (  5  4  3  2  1  X   TOS: 4)
#   # (  5  4  4  3  2  1 )
#   # (  5  X  4  3  2  1 )
#
#   # Beginne direkt beim Stackpointer:
#   mov r1, psp
#
# 2:# Mache nun die gewünschte Zahl von Schüben:
#   ldr r2, [r1, #4]
#   str r2, [r1]
#   adds r1, #4
#   subs tos, #1
#   bne 2b
#
#   # Lege das NOS-Element in die Lücke
#   str r0, [r1]
#
#   # Vergiss den Zähler in TOS
#   drop
#   bx lr
#
