#Licensed under the 3-Clause BSD License
#Copyright 2021, Martin Wendt
#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
#3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
#TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
#CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#======================================================

# -----------------------------------------------------------------------------
#  Concatenate and decompress LZ4 memory image
# -----------------------------------------------------------------------------

.option norelax
.option rvc

.equ cat_and_unpack,     0x00000000
.equ unpack_destination, 0x00010000

.text

boot:

  auipc x11, 0 # Get the address we are currently executing from.

  csrrci zero, mstatus, 8 # Clear Machine Interrupt Enable Bit

  # Clear "flash" memory area
  li x8, -1
  li x9, 128*1024
1:addi x9, x9, -4
  sw x8, 0(x9)
  bne x9, zero, 1b

  # Copy 10 kb of data from the boot area to the start of the RAM.
                        # Start of the boot area, loaded with auipc opcode
  li x9, cat_and_unpack # Destination in RAM to concatenate two memory areas
  li x12, 10*1024       # 10 kb

  c.jal copy_data

  # Copy 1.5 kb of data from the byte-addressable-only text buffer

  li x11, 0x10000000 # Start of text buffer
                     # Continue where we left
  li x12, 1536       # 1.5 kb

  c.jal copy_data

  # Long jump into the concatenated memory area

  lui x15, %hi(depack)
  jalr zero, x15, %lo(depack)

depack:

  la x8, binarydata         # Compressed data, concatenated from two initialised blocks
  li x9, unpack_destination # Destination address

# srcptr x8
# dstptr x9
#
# srcend x10
# cpysrc x11
# cpylen x12
# c_tmp  x13
# token  x14
# alt_ra x15

   lhu x10, 0(x8)              #read size from header
   addi x8, x8, 2
   add x10, x10, x8            #current pos+size=end
fetch_x14:
   lbu x14, 0(x8)
   addi x8, x8, 1
   srli x12, x14, 4            #x12 = literal length
   beqz x12, fetch_offset
   jal fetch_length

   mv x11, x8
   jal copy_data               #literal copy x11 to x9
   mv x8, x11
   bge x8, x10, finished       #reached end of data? lz4 always ends with a literal

fetch_offset:
   lbu x13, 0(x8)              #offset is halfword but at byte alignment
   sub x11, x9, x13
   lbu x13, 1(x8)
   addi x8, x8, 2              #placed here for pipeline
   slli x13, x13, 8
   sub x11, x11, x13
   andi x12, x14, 0x0f         #get offset
   jal fetch_length
   addi x12, x12, 4            #match length is >4 bytes
   jal copy_data
   j fetch_x14
finished:

  # Enter into the freshly decompressed code
  lui x8, %hi(unpack_destination)
  jalr zero, x8, %lo(unpack_destination)

fetch_length:
   xori x13, x12, 0xf
   bnez x13, _done             #0x0f indicates further bytes

_loop:
   lbu x13, 0(x8)
   addi x8, x8, 1
   add x12, x12, x13
   xori x13, x13, 0xff         #0xff indicates further bytes
   beqz x13, _loop
_done:
   ret

copy_data: # ( x11 x9 x12 )
   lbu x13, 0(x11)
   addi x11, x11, 1            #placed here for pipeline
   sb x13, 0(x9)
   addi x9, x9, 1
   addi x12, x12, -1
   bnez x12, copy_data
   ret

binarydata:
  .incbin "mecrisp-quintus-mch2022.lz4.raw"

.org 0x2E00, 0x00 # 11.5 kb in total
