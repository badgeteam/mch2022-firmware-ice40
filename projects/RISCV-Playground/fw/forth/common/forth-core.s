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

.else
  .macro call destination
    jal \destination
  .endm
.endif

.include "../common/datastackandmacros.s"

# -----------------------------------------------------------------------------
#   Type of flash memory
# -----------------------------------------------------------------------------

  .ifdef erasedflashcontainszero
    .equ erasedbyte, 0
    .equ erasedhalfword, 0
    .equ erasedword, 0

    .equ writtenhalfword, 0xFFFF
    .equ writtenword, 0xFFFFFFFF
  .else
    .equ erasedbyte,     0xFF
    .equ erasedhalfword, 0xFFFF
    .equ erasedword,     0xFFFFFFFF

    .equ writtenhalfword, 0
    .equ writtenword, 0
  .endif

# -----------------------------------------------------------------------------
#   Dictionary header macro
# -----------------------------------------------------------------------------

.macro Definition Flags, Name
    .balign 4, 0
    .equ Dictionary_\@, .  # Labels for a more readable assembler listing only

9:  .word 9f          # Insert Link
    .word \Flags      # Flag field

    .byte 8f - 7f     # Calculate length of name field
7:  .ascii "\Name"    # Insert name string

.ifdef compressed_isa
8:  .balign 2, 0      # Realign
.else
8:  .balign 4, 0      # Realign
.endif

    .equ Code_\@, .        # Labels for a more readable assembler listing only
.endm


.macro Definition_EndOfCore Flags, Name
    .balign 4, 0
    .equ Dictionary_\@, .  # Labels for a more readable assembler listing only

     .ifdef flash8bytesblockwrite
9:      .word FlashDictionaryAnfang + 0x04 # Insert Link with offset because of alignment issues.
     .else
9:      .word FlashDictionaryAnfang        # Link einfügen  Insert Link
     .endif

    .word \Flags      # Flag field

    .byte 8f - 7f     # Calculate length of name field
7:  .ascii "\Name"    # Insert name string

.ifdef compressed_isa
8:  .balign 2, 0      # Realign
.else
8:  .balign 4, 0      # Realign
.endif

    .equ Code_\@, .        # Labels for a more readable assembler listing only
.endm

.ifdef erasedflashcontainszero
  .equ Flag_invisible,  0x00000000  # Erased Flash needs to give invisible Flags.
  .equ Flag_visible,    0x80000000
.else
  .equ Flag_invisible,  0xFFFFFFFF
  .equ Flag_visible,    0x00000000
.endif


.equ Flag_immediate,  Flag_visible | 0x0010
.equ Flag_inline,     Flag_visible | 0x0020
.equ Flag_immediate_compileonly, Flag_visible | 0x0030 # Immediate + Inline

.equ Flag_ramallot,   Flag_visible | 0x0080      # Ramallot means that RAM is reserved and initialised by catchflashpointers for this definition on startup
.equ Flag_variable,   Flag_ramallot| 1           # How many 32 bit locations shall be reserved ?
.equ Flag_2variable,  Flag_ramallot| 2

.equ Flag_foldable,   Flag_visible | 0x0040 # Foldable when given number of constants are available.
.equ Flag_foldable_0, Flag_visible | 0x0040
.equ Flag_foldable_1, Flag_visible | 0x0041
.equ Flag_foldable_2, Flag_visible | 0x0042
.equ Flag_foldable_3, Flag_visible | 0x0043
.equ Flag_foldable_4, Flag_visible | 0x0044
.equ Flag_foldable_5, Flag_visible | 0x0045
.equ Flag_foldable_6, Flag_visible | 0x0046
.equ Flag_foldable_7, Flag_visible | 0x0047

.equ Flag_buffer, Flag_visible | 0x0100
.equ Flag_buffer_foldable, Flag_buffer|Flag_foldable

# Different from Mecrisp-Stellaris ! Opcodability is independent of constant folding flags in Mecrisp-Quintus.
# This greatly simplifies this optimisation.

.equ Flag_opcodierbar, Flag_visible | 0x200
.equ Flag_undefined,   Flag_visible | 0xBD4A3BC0

# -----------------------------------------------------------------------------
# Makros zum Bauen des Dictionary
# Macros for building dictionary
# -----------------------------------------------------------------------------

# Für initialisierte Variablen am Ende des RAM-Dictionary
# For initialised variables at the end of RAM-Dictioanary that are recognized by catchflashpointers

.macro CoreVariable, Name #  Benutze den Mechanismus, um initialisierte Variablen zu erhalten.
  .set CoreVariablenPointer, CoreVariablenPointer - 4
  .equ \Name, CoreVariablenPointer
.endm

.macro DoubleCoreVariable, Name #  Benutze den Mechanismus, um initialisierte Variablen zu erhalten.
  .set CoreVariablenPointer, CoreVariablenPointer - 8
  .equ \Name, CoreVariablenPointer
.endm

.macro ramallot Name, Menge         # Für Variablen und Puffer zu Beginn des Rams, die im Kern verwendet werden sollen.
  .equ \Name, rampointer            # Uninitialisiert.
  .set rampointer, rampointer + \Menge
.endm

# -----------------------------------------------------------------------------
# Festverdrahtete Kernvariablen, Puffer und Stacks zu Begin des RAMs
# Hardwired core variables, buffers and stacks at the begin of RAM
# -----------------------------------------------------------------------------

.set rampointer, RamAnfang  # Ram-Anfang setzen  Set location for core variables.

# Variablen des Kerns  Variables of core that are not visible
# Variablen für das Flashdictionary  Variables for Flash management

ramallot Dictionarypointer, 4        # These five variables need to be exactly in this order in memory.
ramallot ZweitDictionaryPointer, 4   # Dictionarypointer +  4
ramallot Fadenende, 4                # Dictionarypointer +  8
ramallot ZweitFadenende, 4           # Dictionarypointer + 12
ramallot VariablenPointer, 4         # Dictionarypointer + 14

ramallot konstantenfaltungszeiger, 4
ramallot leavepointer, 4
ramallot Einsprungpunkt, 4

ramallot FlashFlags, 4

.ifdef within_os # Specials for Linux targets
  ramallot arguments, 4
.endif

.equ Zahlenpufferlaenge, 63 # Zahlenpufferlänge+1 sollte durch 4 teilbar sein !      Number buffer (Length+1 mod 4 = 0)
ramallot Zahlenpuffer, Zahlenpufferlaenge+1 # Reserviere mal großzügig 64 Bytes RAM für den Zahlenpuffer

  ramallot datenstackende, 512  # Data stack
  ramallot datenstackanfang, 0

  ramallot returnstackende, 512  # Return stack
  ramallot returnstackanfang, 0

.equ Maximaleeingabe,    200             # Input buffer for an Address-Length string
ramallot Eingabepuffer, Maximaleeingabe  # Eingabepuffer wird einen Adresse-Länge String enthalten

.ifdef flash8bytesblockwrite
  .equ Sammelstellen, 32 # 32 * (8 + 4) = 384 Bytes
  ramallot Sammeltabelle, Sammelstellen * 12 # Buffer 32 blocks of 8 bytes each for ECC constrained Flash write
.endif

.equ RamDictionaryAnfang, rampointer # Ende der Puffer und Variablen ist Anfang des Ram-Dictionary.  Start of RAM dictionary
.equ RamDictionaryEnde,   RamEnde    # Das Ende vom Dictionary ist auch das Ende vom gesamten Ram.   End of RAM dictionary = End of RAM


# -----------------------------------------------------------------------------
#  Macros for "typesetting" :-)
# -----------------------------------------------------------------------------

.macro write Meldung
  call dotgaensefuesschen
        .byte 8f - 7f         # Compute length of string.
7:      .ascii "\Meldung"

.ifdef compressed_isa
8:  .balign 2, 0      # Realign
.else
8:  .balign 4, 0      # Realign
.endif

.endm

.macro writeln Meldung
  call dotgaensefuesschen
        .byte 8f - 7f         # Compute length of string.
7:      .ascii "\Meldung\n"

.ifdef compressed_isa
8:  .balign 2, 0      # Realign
.else
8:  .balign 4, 0      # Realign
.endif

.endm

.macro welcome Meldung
  call dotgaensefuesschen
        .byte 8f - 7f         # Compute length of string.
7:      .ascii "Mecrisp-Quintus 0.37\Meldung\n"

.ifdef compressed_isa
8:  .balign 2, 0      # Realign
.else
8:  .balign 4, 0      # Realign
.endif

.endm

# -----------------------------------------------------------------------------
# Vorbereitung der Dictionarystruktur
# Preparations for dictionary structure
# -----------------------------------------------------------------------------
.balign 4, 0
CoreDictionaryAnfang: # Dictionary-Einsprungpunkt setzen
                      # Set entry point for Dictionary

.set CoreVariablenPointer, RamDictionaryEnde # Im Flash definierte Variablen kommen ans RAM-Ende
                                             # Variables defined in Flash are placed at the end of RAM

  Definition Flag_invisible, "--- Mecrisp-Quintus 0.37 ---"

.include "flash.s"

.ifdef flash8bytesblockwrite # Needs to be at the beginning for proper ifdef detection
.include "../common/flash8bytesblockwrite.s"
.endif

.include "../common/stackjugglers.s"
.include "../common/comparisions.s"
.include "../common/calculations.s"

.include "terminal.s"

.include "../common/query.s"
.include "../common/strings.s"
.include "../common/deepinsight.s"
.include "../common/token.s"
.include "../common/buildsdoes.s"
.include "../common/compiler.s"
.include "../common/compiler-flash.s"
.include "../common/doloop.s"
.include "../common/case.s"
.include "../common/controlstructures.s"
.include "../common/logic.s"
.include "../common/interpreter.s"
.include "../common/numberstrings.s"
.include "../common/numberoutput.s"

.ifdef mipscore
.include "../common/multiplydivide-mips.s"
.else
  .ifdef softwaremultiply
  .include "../common/multiplydivide-sw.s"
  .else
  .include "../common/multiplydivide.s"
  .endif
.endif

.include "../common/double.s"
.include "../common/memory.s"

# -----------------------------------------------------------------------------
# Schließen der Dictionarystruktur und Zeiger ins Flash-Dictionary
# Finalize the dictionary structure and put a pointer into changeable Flash-Dictionary
# -----------------------------------------------------------------------------

  Definition_EndOfCore Flag_invisible, "--- Flash Dictionary ---"

# -----------------------------------------------------------------------------
#  End of Dictionary
# -----------------------------------------------------------------------------


