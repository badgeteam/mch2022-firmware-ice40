
# -----------------------------------------------------------------------------
#   A small example for using interrupts on RISC-V
# -----------------------------------------------------------------------------

.option rvc # Enable compressed opcode support

# -----------------------------------------------------------------------------
#   How interrupts work on RISC-V
# -----------------------------------------------------------------------------

# Four CSR registers are used for the most basic interrupt:
#
#  MTVEC    Contains the address of the interrupt handler
#  MSTATUS  Enables/disables interrupts
#  MEPC     Holds the return address into the main program (used by mret opcode)
#  MCAUSE   Shows the source of the interrupt or zero when executing main program
#
# When an interrupts occours, the processor
#  * puts the address of the next opcode in the main program into MEPC
#  * puts the source of the interrupt into MCAUSE which also locks further interrupts
#      (the playground only uses source ID 1 for the timer, no need to switch on that)
#  * puts the address of the interrupt handler from MTVEC into PC.
#
# Note that the interrupt entry involves no stack movements at all.
# We have to save the x1-x31 registers ourselves shall we use these in handler.
#
# To return from an interrupt handler, use mret opcode which
#  * puts the address to continue from MEPC into PC
#  * clears MCAUSE.

# -----------------------------------------------------------------------------
#   Notes on registers in RISC-V
# -----------------------------------------------------------------------------

# Only the zero register x0 is hardwired in the processor logic,
# you can use any of x1 to x31 for whatever you wish.
#
# But for efficiently using the compressed opcodes (which are half the size)
# there are a few conventions to follow:
#
#  x0:  Hardwired to zero
#  x1:  Link register for jal/jalr calls and returns
#  x2:  Stack pointer
#
#  x8-x15: Use these as much as possible, as most of compressed opcodes
#          support these eight registers only.

# -----------------------------------------------------------------------------
#   Push and pop macros, just for convenience
# -----------------------------------------------------------------------------

# Note: One would usually combine multiple pushes and pops
#       to adjust stack pointer only once

.macro push register
  addi x2, x2, -4
  sw \register, 0(x2)
.endm

.macro pop register
  lw \register, 0(x2)
  addi x2, x2, 4
.endm

# -----------------------------------------------------------------------------
#   Register constants for a few hardware ports
# -----------------------------------------------------------------------------

.equ leds,          0x40000100

.equ uart_data,     0x40010000
.equ uart_flags,    0x40020000

.equ timer_ticks,   0x40040000
.equ timer_reload,  0x40080000

.equ CYCLES_US,    12
.equ CYCLES_MS, 12000

# -----------------------------------------------------------------------------
#   Execution starts here
# -----------------------------------------------------------------------------

Reset:

  li x2, 0x00020000  # Set stack pointer to end of RAM

  la x10, interrupt
  csrrw zero, mtvec, x10  # MTVEC: Store address of exception handler

  li x31, 0               # Use one arbitrary selected register as a "global" counter variable...

  # The simple timer in the playground counts up every clock cycle,
  # and triggers interrupt on 32 bit overflow, starting again with the reload value.

  li x10, -5000*CYCLES_MS # Set the timer to overflow for the first time in 5 s
  li x11, timer_ticks     # Remember: The value is negative as the timer counts upwards.
  sw x10, 0(x11)

  li x10, -345*CYCLES_MS  # And set the reload value to trigger again every 345 ms.
  li x11, timer_reload    # Same note applies here
  sw x10, 0(x11)

  csrrsi zero, mstatus, 8 # Set   "Machine Interrupt Enable" bit to enable  interrupts
# csrrci zero, mstatus, 8 # Clear "Machine Interrupt Enable" bit to disable interrupts

insight:

  li x8, 10               # Line feed
  call serial_emit

  li x8, 1000*CYCLES_MS   # Once in a second,
  call delay_cycles

  mv x8, x31              # show the counter variable on the serial terminal.
  call hexprint

  j insight

# -----------------------------------------------------------------------------
#   Interrupt handler
# -----------------------------------------------------------------------------

interrupt:
            # All registers in use within the handler need to be saved.
   push x1  # Link address: Not used in this example, but necessary if you want to call something
   push x10
   push x11

   addi x31, x31, 1    # Advance global counter, this register is reserved for the handler
                       # and therefore not saved on the stack.

   srli x10, x31, 1    # Gray code blinky
   xor  x10, x10, x31

   li x11, leds        # Output on the LEDs
   sw x10, 0(x11)

   pop x11
   pop x10
   pop x1
   mret     # Special return opcode uses address in MEPC CSR instead of link register


# This is all you need to understand using interrupts.
# A few simple tools follow...

# -----------------------------------------------------------------------------
hexprint: # Hexadecimal output -- prints value in x8.
# -----------------------------------------------------------------------------

  push x1
  push x10
  push x11
  push x12

  mv x10, x8
  li x11, 32           # Number of bits left

1:srli x8, x10, 28     # Print upper nibble first
  andi x8, x8, 0xF
  li x12, 10
                       # Number of letter for printing this nibble?
  bltu x8, x12, 2f
    addi x8, x8, 55-48 # Offset from '0' to 'A' in ASCII
2:addi x8, x8, 48      # Character '0' in ASCII
  call serial_emit

  slli x10, x10, 4     # Shift next nibble in position
  addi x11, x11, -4    # 4 bits done
  bne x11, zero, 1b    # Any bits left?

  pop x12
  pop x11
  pop x10
  pop x1
  ret

# -----------------------------------------------------------------------------
serial_emit: # Emit one character from x8.
# -----------------------------------------------------------------------------
  push x10
  push x11

  li x10, uart_flags

1:lw x11, 0(x10)
  andi x11, x11, 0x200 # Check "busy sending" flag
  bne x11, zero, 1b

  li x10, uart_data
  sw x8, 0(x10)

  pop x11
  pop x10
  ret

# -----------------------------------------------------------------------------
serial_key: # Receive one character into x8.
# -----------------------------------------------------------------------------
  push x10
  push x11

  li x10, uart_flags

1:lw x11, 0(x10)
  andi x11, x11, 0x100 # Check "valid data" flag
  beq x11, zero, 1b

  li x10, uart_data
  lbu x8, 0(x10)

  pop x11
  pop x10
  ret

# -----------------------------------------------------------------------------
delay_cycles: # Delay cycles given in r8.
# -----------------------------------------------------------------------------
  push x10
  push x11

  rdcycle x11       # Start

1:rdcycle x10       # Current
  sub x10, x10, x11 # Elapsed = Current - Start
  bltu x10, x8, 1b  # Loop if elapsed < cycles

  pop x11
  pop x10
  ret
