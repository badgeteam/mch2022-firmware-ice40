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

# Besondere Teile des Compilers, die mit der Dictionarystruktur im Flash zu tun haben.
# Special parts of compiler tightly linked with generating code for Flash memory.


# -----------------------------------------------------------------------------
  Definition Flag_visible, "smudge" # ( -- )
smudge:
# -----------------------------------------------------------------------------
  push x1

  .ifdef compressed_isa
    call align4komma # Align on 4 to make sure the last opcode is actually written to Flash and to fullfill ANS requirement.
  .endif

  call compiletoramq
  popda x15
  bne x15, zero, smudge_ram

  # -----------------------------------------------------------------------------
  # Smudge for Flash

    .ifdef flash8bytesblockwrite
      call align8komma
    .endif

    # Prüfe, ob am Ende des Wortes ein $FFFF steht. Das darf nicht sein !
    # Es würde als freie Stelle erkannt und später überschrieben werden.
    # Deshalb wird in diesem Fall hier am Ende eine 0 ans Dictionary angehängt.

    # Check if there is $FFFF at the end of the definition.
    # That must not be ! It would be detected as free space on next Reset and simply overwritten.
    # To prevent it a zero is applied at the end in this case.

    call here
    lw x15, -4(x8)
    li x14, erasedword
    drop
    bne x15, x14, 1f
      # writeln "Füge in Smudge eine Enderkennungs-Null ein."
      pushdaconst writtenword
      call komma
1:  # Okay, Ende gut, alles gut. Fine :-)

    # Brenne die gesammelten Flags:  Flash in the collected Flags:
    pushdatos
    laf x8, FlashFlags
    lw x8, 0(x8)

    pushdatos
    laf x8, Fadenende
    lw x8, 0(x8)
    addi x8, x8, 4 # Skip Link field

    call flashstore

    .ifdef flushflash
      call flushflash
    .endif

    pop x1
    ret

  # -----------------------------------------------------------------------------
  # Smudge for RAM

smudge_ram:
  pushdaconst Flag_visible
  j setflags_intern

# -----------------------------------------------------------------------------
  Definition Flag_visible, "setflags" # ( x -- )
setflags: # Setflags collects the Flags if compiling for Flash, because we can write Flash field only once.
          # For RAM, the bits are simply set directly.
# -----------------------------------------------------------------------------

  li x14, Flag_undefined >> 5 # Sichtbarkeit entfernen  Remove visibility
  bne x14, x8, 1f             # Flag gültig ?           Flag valid ?

    la x8, checksums
    j dotnfuesschen

1:push x1 # Flag ok.

setflags_intern:
  call compiletoramq
  popda x15
  bne x15, zero, setflags_ram

  # -----------------------------------------------------------------------------
  # Setflags for Flash
  laf x14, FlashFlags
  lw x15, 0(x14)
  or x15, x15, x8  # Flashflags beginnt von create aus immer mit "Sichtbar" = 0.
  sw x15, 0(x14)
  drop
  pop x1
  ret

  # -----------------------------------------------------------------------------
  # Setflags for RAM
setflags_ram:

  # Hole die Flags des aktuellen Wortes   Fetch flags of current definition
  laf x14, Fadenende # Variable containing pointer to current definition
  lw x14, 0(x14)     # Address of current definition
  lw x15, 4(x14)      # Flags des zuletzt definierten Wortes holen  Fetch its Flags

  push x10
  li x10, -1
  bne x15, x10, 1f
    mv x15, x8     # Direkt setzen, falls an der Stelle noch -1 steht  Set directly, if there are no Flags before
1:  or x15, x15, x8 # Hinzuverodern, falls schon Flags da sind          If there already are Flags, OR them together.
  pop x10

  sw x15, 4(x14)
  drop
  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible|Flag_foldable_1, "aligned" # ( c-addr -- a-addr )
aligned:
# -----------------------------------------------------------------------------
  andi x15, x8, 1
  add x8, x8, x15
  andi x15, x8, 2
  add x8, x8, x15
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "here" # ( -- addr ) Gives Dictionarypointer
here: # Gibt den Dictionarypointer zurück
# -----------------------------------------------------------------------------
  pushdatos    # Platz auf dem Datenstack schaffen
  laf x8, Dictionarypointer
  lw x8, 0(x8) # Hole den Dictionarypointer
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flashvar-here" # ( -- a-addr ) Gives RAM management pointer
flashvarhere:
# -----------------------------------------------------------------------------
  pushdatos
  laf x8, VariablenPointer
  lw x8, 0(x8)
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "addrinflash?" # ( a-addr -- a-addr ) Permanent memory there ?
addrinflash:
# -----------------------------------------------------------------------------
  laf x14, FlashAnfang
  laf x15, FlashEnde
  j 1f

# -----------------------------------------------------------------------------
  Definition Flag_visible, "addrinram?" # ( a-addr -- a-addr ) Volatile memory there ?
# -----------------------------------------------------------------------------
  laf x14, RamAnfang
  laf x15, RamEnde

1:bltu x8, x14, 2f
  bgeu x8, x15, 2f

    li x8, -1
    ret

2:li x8, 0
  ret

  .ifdef flash8bytesblockwrite
# -----------------------------------------------------------------------------
  Definition Flag_visible, "align8," # ( -- )
align8komma: # Macht den Dictionarypointer auf 8 gerade
# -----------------------------------------------------------------------------
  push x1

  call align4komma

  call here
  andi x8, x8, 4
  beq x8, zero, 1f

    li x8, writtenword
    call komma
    j 2f

1:drop
2:pop x1
  ret
  .endif

  .ifdef compressed_isa

# -----------------------------------------------------------------------------
  Definition Flag_visible, "align" # ( -- )
align4komma: # Macht den Dictionarypointer auf 4 gerade
# -----------------------------------------------------------------------------
  push x1

  call here

  # Alignment for - non-existent - c, which may happen when user allots non-aligned amounts of memory
  andi x15, x8, 1
  add x8, x8, x15
  laf x14, Dictionarypointer
  sw x8, 0(x14)

  # Alignment for h,
  andi x8, x8, 2
  beq x8, zero, 1f

    li x8, 0x0001 # Compressed NOP opcode
    call hkomma
    j 2f

1:drop
2:pop x1
  ret

# -----------------------------------------------------------------------------
kommairgendwo: # ( x addr -- ) For backpatching of jump opcodes.
# -----------------------------------------------------------------------------
  push x1
  ddup

  call hkommairgendwo

  swap
  srli x8, x8, 16
  swap
  addi x8, x8, 2
  pop x1
hkommairgendwo: # ( x addr -- ) For backpatching of jump opcodes.
  push x1
  dup
  j hkomma_intern

# -----------------------------------------------------------------------------
  Definition Flag_visible, "h," # ( -- )
hkomma: # Fügt 16 Bits an das Dictionary an
# -----------------------------------------------------------------------------
  push x1

  call here
  dup

  pushdaconst 2
  call allot

hkomma_intern:
  call addrinflash
  popda x15
  beq x15, zero, hkomma_ram

hkomma_flash:
  call hflashstore
  j 1f

hkomma_ram:
  # Simply write directly if compiling for RAM.
  popda x15
  sh x8, 0(x15)
  drop

1:pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "," # ( x -- )
komma: # Fügt 32 Bits an das Dictionary an  Write 32 bits in Dictionary
# -----------------------------------------------------------------------------
  push x1
  dup
  call hkomma
  srli x8, x8, 16
  pop x1
  j hkomma

  .else # compressed_isa

# -----------------------------------------------------------------------------
  Definition Flag_visible, "align" # ( -- )
align4komma: # Macht den Dictionarypointer auf 4 gerade
# -----------------------------------------------------------------------------
  push x1  # Eigentlich nichts zu tun, vom Kern aus immer auf 4 gerade.

  call here
  call aligned
  laf x14, Dictionarypointer
  sw x8, 0(x14)
  drop

  pop x1
  ret

# -----------------------------------------------------------------------------
kommairgendwo: # ( x addr -- ) For backpatching of jump opcodes.
# -----------------------------------------------------------------------------
  push x1
  dup
  j komma_intern

# -----------------------------------------------------------------------------
  Definition Flag_visible, "," # ( x -- )
komma: # Fügt 32 Bits an das Dictionary an  Write 32 bits in Dictionary
# -----------------------------------------------------------------------------
  push x1

#  write "Komma: "
#  call here
#  call hexdot
#  dup
#  call hexdot
#  writeln ""

  call here
  dup
  call four_allot

komma_intern:
  call addrinflash
  popda x15
  beq x15, zero, komma_ram

komma_flash:
  call flashstore
  j 1f

komma_ram:
  # Simply write directly if compiling for RAM.
  popda x15
  sw x8, 0(x15)
  drop

1:pop x1
  ret

  .endif

#------------------------------------------------------------------------------
  Definition Flag_visible, "allot" # Erhöht den Dictionaryzeiger, schafft Platz !  Advance Dictionarypointer and check if there is enough space left for the requested amount.
allot:  # Überprüft auch gleich, ob ich mich noch im Ram befinde.
        # Ansonsten verweigtert Allot seinen Dienst.
#------------------------------------------------------------------------------

#   # Simple variant without any checks.
#   li x14, Dictionarypointer
#   lw x15, 0(x14)
#   add x15, x15, x8
#   sw x15, 0(x14)
#   drop
#   ret

  push_x1_x10

  popda x10 # Requested length

  call compiletoramq
  popda x15
  bne x15, zero, allot_ram

allot_flash:
  laf x14, Dictionarypointer
  lw x15, 0(x14)
  add x15, x15, x10

  laf x10, FlashDictionaryEnde

  bltu x15, x10, 2f
    writeln "Flash full"
    j quit

allot_ram:
  call flashvarhere         # Am Ende des RAMs liegen die Variablen. Diese sind die Ram-Voll-Grenze...
                            # There are variables defined in Flash at the end of RAM. Don't overwrite them !
  laf x14, Dictionarypointer
  lw x15, 0(x14)
  add x15, x15, x10

  bltu x15, x8, 1f
    writeln "Ram full"
    j quit

1:drop

2:sw x15, 0(x14)
  pop_x1_x10
  ret

four_allot:
  pushdaconst 4
  j allot

# There are two sets of Pointers: One set for RAM, one set for Flash Dictionary.
# They are exchanged if you want to write to the "other" memory type.
# A small check takes care of the case if you are already in the memory you request.

# -----------------------------------------------------------------------------
  Definition Flag_visible, "forgetram"
# -----------------------------------------------------------------------------
  push x1
  call compiletoram

  # Dictionarypointer ins RAM setzen
  # Set dictionary pointer into RAM first
  laf x14, Dictionarypointer
  laf x15, RamDictionaryAnfang
  sw x15, 0(x14)

  # Fadenende fürs RAM vorbereiten
  # Set latest for RAM
  laf x14, Fadenende
  la x15, CoreDictionaryAnfang
  sw x15, 0(x14)

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "compiletoram?"
compiletoramq:
# -----------------------------------------------------------------------------
  push x1
  call here
  call addrinflash
  inv x8
  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "compiletoram"
compiletoram:
# -----------------------------------------------------------------------------
  push x1
  call compiletoramq

  popda x15
  bne x15, zero, 2f

  # Befinde mich im Flash. Prüfe auf Kollisionen der Variablen mit dem RAM-Dictionary und schalte um !
  laf x14, Dictionarypointer
  lw x15,  4(x14) # ZweitDictionaryPointer
  lw x14, 14(x14) # VariablenPointer

  bltu x15, x14, Zweitpointertausch
   writeln " Variables collide with dictionary"
Zweitpointertausch:

  pushdatos

    laf x8, Dictionarypointer

    lw x14,  0(x8) # Dictionarypointer
    lw x15,  4(x8) # ZweitDictionaryPointer
    sw x14,  4(x8)
    sw x15,  0(x8)

    lw x14,  8(x8) # Fadenende
    lw x15, 12(x8) # ZweitFadenende
    sw x14, 12(x8)
    sw x15,  8(x8)

  li x8, 0 # Trick: Allot will check for collisions, too, and reports RAM full then.
  pop x1
  j allot

# -----------------------------------------------------------------------------
  Definition Flag_visible, "compiletoflash"
compiletoflash:
# -----------------------------------------------------------------------------
  push x1
  call compiletoramq

  popda x15
  bne x15, zero, Zweitpointertausch # Befinde mich im Ram. Schalte um !

2:pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible|Flag_foldable_0, "(latest)"
# -----------------------------------------------------------------------------
  pushdatos
  laf x8, Fadenende
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible|Flag_foldable_0, "(dp)"
# -----------------------------------------------------------------------------
  pushdatos
  laf x8, Dictionarypointer
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "(create)"
create: # Nimmt das nächste Token aus dem Puffer,
        # erstellt einen neuen Kopf im Dictionary und verlinkt ihn.
        # Fetch new token from buffer, create a new dictionary header and take care of links.
        # Links are very different for RAM and Flash !
        # As we can write Flash only once, freshly created definitions have no code at all.
# -----------------------------------------------------------------------------
  push x1
  call token # Hole den Namen der neuen Definition.  Fetch name for new definition.
  # ( Tokenadresse Länge )
  bne x8, zero, 1f

    # Check if token is empty. That happens if input buffer is empty after create.
    # Token ist leer. Brauche Stacks nicht zu putzen.
    writeln " Create needs name !"
    j quit

1:# Tokenname ist okay.               Name is ok.
  # Prüfe, ob er schon existiert.     Check if it already exists.
  ddup
  # ( Tokenadresse Länge Tokenadresse Länge )
  call find
  # ( Tokenadresse Länge Einsprungadresse Flags )
  drop # Benötige die Flags hier nicht. Möchte doch nur schauen, ob es das Wort schon gibt.  No need for the Flags...
  # ( Tokenadresse Länge Einsprungadresse )

  # Prüfe, ob die Suche erfolgreich gewesen ist.  Do we have a search result ?
  popda x15
  beq x15, zero, 2f
  # ( Tokenadresse Länge )
    ddup
    write "Redefine "
    call type # Den neuen Tokennamen nochmal ausgeben
    write ". "
2:

  .ifdef compressed_isa
    call align4komma
  .endif

  # ( Tokenadresse Länge )

  call compiletoramq
  popda x15
  bne x15, zero, create_ram

  # -----------------------------------------------------------------------------
  # Create for Flash

  laf x14, FlashFlags
  li x15, Flag_visible
  sw x15, 0(x14) # Flags vorbereiten  Prepare Flags for collecting

  .ifdef flash8bytesblockwrite
    call align8komma  # Vorrücken auf die nächste passende Schreibstelle
                      # Es muss ein kompletter 8-Byte-Block für das Linkfeld reserviert werden
    call four_allot   # damit dies später noch nachträglich eingefügt werden kann.
  .endif

  call here
  # ( Tokenadresse Länge Neue-Linkadresse )

  pushdaconst 8 # Lücke für die Flags und Link lassen  Leave space for Flags and Link - they are not known yet at this time.
  call allot

  call minusrot
  call stringkomma # Den Namen einfügen  Insert Name
  # ( Neue-Linkadresse )

  # Jetzt den aktuellen Link an die passende Stelle im letzten Wort einfügen,
  # falls dort FFFF FFFF steht:
  # Insert Link to fresh definition into old latest if there is still -1 in its Link field:

  laf x10, Fadenende # Hole das aktuelle Fadenende  Fetch old latest
  lw x11, 0(x10)

  lw x12, 0(x11) # Inhalt des Link-Feldes holen  Check if Link is set

  li x13, erasedword
  bne x12, x13, 1f # Ist der Link ungesetzt ?      Isn't it ?

    dup
    pushda x11
    call flashstore

1:# Backlink fertig gesetzt.  Finished Backlinking.
  # Fadenende aktualisieren:  Set fresh latest.
  sw x8, 0(x10) # Neues-Fadenende in die Fadenende-Variable legen
  drop

  j create_ende

  # -----------------------------------------------------------------------------
  # Create for RAM
create_ram:
  # ( Tokenadresse Länge )

  call here

    # Link setzen  Write Link
    pushdaaddrf Fadenende
    lw x8, 0(x8)
    call komma # Das alte Fadenende hinein   Old latest

  laf x14, Fadenende # Das Fadenende aktualisieren  Set new latest
  sw x8, 0(x14)
  drop

  # Flags setzen  Set initial Flags to Invisible.
  pushdaconst Flag_invisible
  call komma

  # Den Namen schreiben  Write Name
  call stringkomma

create_ende: # Save code entry point of current definition for recurse and dodoes

  call here
  laf x14, Einsprungpunkt
  sw x8, 0(x14)
  drop

  pop x1
  ret


# -----------------------------------------------------------------------------
  Definition Flag_visible, "variable" # ( n -- )
# -----------------------------------------------------------------------------
  pushdaconst 1
  j nvariable

# -----------------------------------------------------------------------------
  Definition Flag_visible, "2variable" # ( d -- )
# -----------------------------------------------------------------------------
  pushdaconst 2
  j nvariable

#------------------------------------------------------------------------------
  Definition Flag_visible, "nvariable" # ( Init-Values Length -- )
nvariable: # Creates an initialised variable of given length.
#------------------------------------------------------------------------------
  push_x1_x10_x11
  call create
  call compiletoramq
  popda x15
  bne x15, zero, variable_ram

  # -----------------------------------------------------------------------------
  # Variable Flash

  andi x8, x8, 0x0F    # Maximum length for flash variables ! Limit is important to not break Flags for catchflashpointers.
  push x8              # Save the amount of cells for generating flags for catchflashpointers later
  slli x8, x8, 2       # Multiply number of elements with 4 to get byte count

  call variable_buffer_flash_prepare
  call retkomma

    popda x10          # Fetch amount of bytes
    beq x10, zero, 2f  # If nvariable is called with length zero... Maybe this could be useful sometimes.

1:  sw x8, (x11)       # Initialize RAM location
    addi x11, x11, 4   # Advance address
    call komma         # Put initialisation value for catchflashpointers in place.
    addi x10, x10, -4
    bne x10, zero, 1b
2:  # Finished.

  r_from                                    # Finally (!) set Flags for RAM usage.
  ori x8, x8, Flag_ramallot & ~Flag_visible # Or together with desired amount of cells.
  j variable_buffer_flash_finalise

#------------------------------------------------------------------------------
  Definition Flag_visible, "buffer:" # ( Length -- )
  # Creates an uninitialised buffer of given bytes length.
#------------------------------------------------------------------------------
  push_x1_x10_x11

  call aligned # Round requested buffer length to next 4-Byte boundary to ensure alignment

  call create
  call compiletoramq
  popda x15
  bne x15, zero, buffer_ram

  # -----------------------------------------------------------------------------
  # Buffer Flash

  call variable_buffer_flash_prepare
  call retkomma

  # Write desired size of buffer at the end of the definition
  call komma

  pushdaconst Flag_buffer_foldable  # Finally (!) set Flags for buffer usage.

variable_buffer_flash_finalise:
  call setflags
  j pop_x1_x10_x11_smudge

  # -----------------------------------------------------------------------------
variable_buffer_flash_prepare:
    # Variablenpointer erniedrigen und zurückschreiben   Decrement variable pointer

  laf x10, VariablenPointer
  lw x11, 0(x10)
  sub x11, x11, x8  # Ram voll ?  Maybe insert a check for enough RAM left ?
    laf x14, RamDictionaryAnfang
    bge x11, x14, 1f
      writeln "Not enough RAM"
      j quit
1:sw x11, 0(x10)

  # Code schreiben:  Write code
  pushda x11
  j literalkomma

  # -----------------------------------------------------------------------------
  # Variable and Buffer: for RAM

variable_ram:
  call variable_buffer_ram_prepare

  popda x10 # Amount of cells to write is in TOS.
  beq x10, zero, variable_buffer_ram_finalise # If nvariable is called with length zero... Maybe this could be useful sometimes.

1:call komma
  addi x10, x10, -1
  bne x10, zero, 1b

  j variable_buffer_ram_finalise

# -----------------------------------------------------------------------------

buffer_ram:
  call variable_buffer_ram_prepare
  call allot
variable_buffer_ram_finalise:
  # call setze_faltbarflag # Variables always are 0-foldable as their address never changes.
  pushdaconst Flag_ramallot & ~Flag_visible # For better detection of variables and buffers in dictionary
  call setflags
pop_x1_x10_x11_smudge:
  pop_x1_x10_x11
  j smudge

# -----------------------------------------------------------------------------

variable_buffer_ram_prepare:
  push x1

  # This is simple: Write code, write value, a classic Forth variable.

  .ifdef compressed_isa
    # This is to align dictionary pointer to have variable locations that are always 4-even
    call align4komma
  .endif

  call dup_komma

  .ifdef mipscore

  pushdaconst 0x03E00009 | reg_tos << 11 # jalr x8, x1
  call komma
  pushdaconst 0x00000000 # nop
  pop x1
  j komma

  .else

  pushdaconst 0x00008067 | reg_tos << 7 # Opcode for jalr x8, x1, 0
  pop x1
  j komma

  .endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "dictionarystart"
dictionarystart: # ( -- Startadresse des aktuellen Dictionaryfadens )
                 # Da dies je nach Ram oder Flash unterschiedlich ist...
                 # Einmal so ausgelagert.
                 # Entry point for dictionary searches.
                 # This is different for RAM and for Flash and it changes with new definitions.
# -----------------------------------------------------------------------------


  # Prüfe, ob der Dictionarypointer im Ram oder im Flash ist:  Are we compiling into RAM or into Flash ?
  push x1

  call compiletoramq
  pop x1
  bne x8, zero, 1f

  la x8, CoreDictionaryAnfang # Befinde mich im Flash mit Backlinks. Muss beim CoreDictionary anfangen:        In Flash: Start with core dictionary.
  ret

1:laf x8, Fadenende            # Kann mit dem Fadenende beginnen.                                               In RAM:   Start with latest definition.
  lw x8, 0(x8)
  ret

  # Zwei Möglichkeiten: Vorwärtslink ist $FFFFFFFF --> Ende gefunden
  # Oder Vorwärtslink gesetzt, aber an der Stelle der Namenslänge liegt $FF. Dann ist das Ende auch da.
  # Diese Variante tritt auf, wenn nichts hinzugetan wurde, denn im festen Teil ist der Vorwärtslink
  # immer gesetzt und zeigt auf den Anfang des Schreib/Löschbaren Teils.

  # There are two possibilities to detect end of dictionary:
  # - Link is $FFFFFFFF
  # - Link is set, but points to memory that contains $FF in name length.
  # Last case happens if nothing is compiled yet, as the latest link in core always
  # points to the beginning of user writeable/eraseable part of dictionary space.

  # Dictionary entry structure:
  # 4 Bytes Link ( 4-aligned )
  # 4 Bytes Flags
  # 1 Byte  Name length
  #         Counted Name string and sometimes a padding zero to realign.
  #         Code.

# -----------------------------------------------------------------------------
  Definition Flag_visible, "dictionarynext" # ( address -- address flag )
dictionarynext: # Scans dictionary chain and returns true if end is reached.
# -----------------------------------------------------------------------------
  li x15, erasedword # Check if link field is empty which does not happen with properly smudged flash definitions
  lw x14, 0(x8)
  beq x15, x14, true

    li x15, erasedbyte
    lbu x14, 8(x14) # Skip link and flags of the next definition to fetch its name length byte
    beq x15, x14, true

      lw x8, 0(x8)
        pushdaconst 0
        ret

#------------------------------------------------------------------------------
  Definition Flag_visible|Flag_variable, "hook-find" # ( -- addr )
  CoreVariable hook_find
#------------------------------------------------------------------------------
  pushdaaddrf hook_find
  ret
  .word core_find  # No Pause defined for default

#------------------------------------------------------------------------------
  Definition Flag_visible, "find" # ( -- ? )
find:
#------------------------------------------------------------------------------
  laf x15, hook_find
  lw x15, 0(x15)
  .ifdef mipscore
  jr x15
  .else
  jalr zero, x15, 0
  .endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "(find)"
core_find: # ( address length -- Code-Adresse Flags )
# -----------------------------------------------------------------------------
  push_x1_x10_x12

  # x15  Helferlein      Scratch
  # x10  Flags           Flags

  # x11  Zieladresse     Destination Address
  # x12  Zielflags       Destination Flags

  # x8   Hangelpointer   Pointer for crawl the dictionary

  li x11, 0  # Noch keinen Treffer          No hits yet
  li x12, 0  # Und noch keine Trefferflags  No hits have no Flags

  to_r_2 # String length and address

  call dictionarystart

1:# Loop through the dictionary

  li x15, Flag_invisible
  lw x10, 4(x8) # Fetch Flags to see if this definition is visible.
  beq x15, x10, 2f # Skip this definition if invisible

  # Definition is visible. Compare the name !
  dup
  addi x8, x8, 8 # Skip Link and Flags
  call count     # Prepare an address-length string

  r_fetch_2
  call compare
  popda x15
  beq x15, zero, 2f

    # Gefunden ! Found !
    # String überlesen und Pointer gerade machen   Skip name string
    dup
    addi x8, x8, 8 # Skip Link and Flags
    call skipstring
    popda x11      # Codestartadresse  Note Code start address
    mv x12, x10    # Flags             Note Flags

    # j 3f # RAM only, finished on first hit.

    # Prüfe, ob ich mich im Flash oder im Ram befinde.  Check if in RAM or in Flash.
    # Im Ram beim ersten Treffer ausspringen. Search is over in RAM with first hit.
    # Im Flash wird weitergesucht, ob es noch eine neuere Definition mit dem Namen gibt.
    # When in Flash, whole dictionary has to be searched because of backwards link dictionary structure.
    pushda x11
    call addrinflash
    popda x15
    beq x15, zero, 3f

2:# Weiterhangeln  Continue crawl.
  call dictionarynext
  popda x15
  beq x15, zero, 1b


3:# Durchgehangelt. Habe ich etwas gefunden ?  Finished. Found something ?
  # Zieladresse gesetzt, also nicht Null bedeutet: Etwas gefunden !    Destination address <> 0 means successfully found.
  mv x8, x11    # Zieladresse    oder 0, falls nichts gefunden            Address = 0 means: Not found. Check for that !
  pushda x12    # Zielflags      oder 0  --> # ( 0 0 - Nicht gefunden )   Push Flags on Stack. ( Destination-Code Flags ) or ( 0 0 ).

  r_drop_2
  pop_x1_x10_x12
  ret
