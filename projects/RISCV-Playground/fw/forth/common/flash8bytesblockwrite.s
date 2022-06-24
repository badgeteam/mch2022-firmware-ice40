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

# Emulation for flash! to circumvent problems with 8-Byte-ECC Flash
# 32-Bit Flash writes are collected here to be written later as 8 Byte blocks

# Einfügen im Hauptteil:
# .equ Sammelstellen, 32 # 32 * (8 + 4) = 384 Bytes
# ramallot Sammeltabelle, Sammelstellen * 12 # Buffer 32 blocks of 8 bytes each for ECC constrained Flash write

# -----------------------------------------------------------------------------
  Definition Flag_visible, "initflash" # Zu Beginn und in Quit !
initflash: # ( -- ) Löscht alle Einträge in der Sammeldatei
                     # Clear the table at the beginning and in quit
# -----------------------------------------------------------------------------
  push x10

  laf x15, Sammeltabelle
  li  x14, 3 * Sammelstellen
  li x10, -1

1:sw x10, 0(x15)
  addi x15, x15, 4
  addi x14, x14, -1
  bne x14, zero, 1b

  pop x10
  ret

    .ifdef debug
# -----------------------------------------------------------------------------
  Definition Flag_visible, "stmalen" # Nur zur Fehlersuche
sammeltabellemalen: # ( -- ) Malt den Inhalt der Sammeltabelle
                    # Write contents of collection table, for experiments only.
# -----------------------------------------------------------------------------
  push_x1_x10_x11

  laf x10, Sammeltabelle
  li  x11, Sammelstellen

1:pushdatos
  lw x8, 0(x10)
  andi x8, x8, ~3
  write "Adresse: "
  call hexdot

  write "Inhalt: "
  pushdatos
  lw x8, 4(x10)
  call hexdot

  pushdatos
  lw x8, 8(x10)
  call hexdot

  writeln " >"

  addi x10, x10, 12
  addi x11, x11, -1
  bne x11, zero, 1b

  pop_x1_x10_x11
  ret
  .endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flash!" # Übernimmt die Rolle des großen flash! :-)
flashstore: # ( x addr -- ) Fügt einen Eintrag in die Tabelle ein und brennt Päärchen.
            # Emulates flash! - collects values in table and writes completed pairs.
# -----------------------------------------------------------------------------
  # Idee: Prüfe, ob der 8-Byte-Block gerade in der Tabelle ist.
  # Wenn ja: Einfügen, und falls es der 2. Schreibzugriff ist, weiterleiten.
  # Wenn nein: Neuen 8-Byte-Block eröffnen und mit dem Wert für leeren Speicher füllen - Achtung, Tabellenüberlauf !

  # Tabellenaufbau:
  # Adresse, auf 8 gerade, mit der Zahl der bereits geschriebenen Stellen in den Low-Bits.
  # 8 Bytes $FF bzw. die geschriebenen Stellen.

  push_x1_x10_x13

  # write "flash! "
  # call dots

  # x10:    # Tabelleneintragsstartadresse
  # x11:    # Manchmal Zähler fürs Durchgucken der Tabelle
  popda x12 # Adresse
  # TOS:    # Inhalt

  # Prüfe, ob die Adresse gerade ist
  andi x15, x12, 3
  beq x15, zero, 1f
    writeln "flash! needs 4-even addresses."
    j quit
1:

  # Suche nach einem Eintrag, der die Adresse ohne $7 trägt !
  # Search if the 8-Byte truncated address is already buffered in the table !

  srli x13, x12, 3 # Prepare address for crawling by removing low bits

  laf x10, Sammeltabelle
  li  x11, Sammelstellen

2:lw x15, 0(x10)
  srli x15, x15, 3 # Prepare address by removing low bits
  beq x13, x15, flashstoreemulation_gefunden # Ist das passende Päärchen gefunden ? Found the pair ?

  # Ansonsten weitersuchen:
  # Continue searching the table
  addi x10, x10, 12
  addi x11, x11, -1
  bne x11, zero, 2b

  # Nicht gefunden: Suche eine leere Stelle in der Tabelle !
  # Not found. Search for an empty place in table to fill this request in

  laf x10, Sammeltabelle
  li  x11, Sammelstellen

3:lw x15, 0(x10)
  addi x15, x15, 1
  beq x15, zero, flashstoreemulation_leerestelle # Ist eine leere Stelle aufgetaucht ? Is this table place empty ?

  # Ansonsten weitersuchen:
  # Continue searching the table
  addi x10, x10, 12
  addi x11, x11, -1
  bne x11, zero, 3b

    writeln "Too many scattered Flash writes."
    j quit

flashstoreemulation_leerestelle:
  # writeln "Leerstelle präparieren"
  # x10 zeigt gerade auf die Stelle, wo ich meinen Wunsch einfügen kann:
  # x10 is pointer into an empty table place to fill in now:

  # Set table entry properly
  slli x13, x13, 3 # Address has just been shifted right before
  sw x13, 0(x10)   # Address of new block

  li x11, erasedword
  sw x11, 4(x10)
  sw x11, 8(x10)

flashstoreemulation_gefunden: # Found !
  # writeln "Einfügen"
  # x10 zeigt auf den passenden Tabelleneintrag.
  # Zieladresse in x12, Inhalt in TOS.
  # x11 wird nicht mehr benötigt.

  # Insert the new entry into the table

  andi x11, x12, 7    # Prepare low bits of address as offset into table:
  add  x11, x11, x10  # Add table entry address
  sw x8, 4(x11)       # Store desired value into table, skip table entry header
  drop

  # Increment number of stores to this table
  lw x11, 0(x10)   # Fetch old count
  addi x11, x11, 1 # Increment count of writes
  sw x11, 0(x10)   # Store new count

  # Enough writes to fill a 8 byte block ?
  andi x11, x11, 7
  addi x11, x11, -2
  bne x11, zero, flashstoreemulation_fertig

    # A 8 Byte block is finished ! Let's write !
    call flushblock

flashstoreemulation_fertig:
  pop_x1_x10_x13
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flushflash" # Flushes all remaining table entries
flushflash:
# -----------------------------------------------------------------------------
  push_x1_x10_x11

  laf x10, Sammeltabelle
  li  x11, Sammelstellen

2:lw x15, 0(x10)     # Load the address of the table entry
  addi x15, x15, 1
  beq x15, zero, 3f  # Does this table entry contain something ?

    call flushblock

3:addi x10, x10, 12
  addi x11, x11, -1
  bne x11, zero, 2b

  pop_x1_x10_x11
  ret

# -----------------------------------------------------------------------------
flushblock: # Put a table entry which address is in x10 on data stack for 8flash!
# -----------------------------------------------------------------------------
  pushdatos
  lw x8, 0(x10)
  andi x8, x8, ~7   # Cut off the lowest three bits that contain the write count
  li x15, -1
  sw x15, 0(x10)   # Clear table entry

  addi x9, x9, -8   # Place data content on stack
  lw x15, 4(x10)
  sw x15, 4(x9)
  lw x15, 8(x10)
  sw x15, 0(x9)
  j eightflashstore
