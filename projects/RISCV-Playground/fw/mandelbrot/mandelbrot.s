
# -----------------------------------------------------------------------------
#   A fractal explorer for RISC-V
# -----------------------------------------------------------------------------

.option rvc # Enable compressed opcode support

# -----------------------------------------------------------------------------
#   Register constants for a few hardware ports
# -----------------------------------------------------------------------------

.equ characters,    0x10000000
.equ font,          0x20000000
.equ buttons,       0x40000080

# -----------------------------------------------------------------------------
#   Execution starts here
# -----------------------------------------------------------------------------

.equ mandel_shift, 12  # Use 12 fractional digits. Hardwired, do not change.

  # x4:  Center X coordinate
  # x5:  Center Y coordinate
  # x6:  Step size

  # x8:  Scratch
  # x9:  Mandelbrot/Tricorn switch
  # x10: Zr for iteration loop
  # x11: Zi for iteration loop
  # x12: Iteration count
  # x13: Scratch
  # x14: Loop X coordinate
  # x15: Loop Y coordinate

  # x16: Display X
  # x17: Display Y
  # x18: Character buffer position

Reset:
  li x4, -1 << (mandel_shift-1)        # Center x position
  li x5, 0                             # Center y position
  li x6, (2*2 << mandel_shift) / 30    # Initial step size
  li x9, 1                             # Switch between 1: Mandelbrot or -1: Tricorn

fractal:
  li x18, characters   # Character buffer address at position (0,0)
  li x8, -15           # Calculate y start coordinates
  mul x15,  x6, x8
  add x15, x15, x5
  li x17, 0            # Start at line 0

y_loop:
    li x8, -20         # Calculate x start coordinates
    mul x14,  x6, x8
    add x14, x14, x4
    li x16, 0          # Start at first character

x_loop:
      mv x10, x14      # Zr = Cr  Prepare values for iteration
      mv x11, x15      # Zi = Ci    in this point
      li x12, 64       # Maximum number of iterations

iteration_loop:

        mv x8, x11
        mul  x8,  x8, x11     # (Zi * Zi)
        mul x11, x11, x10     # (Zr * Zi)
        mul x10, x10, x10     # (Zr * Zr)
        sub x10, x10,  x8     # (Zr^2 - Zi^2)

        add x8, x8,  x8       # (Zr^2 - Zi^2 + 2*Zi^2) = (Zr^2 + Zi^2)
        add x8, x8, x10       # Detour saves one register...

        srli x8, x8, 14 + mandel_shift    # Finished if (Zr^2 + Zi^2) gets larger
        bne x8, zero, iteration_finished  # than 4 << mandel_shift

        srai x10, x10, mandel_shift       # (Zr^2 - Zi^2) >>> mandel_shift
        srai x11, x11, mandel_shift-1     # 2 * (Zr * Zi) >>> mandel_shift

        mul x11, x11, x9       # Complex conjugate of Zi to select fractal

        add x10, x10, x14                 # Zr' = Zr^2 - Zi^2 + Cr
        add x11, x11, x15                 # Zi' = 2 * Zr * Zi + Ci

        addi x12, x12, -1      # Next iteration ?
        bne x12, zero, iteration_loop

iteration_finished:

        andi x12, x12, 15     # Map iteration count by masking
        la x8, colormap       # into the ASCII
        add x8, x8, x12       # "colormap" and
        lb x8, 0(x8)          # fetch a character to print.

        andi x13, x9, 0x80    # Select yellow or cyan depending on fractal type
        or x8, x8, x13

        sb x8, 0(x18)         # Display character
        addi x18, x18, 1      # and advance character buffer address

      add  x14, x14, x6       # Next step in x
      addi x16, x16, 1        # Next character on display
      li x13, 40              # 40 characters per line
      bne x16, x13, x_loop

    add  x15, x15, x6          # Next step in y
    addi x17, x17, 1           # Next line on display
    li x13, 30                 # 30 lines for complete frame
    bne x17, x13, y_loop

  # Drawing completed. Now check buttons to change viewport.

  li x8, buttons
  lw x8, 0(x8)

  # Move viewport with joystick

   andi x13, x8, 8
   beq x13, zero, 1f
     add x4, x4, x6
1: andi x13, x8, 4
   beq x13, zero, 1f
     sub x4, x4, x6
1: andi x13, x8, 1
   beq x13, zero, 1f
     add x5, x5, x6
1: andi x13, x8, 2
   beq x13, zero, 1f
     sub x5, x5, x6
1:

  # Zoom with A & B

   andi x13, x8, 512
   beq x13, zero, 1f
     li x13, 1 << 5    # Maximum zoom level
     blt x6, x13, 1f
       srai x13, x6, 4
       sub x6, x6, x13
1:

   andi x13, x8, 1024
   beq x13, zero, 1f
     li x13, 1 << 10   # Minimum zoom level
     bge x6, x13, 1f
       srai x13, x6, 4
       add x6, x6, x13
1:

  # Switch between Mandelbrot and Tricorn fractal

   andi x13, x8, 32
   beq x13, zero, 1f
     li x9, 1
1: andi x13, x8, 64
   beq x13, zero, 1f
     li x9, -1
1:

  # Reset viewport

   andi x13, x8, 128
   bne x13, zero, Reset

  # Draw again!

  j fractal

  # ASCII art
                # Iteration counter runs backwards:
                #  111111
                #  5432109876543210
colormap:  .ascii " +@0O8%mnv*;:,. "
