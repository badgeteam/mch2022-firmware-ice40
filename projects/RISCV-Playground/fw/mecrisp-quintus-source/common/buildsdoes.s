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

.ifdef mipscore

# -----------------------------------------------------------------------------
insert_jalrx8: # ( Ziel Opcodelücke -- )
# -----------------------------------------------------------------------------
  push_x1_x10

  popda x10 # Opcodelücke

  dup
  # High-Part
  srli x8, x8, 16
  li x15, 0x3C000000 | reg_tmp1 << 16 # lui x15, 0
  or x8, x8, x15
  pushda x10
  call kommairgendwo

  # Low-Part
  andi x8, x8, 0xFFFF
  li x15, 0x34000000 | reg_tmp1 << 21 | reg_tmp1 << 16 # ori x15, x15, 0
  or x8, x8, x15
  pushda x10
  addi x8, x8, 4
  pop_x1_x10
  j kommairgendwo

.else

# -----------------------------------------------------------------------------
insert_jalrx8: # ( Ziel Opcodelücke -- )
# -----------------------------------------------------------------------------
  push_x1_x10

  popda x10 # Opcodelücke

  # Korrektur fürs negative Vorzeichen
  li x15, 0x800
  and x15, x15, x8
  beq x15, zero, 1f
    li x15, 0x00001000
    add x8, x8, x15
1:

  dup
  li x15, 0xFFFFF000
  and x8, x8, x15
  ori  x8, x8, 0x00000037 | reg_tmp1 << 7 # lui x15, ...

  pushda x10
  call kommairgendwo

  sll x8, x8, 20
  li x15, 0x00000067 | reg_tos << 7 | reg_tmp1 << 15 # jalr x8, x15, 0
  or x8, x8, x15

  pushda x10
  addi x8, x8, 4
  pop_x1_x10
  j kommairgendwo

.endif

# -----------------------------------------------------------------------------
  Definition Flag_inline, "does>"
does: # Gives freshly defined word a special action.
      # Has to be used together with <builds !
# -----------------------------------------------------------------------------
    # At the place where does> is used, a jump to dodoes is inserted and
    # after that a R> to put the address of the definition entering the does>-part
    # on datastack. This is a very special implementation !

  pushdatos
  # Den Aufruf mit absoluter Adresse einkompilieren. Perform this call with absolute addressing.
  .ifdef mipscore
    la x15, dodoes
    jalr x8, x15
  .else
    lui x15, %hi(dodoes)
    jalr x8, x15, %lo(dodoes)
  .endif

  ret # Very important as delimiter as does> itself is inline.

dodoes:
  # On the stack: ( Address-to-call R: Return-of-dodoes-itself )
  # Now insert a call into the latest definition which was hopefully prepared by <builds

  # Save and change dictionary pointer to insert a call sequence:

  push x1

  pushdaaddrf Einsprungpunkt
  lw x8, 0(x8)

  .ifdef compressed_isa
    addi x8, x8, 8    # Skip pop x1 and pushdatos opcodes
    andi x15, x8, 2   # Align on 4
    add x8, x8, x15
  .else
    addi x8, x8, 16 # Skip pop x1 and pushdatos opcodes
  .endif

  .ifdef flash8bytesblockwrite
    dup
    call addrinflash
    popda x15
    beq x15, zero, 1f

      andi x15, x8, 7
      beq x15, zero, 1f

        addi x8, x8, 4
1:
  .endif

  # ( Ziel Opcodelücke )
  call insert_jalrx8

  call smudge

  addi sp, sp, 4 # Skip one return layer
  pop x1
  ret

#------------------------------------------------------------------------------
  Definition Flag_visible, "<builds"
builds: # Brother of does> that creates a new definition and leaves space to insert a call instruction later.
#------------------------------------------------------------------------------
  push x1
  call create # Create new empty definition
  call push_x1_komma # Write opcodes for push x1

  call dup_komma

  .ifdef compressed_isa
    call align4komma
  .endif

  .ifdef flash8bytesblockwrite

    call compiletoramq
    popda x15
    bne x15, zero, 1f

      call here
      andi x15, x8, 7
      drop
      beq x15, zero, 1f # Address and 7 will be either 0 or 4 and shall be aligned on 8.

      .ifdef mipscore
        pushdaconst 0x00000025 # nop
      .else
        pushdaconst 0x00000013 # nop
      .endif
      call komma

1:
  .endif

  pushdaconst 8 # A call instruction or its preparation will go here - but I don't know its target address for now.
  call allot # Make a hole to insert the destination later.

  .ifdef mipscore
    pushdaconst 0x00000009 | reg_tos << 11 | reg_tmp1 << 21 # jalr x8, x15
    call komma

    pushdaconst 0x00000025 # nop = or zero, zero, zero  Wichtig, damit keine Flash-Ende-Füllung angefügt wird.
    call komma
  .endif

  pop x1
  ret

#------------------------------------------------------------------------------
  Definition Flag_visible, "create" # ANS-Create with default action.
#------------------------------------------------------------------------------
  push x1
  call builds
  # Copy of the inline-code of does>
  pushdatos
  .ifdef mipscore
    laf x15, dodoes
    jalr x8, x15
  .else
    lui x15, %hi(dodoes)
    jalr x8, x15, %lo(dodoes)
  .endif
  pop x1
  ret
