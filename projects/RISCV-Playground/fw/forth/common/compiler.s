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

# Die Routinen, die nötig sind, um neue Definitionen zu kompilieren.
# The compiler - parts that are the same for Flash and for Ram.

# -----------------------------------------------------------------------------
  Definition Flag_visible, "registerliteral," # ( x Register -- )
registerliteralkomma: # Compile code to put a literal constant into a register.
# -----------------------------------------------------------------------------
  .ifdef mipscore

  beq x8, zero, ddrop_vektor # Der Null-Register soll nie geladen werden

  push_x1_x10
  popda x10 # Target register

  # 16 bit unsigned constant ?
  li x15, 0xFFFF0000 # Possible range for ori opcode
  and x14, x8, x15
  bne x14, zero, 1f

    li x14, 0x34000000 # ori zero, zero, 0
4:  andi x8, x8, 0xFFFF
    slli x15, x10, 16
    or x8, x8, x15
    or x8, x8, x14
    call komma
    j 3f


1:# Sign + 15 bit negative constant ?
  li x15, 0xFFFF8000 # Possible range for addiu opcode
  and x14, x8, x15
  bne x15, x14, 2f
    li x14, 0x24000000 # addiu zero, zero, 0
    j 4b


2:# Long literal with two opcodes
  dup

  # High-Part
  srli x8, x8, 16
  slli x15, x10, 16
  or x8, x8, x15
  li x15, 0x3C000000 # lui zero, 0
  or x8, x8, x15
  call komma

  # Low-Part
  andi x8, x8, 0xFFFF
  bne x8, zero, 5f
    drop # Falls die Konstante für ORI 0 ist, brauche ich keinen ORI-Opcode zu schreiben.
    j 3f

5:slli x15, x10, 16
  or x8, x8, x15
  slli x15, x10, 16+5
  or x8, x8, x15
  li x14, 0x34000000 # ori zero, zero, 0
  or x8, x8, x14
  call komma

3:pop_x1_x10
  ret

  .else

  beq x8, zero, ddrop_vektor # Der Null-Register soll nie geladen werden

  push_x1_x10
  popda x10 # Target register

  # Probe, ob sich die Konstante nicht auch kürzer laden lässt:

  li x15, 0xFFFFF800
  and x14, x8, x15
  beq x14, x15, 1f
  bne x14, zero, 2f

1:# Kurze Variante mit nur einem Opcode.

  .ifdef compressed_isa
    # Passende Konstante ?
    li x15, 0xFFFFFE0
    and x14, x8, x15
    beq x14, x15, 6f
    bne x14, zero, 7f

6:  # Generiere c.li Opcodes
    andi x15, x8, 0x1f # Maskiere die Konstante
    slli x15, x15, 2

    srli x14,  x8, 31 # Schiebe das Vorzeichenbit auf Position 12
    slli x14, x14, 12

    li x8, 0x4001
    or x8, x8, x15
    or x8, x8, x14
    slli x10, x10, 7
    or x8, x8, x10
    call hkomma
    j 4f

7:
  .endif

  sll x8, x8, 20
  li x15, 0x4013 # xori x0, x0, ...
  sll x14, x10, 7  # Zielregister
  or  x15, x15, x14  #  hinzuverodern
  or x8, x8, x15
  call komma
  j 4f

2:# Lange Variante mit zwei Opcodes.

  # Korrektur fürs negative Vorzeichen im xori-Opcode:
  li x15, 0x800
  and x15, x15, x8
  beq x15, zero, 3f
    li x15, 0xFFFFF000
    xor x8, x8, x15
3:

  .ifdef compressed_isa
    li x15, 2 # Prüfe, ob es nicht x2 ist
    beq x10, x15, 6f # Passt nicht, langen Opcode schreiben

    # Prüfe, ob die Konstante in c.lui passt. Bits 17:12, mit Vorzeichenerweiterung.
    li x15, 0xFFFE0000
    and x14, x8, x15
    beq x14, x15, 1f   # Passt.
    bne x14, zero, 6f  # Passt nicht, langen Opcode schreiben

1:    # c.lui schreiben
      dup

      srai x8, x8, 10
      li x15, 0x107C # Bitmaske
      and x8, x8, x15

      li x15, 0x6001 # c.lui
      or x8, x8, x15

      slli x14, x10, 7 # Zielregister
      or x8, x8, x14

      call hkomma
      j 7f
  .endif

6:dup
  li x15, 0xFFFFF000
  and x8, x8, x15
  ori  x8, x8, 0x000000037  # lui x0, ...
  slli x14, x10, 7  # Zielregister
  or  x8, x8, x14  #  hinzuverodern
  call komma

7:slli x8, x8, 20
  bne x8, zero, 5f
    drop # Falls die Konstante für XORI 0 ist, brauche ich keinen XORI-Opcode zu schreiben.
    j 4f

5:li x15, 0x4013 # xori x0, x0, ...
  slli x14, x10, 7  # Zielregister
  or  x15, x15, x14  #  hinzuverodern
  slli x14, x10, 15 # Quellregister
  or  x15, x15, x14  #  hinzuverodern
  or x8, x8, x15
  call komma

4:pop_x1_x10
  ret
  .endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "literal," # ( x -- )
literalkomma:
# -----------------------------------------------------------------------------
  push x1
  call dup_komma

  pushdaconst reg_tos
  pop x1
  j registerliteralkomma

dup_komma:
  pushdaaddr dup_einsprung
  j inlinekomma

# -----------------------------------------------------------------------------
  Definition Flag_visible, "call," # ( x -- )
callkomma: # Hier kann ich noch eine Probe einfügen, ob ich nicht auch einen kurzen JAL-Opcode generieren könnte. ***
# -----------------------------------------------------------------------------

  .ifdef mipscore

  push x1

  # Take care of 256 MB borders ! Important for reaching Flash <--> RAM in real MIPS cores. ****

  call here
  popda x15
  li x14, 0xF0000000
  and x15, x15, x14
  and x14, x8, x14
  beq x15, x14, 1f

  # Generate long call sequence

  pushdaconst reg_tmp1
  call registerliteralkomma

  pushdaconst 0x0000F809 | reg_tmp1 << 21 # jalr x1, x15
  call komma
  j 2f

1:# Generate JAL opcode
  srli x8, x8, 2
  li x15, 0x03FFFFFF
  and x8, x8, x15
  li x15, 0x0C000000
  or  x8, x8, x15
  call komma

2: # Fill nop into branch delay slot
  pushdaconst 0
  call komma

  pop x1
  ret

  .else

  push x1

  dup
  call here
  call minus

  .ifdef compressed_isa
    call cj_encoding_q
    popda x15
    beq x15, zero, 3f
      # Ein ganz kurzer C.JAL-Opcode ist möglich !
      nip
      li x15, 0x2001 # c.jal
      or x8, x8, x15
      pop x1
      j hkomma

3:
  .endif

  call uj_encoding_q
  popda x15
  beq x15, zero, 2f

    # Kurzer JAL-Opcode ist möglich !
    nip
    li x15, 0x000000ef # jal x1, 0
    or x8, x8, x15
    pop x1
    j komma


2:drop
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
  ori  x8, x8, 0x00000037 | reg_tmp1 << 7  # lui x15, ...
  call komma

  sll x8, x8, 20
  li x15, 0x000000e7 | reg_tmp1 << 15 # jalr x1, x15, 0
  or x8, x8, x15
  pop x1
  j komma

  .endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "inline," # ( x -- )
inlinekomma:
# -----------------------------------------------------------------------------

  .ifdef mipscore

# Original:
#       push_x1_x10
#
#     1:lw x10, 0(x8)
#       li x15, 0x03e00008 # Ret-Opcode
#       beq x10, x15, 2f
#
#         pushda x10
#         call komma
#         addi x8, x8, 4
#         j 1b
#
#     2:lw x8, 4(x8) # Check branch delay slot for an additional opcode.
#       beq x8, zero, 3f
#
#         call komma
#         j 4f
#
#     3:drop
#     4:pop_x1_x10
#       ret

# Jetzt mit der Frame-Erkennung, um auch selbstdefiniertes inline einfügen zu können.

  push_x1_x10

  # -------------------------------------
  lw x10, 0(x8)
  li x15, 0x2442FFFC  # addiu $2, $2, FFFC
  bne x10, x15, 1f

    lw x10, 4(x8)
    li x15, 0xAC5F0000  # sw $31, 0000($2)
    bne x10, x15, 1f

      addi x8, x8, 8     # Do not inline these if they appear as the first opcodes in a definition
  # -------------------------------------

1:

  # -------------------------------------
  lw x10, 0(x8)
  li x15, 0x8C5F0000  # lw $31, 0000($2)
  bne x10, x15, 5f

    lw x10, 4(x8)
    li x15, 0x03E00008  # jr $zero, $31, $zero
    bne x10, x15, 5f

      lw x10, 8(x8)
      li x15, 0x24420004  # addiu $2, $2, 0004
      beq x10, x15, 3f
5:
  # -------------------------------------

  lw x10, 0(x8)
  li x15, 0x03e00008 # Ret-Opcode
  beq x10, x15, 2f

    pushda x10
    call komma
    addi x8, x8, 4
    j 1b

2:lw x8, 4(x8) # Check branch delay slot for an additional opcode.
  beq x8, zero, 3f

    call komma
    j 4f

3:drop
4:pop_x1_x10
  ret

  .else

  .ifdef compressed_isa

  push_x1_x10_x11

  # -------------------------------------

  lhu x15, 0(x8)
  li x14, 0x1171
  bne x15, x14, 1f

    lhu x15, 2(x8)
    li x14, 0xC006
    bne x15, x14, 1f

      addi x8, x8, 4 # Do not inline these if they appear as the first opcodes in a definition

1:# -------------------------------------

  lhu x15, 0(x8)
  li x14, 0x4082
  bne x15, x14, 2f

    lhu x15, 2(x8)
    li x14, 0x0111
    bne x15, x14, 2f

      lhu x15, 4(x8)
      li x14, 0x8082
      beq x15, x14, 4f

2:# -------------------------------------

  lhu x15, 0(x8)
  li x14, 0x8082
  beq x15, x14, 4f

#    # -------------------------------------
#    # Auch die langen RET-Opcodes erkennen...
#    lhu x15, 0(x8)
#    li x14, 0x8067
#    bne x15, x14, 2f
#
#      lhu x15, 2(x8)
#      beq x15, zero, 4f
#
#  2:# -------------------------------------

  lhu x15, 0(x8)
  andi x14, x15,  3
  addi x14, x14, -3
  bne zero, x14, 3f

    dup             # Long opcodes, low part
    lhu x8, 0(x8)
    call hkomma
    addi x8, x8, 2

3:dup               # Compressed opcodes, or high part of long opcode
  lhu x8, 0(x8)
  call hkomma
  addi x8, x8, 2

  j 1b
  # -------------------------------------

4:drop
  pop_x1_x10_x11
  ret

  .else

# Original:
#       push_x1_x10
#
#     1:lw x10, 0(x8)
#       li x15, 0x00008067 # Ret-Opcode
#       beq x10, x15, 2f
#
#         pushda x10
#         call komma
#         addi x8, x8, 4
#         j 1b
#
#     2:drop
#       pop_x1_x10
#       ret


# Jetzt mit der Frame-Erkennung, um auch selbstdefiniertes inline einfügen zu können.

  push_x1_x10

  # -------------------------------------
  lw x10, 0(x8)
  li x15, 0xFFC10113  # addi   x2, x2, -4
  bne x10, x15, 1f

    lw x10, 4(x8)
    li x15, 0x00112023  # sw     x1, 0 (x2)
    bne x10, x15, 1f

      addi x8, x8, 8     # Do not inline these if they appear as the first opcodes in a definition
  # -------------------------------------

1:

  # -------------------------------------
  lw x10, 0(x8)
  li x15, 0x00012083  # lw     x1, 0 (x2)
  bne x10, x15, 2f

    lw x10, 4(x8)
    li x15, 0x00410113  # addi   x2, x2, 4
    bne x10, x15, 2f

      lw x10, 8(x8)
      li x15, 0x00008067  # jalr   zero, 0 (x1) Ret-Opcode
      beq x10, x15, 3f
2:
  # -------------------------------------

  lw x10, 0(x8)
  li x15, 0x00008067 # Ret-Opcode
  beq x10, x15, 3f

    pushda x10
    call komma
    addi x8, x8, 4
    j 1b

3:drop
  pop_x1_x10
  ret

  .endif

  .endif



# -----------------------------------------------------------------------------
  Definition Flag_visible, "skipdefinition" # ( addr -- addr )
suchedefinitionsende:
# -----------------------------------------------------------------------------
  .ifdef mipscore

  li x14, 0x03e00008 # Ret-Opcode

1:lw x15, 0(x8)
  addi x8, x8, 4
  bne x15, x14, 1b

  addi x8, x8, 4 # Skip branch delay slot
  ret

  .else

  .ifdef compressed_isa

1:lhu x15, 0(x8)

  andi x14, x15,  3
  addi x14, x14, -3
  beq zero, x14, 2f

    # Compressed opcode
    addi x8, x8, 2
    li x14, 0x00008082
    beq x15, x14, 3f
    j 1b

2:# Long opcode
    addi x8, x8, 4
    j 1b

#    Erkennung für lange RET-Opcodes:
#    li x14, 0x00008067
#    bne x15, x14, 1b
#
#      lhu x15, -2(x8)
#      bne x15, zero, 1b

3:ret

  .else

  li x14, 0x00008067 # Ret-Opcode

1:lw x15, 0(x8)
  addi x8, x8, 4
  bne x15, x14, 1b

  ret
  .endif

  .endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "string," # ( c-addr length -- )
stringkomma: # Fügt ein String an das Dictionary an  Write a string in Dictionary.
# -----------------------------------------------------------------------------
  push_x1_x10_x13

  andi x10, x8, 0xFF   # Maximum counted string length
  lw x11, 0(x9)        # Fetch address of string
  addi x9, x9, 4
  call clearbytes
  call addbyte # Strings begins with its length byte

1:beq x10, zero, 2f
  pushdatos
  lbu x8, 0(x11)
  call addbyte
  addi x10, x10, -1
  addi x11, x11,  1
  j 1b

2:call flushbytes

  pop_x1_x10_x13
  ret

addbyte:
  sll x8, x8, x12
  or x13, x13, x8
  drop
  addi x12, x12, 8
  .ifdef compressed_isa
  li x15, 16
  .else
  li x15, 32
  .endif
  bne x12, x15, retbytes
flushbytes:
  beq x12, zero, clearbytes
  push x1
  pushda x13
  .ifdef compressed_isa
  call hkomma
  .else
  call komma
  .endif

  pop x1
clearbytes:
  li x12, 0 # How many bytes already written ?
  li x13, 0 # Data which needs to be flushed later
retbytes:
  ret

#------------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "[']" # Sucht das nächste Wort im Eingabestrom  Searches the next token in input buffer and compiles its entry point as literal.
#------------------------------------------------------------------------------
  j tick # So sah das mal aus: ['] ' immediate 0-foldable ;

# -----------------------------------------------------------------------------
  Definition Flag_visible, "'" # Searches next token in unput buffer and gives back its code entry point.
tick: # Nimmt das nächste Token aus dem Puffer, suche es und gibt den Einsprungpunkt zurück.
# -----------------------------------------------------------------------------
  push_x1_x10_x11
  call token

    lw x10, 0(x9) # Save string address and length for later use
    mv x11, x8

  call find
  popda x15 # Drop Flags into x15 - used by postpone !

  bne x8, zero, 1f # Probe entry address

    pushdatos
    sw x10, 0(x9)
    mv x8, x11
    j type_not_found_quit

1:pop_x1_x10_x11
  ret

#------------------------------------------------------------------------------
  Definition Flag_immediate_compileonly, "postpone" # Sucht das nächste Wort im Eingabestrom  Search next token and fill it in Dictionary in a special way.
                                       # und fügt es auf besondere Weise ein.
#------------------------------------------------------------------------------
  push x1
  call tick # Stores Flags into x15 !
  # ( Einsprungadresse )

1:andi x14, x15, Flag_immediate & ~Flag_visible # In case definition is immediate: Compile a call to its address.
  bne x14, zero, 4f

2:andi x14, x15, Flag_inline & ~Flag_visible    # In case definition is inline: Compile entry point as literal and a call to inline, afterwards.
  beq x14, zero, 3f
                             # ( Einsprungadresse )
    call literalkomma                  # Einsprungadresse als Konstante einkompilieren
    pushdaaddr inlinekomma
    j 4f                             # zum Aufruf bereitlegen

3:# Normal                     # In case definition is normal: Compile entry point as literal and a call to call, afterwards.
    call literalkomma
    pushdaaddr callkomma

4:  pop x1
    j callkomma

#------------------------------------------------------------------------------
  Definition Flag_immediate_compileonly, "exit" # Kompiliert ein ret mitten in die Definition.
exitkomma:  # Writes a ret opcode into current definition. Take care with inlining !
#------------------------------------------------------------------------------

  # Write opcodes for "pop x1 ret"

  .ifdef mipscore
    push x1
    pushdaconst 0x8C5F0000
    call komma
    pushdaconst 0x03E00008
    call komma
    pushdaconst 0x24420004
    pop x1
    j komma
  .else

    .ifdef compressed_isa
      push x1
      pushdaconst 0x01114082 # Gleich zwei Opcodes auf einmal laden spart Platz
      call komma
      pop x1
      j retkomma
    .else
      push x1
      pushdaconst 0x00012083 # lw	ra,0(sp)
      call komma
      pushdaconst 0x00410113 # addi	sp,sp,4
      call komma
      pop x1
      j retkomma
    .endif

  .endif

#------------------------------------------------------------------------------
retkomma: # Separat, weil MIPS einen Branch Delay Slot NOP braucht.
#------------------------------------------------------------------------------

  .ifdef mipscore
    push x1

    pushdaconst 0x03E00008
    call komma
    pushdaconst 0x00000000
    call komma

    pop x1
    ret
  .else
    .ifdef compressed_isa
      pushdaconst 0x8082 # ret
      j hkomma
    .else
      pushdaconst 0x00008067 # ret
      j komma
    .endif
  .endif

# Some tests:
#  : fac ( n -- n! )   1 swap  1 max  1+ 2 ?do i * loop ;
#  : fac-rec ( acc n -- n! ) dup dup 1 = swap 0 = or if drop else dup 1 - rot rot * swap recurse then ; : facre ( n -- n! ) 1 swap fac-rec ;

#------------------------------------------------------------------------------
  Definition Flag_immediate_compileonly, "recurse" # Für Rekursion. Führt das gerade frische Wort aus. Execute freshly defined definition.
#------------------------------------------------------------------------------
  pushdaaddrf Einsprungpunkt
  lw x8, 0(x8)
  j callkomma

# -----------------------------------------------------------------------------
  Definition Flag_visible|Flag_variable, "state" # ( -- addr )
  CoreVariable state
# -----------------------------------------------------------------------------
  pushdatos
  laf x8, state
  ret
  .word 0

# -----------------------------------------------------------------------------
  Definition Flag_visible|Flag_variable, "(sp)" # ( -- addr )
  CoreVariable Datenstacksicherung
# -----------------------------------------------------------------------------
  pushdatos
  laf x8, Datenstacksicherung
  ret
  .word 0

#------------------------------------------------------------------------------
  Definition Flag_visible, "]" # In den Compile-Modus übergehen  Switch to compile mode
compilemode:
# -----------------------------------------------------------------------------
  li x15, -1
  j 1f

#------------------------------------------------------------------------------
  Definition Flag_immediate, "[" # In den Execute-Modus übergehen  Switch to execute mode
executemode:
# -----------------------------------------------------------------------------
  li x15, 0
1:laf x14, state
  sw x15, 0(x14)
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, ":" # ( -- )
# -----------------------------------------------------------------------------
  push x1

  laf x14, Datenstacksicherung # Setzt den Füllstand des Datenstacks zur Probe.
  sw x9, 0(x14)               # Save current datastack pointer to detect structure mismatch later.

  call create
  call push_x1_komma

  pop x1
  j compilemode


push_x1_komma:

  .ifdef mipscore
    push x1

    pushdaconst 0x2442FFFC
    call komma
    pushdaconst 0xAC5F0000
    call komma

    pop x1
    ret
  .else

    .ifdef compressed_isa
      pushdaconst 0xC0061171 # Gleich zwei Opcodes auf einmal laden spart Platz
      j komma
    .else
      push x1

      pushdaconst 0xffc10113 # addi sp,sp,-4
      call komma
      pushdaconst 0x00112023 # sw ra,0(sp)
      call komma

      pop x1
      ret
    .endif

  .endif

# -----------------------------------------------------------------------------
  Definition Flag_immediate_compileonly, ";" # ( -- )
# -----------------------------------------------------------------------------
  push x1

  laf x14, Datenstacksicherung # Prüft den Füllstand des Datenstacks.
  lw x15, 0(x14)               # Check fill level of datastack.
  beq x15, x9, 1f
    writeln " Stack not balanced."
    j quit
1: # Stack balanced, ok
  call exitkomma

4:call smudge
  pop x1
  j executemode

# -----------------------------------------------------------------------------
  Definition Flag_visible, "execute"
execute:
# -----------------------------------------------------------------------------
  popda x15
  .ifdef mipscore
  jr x15
  .else
  jalr zero, x15, 0
  .endif

# -----------------------------------------------------------------------------
  Definition Flag_immediate, "immediate" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_immediate & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "inline" # ( -- )
setze_inlineflag:
# -----------------------------------------------------------------------------
  pushdaconst Flag_inline & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate, "compileonly" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_immediate_compileonly & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "0-foldable" # ( -- )
setze_faltbarflag:
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_0 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "1-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_1 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "2-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_2 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "3-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_3 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "4-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_4 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "5-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_5 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "6-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_6 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_immediate|Flag_foldable_0, "7-foldable" # ( -- )
# -----------------------------------------------------------------------------
  pushdaconst Flag_foldable_7 & ~Flag_visible
  j setflags

# -----------------------------------------------------------------------------
  Definition Flag_visible, "constant" # ( n -- )
# -----------------------------------------------------------------------------
  push x1
  call create
1:call literalkomma
  call retkomma

  call setze_faltbarflag
  pop x1
  j smudge

# -----------------------------------------------------------------------------
  Definition Flag_visible, "2constant" # ( n -- )
# -----------------------------------------------------------------------------
  push x1
  call create
  swap
  call literalkomma
  j 1b
