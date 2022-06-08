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
# Swiches for capabilities of this chip
# -----------------------------------------------------------------------------

.option norelax
.option rvc
.equ compressed_isa, 1

# -----------------------------------------------------------------------------
# Speicherkarte für Flash und RAM
# Memory map for Flash and RAM
# -----------------------------------------------------------------------------

# Konstanten für die Größe des Ram-Speichers

.equ RamAnfang, 0x00000000 # Start of RAM          Porting: Change this !
.equ RamEnde,   0x00010000 # End   of RAM.  64 kb. Porting: Change this !

# Konstanten für die Größe und Aufteilung des Flash-Speichers

.equ FlashAnfang, 0x00010000 # Start of Flash          Porting: Change this !
.equ FlashEnde,   0x00020000 # End   of Flash.  64 kb. Porting: Change this !

.equ FlashDictionaryAnfang, FlashAnfang + 0x4000 # 16 kb reserved for core.
.equ FlashDictionaryEnde,   FlashEnde            # 48 kb space for "user flash dictionary"

# -----------------------------------------------------------------------------
# Core start
# -----------------------------------------------------------------------------

.text

  j Reset

# -----------------------------------------------------------------------------
# Include the Forth core of Mecrisp-Quintus
# -----------------------------------------------------------------------------

.include "../common/forth-core.s"

# -----------------------------------------------------------------------------
Reset: # Forth begins here
# -----------------------------------------------------------------------------

  .include "../common/catchflashpointers.s"

  la x15, irq_collection
  csrrw zero, mtvec, x15  # MTVEC: Store address of exception handler

  welcome ""

  # Ready to fly !
  .include "../common/boot.s"
