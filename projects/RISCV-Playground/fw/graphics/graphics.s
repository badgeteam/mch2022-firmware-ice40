
# -----------------------------------------------------------------------------
#   A graphics example for RISC-V Playground
# -----------------------------------------------------------------------------

.option rvc # Enable compressed opcode support

# -----------------------------------------------------------------------------
#   Memory map
# -----------------------------------------------------------------------------

.equ palettedata, 0x00002000 # Palette, 256 * 2 bytes of RGB 5:6:5 colors
.equ pixelbuffer, 0x00002200 # Buffer for 320x240 bytes of pixel data

# -----------------------------------------------------------------------------
#   Register constants for a few hardware ports
# -----------------------------------------------------------------------------

.equ lcd_ctrl,      0x40001000 # LCD control lines
.equ lcd_data,      0x40002000 # LCD data, writeonly. Set 0x100 for commands.

.equ LCD_CS_N,   1
.equ LCD_RST_N,  2
.equ LCD_MODE,   4
.equ LCD_UPDATE, 8
.equ LCD_CMD, 0x100

.equ CYCLES_US,    15
.equ CYCLES_MS, 15000

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
#   Execution starts here
# -----------------------------------------------------------------------------

Reset:

  li x2, 0x00020000            # Set stack pointer to end of RAM
  call lcd_graphics_init       # Initialise LCD for graphics output
  call palette                 # Initialise color palette

# call clrscr                  # Clear pixel buffer
  call showpalette             # Show palette demo while calculating
  call refresh                 # Push data to LCD

  call mandelbrot              # Finely calculating the Mandelbrot fractal takes some time
  call refresh                 # Push data to LCD

1:j 1b                         # Done.

# -----------------------------------------------------------------------------
mandelbrot: # Paint a nice image of the Mandelbrot fractal
# -----------------------------------------------------------------------------

.equ mandel_shift, 12  # Use 12 fractional digits.

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
  # x18: Pixel buffer position

  li x4, -1 << (mandel_shift-1)        # Center x position
  li x5, 0                             # Center y position
  li x6, (2*2 << mandel_shift) / 240   # Initial step size
  li x9, 1                             # Switch between 1: Mandelbrot or -1: Tricorn

fractal:
  li x18, pixelbuffer  # Pixel buffer address at position (0,0)
  li x8, -240/2        # Calculate y start coordinates
  mul x15,  x6, x8
  add x15, x15, x5
  li x17, 0            # Start at line 0

y_loop:
    li x8, -320/2      # Calculate x start coordinates
    mul x14,  x6, x8
    add x14, x14, x4
    li x16, 0          # Start at first pixel

x_loop:
      mv x10, x14      # Zr = Cr  Prepare values for iteration
      mv x11, x15      # Zi = Ci    in this point
      li x12, 256      # Maximum number of iterations

iteration_loop:

        mv x8, x11
        mul  x8,  x8, x11     # (Zi * Zi)
        mul x11, x11, x10     # (Zr * Zi)
        mul x10, x10, x10     # (Zr * Zr)
        sub x10, x10,  x8     # (Zr^2 - Zi^2)

        add x8, x8,  x8       # (Zr^2 - Zi^2 + 2*Zi^2) = (Zr^2 + Zi^2)
        add x8, x8, x10       # Detour saves one register...

        srli x8, x8, 2 + 2*mandel_shift   # Finished if (Zr^2 + Zi^2) gets larger
        bne x8, zero, iteration_finished  # than 4 << mandel_shift

        srai x10, x10, mandel_shift       # (Zr^2 - Zi^2) >>> mandel_shift
        srai x11, x11, mandel_shift-1     # 2 * (Zr * Zi) >>> mandel_shift

        mul x11, x11, x9       # Complex conjugate of Zi to select fractal

        add x10, x10, x14                 # Zr' = Zr^2 - Zi^2 + Cr
        add x11, x11, x15                 # Zi' = 2 * Zr * Zi + Ci

        addi x12, x12, -1      # Next iteration ?
        bne x12, zero, iteration_loop

iteration_finished:

        li x13, 256            # Iteration counter runs backwards
        sub x13, x13, x12      # 256 rolls over to black in color byte

        sb x13, 0(x18)         # Put iteration count into pixel buffer
        addi x18, x18, 1       # and advance character buffer address

      add  x14, x14, x6        # Next step in x
      addi x16, x16, 1         # Next character on display
      li x13, 320              # 320 pixels per line
      bne x16, x13, x_loop

    add  x15, x15, x6          # Next step in y
    addi x17, x17, 1           # Next line on display
    li x13, 240                # 240 lines for complete frame
    bne x17, x13, y_loop

  ret


# -----------------------------------------------------------------------------
palette: # Initialise palette with RGB 5:6:5 values.
         # Blue: 4 LSB of index, Green: Square of Red, Red: 4 MSB of index
         # The idea is from the Symetrie palette by Rrrola
         # See https://abaddon.hu/256b/colors.html
         # 2D-Gradient, 4 bits black>red>yellow | 4 bits black>blue
# -----------------------------------------------------------------------------
  push x1
  push x10
  push x11
  push x12
  push x13

  li x10, 256

1:addi x10, x10, -1

  andi x11, x10, 0x0F  # 4 LSB of index for blue channel, shifted to be 5 bits wide
  slli x11, x11, 1

  andi x12, x10, 0xF0  # 4 MSB of index for red channel, later shifted to be 5 bits wide

  srli x13, x12, 4     # 4 MSB of index as for red channel
  mul  x13, x13, x13   # squared for green channel
  srli x13, x13, 2     # masked and shifted
  slli x13, x13, 5     # to be 6 bits wide
  or   x11, x11, x13

  slli x12, x12, 8     # Shift for red channel
  or   x11, x11, x12

  li x13, palettedata
  slli x12, x10, 1     # Two bytes per palette data entry
  add x12, x12, x13
  sh x11, 0(x12)

  bne x10, zero, 1b

  pop x13
  pop x12
  pop x11
  pop x10
  pop x1
  ret

# -----------------------------------------------------------------------------
showpalette: # How does the palette actually look?
# -----------------------------------------------------------------------------
  push x10
  push x11
  push x12
  push x13
  push x14

  li x14, pixelbuffer          # Pixel buffer address at position (0,0)
  li x13, 0                    # Start at first line

showpalette_y_loop:

    li x12, 0                  # Start at first pixel

showpalette_x_loop:

        srli x10, x12, 3       # 8x8 squares with the colors of the palette
        srli x11, x13, 3

        andi x10, x10, 0x0F    # X coordinate delivers low  4 bits
        andi x11, x11, 0x0F    # Y coordinate delivers high 4 bits
        slli x11, x11, 4       # of the index
        or x10, x10, x11       # into the color palette

        sb x10, 0(x14)         # Put color into pixel buffer
        addi x14, x14, 1       # and advance character buffer address

      addi x12, x12, 1         # Next character on display
      li x10, 320              # 320 pixels per line
      bne x12, x10, showpalette_x_loop

    addi x13, x13, 1           # Next line on display
    li x10, 240                # 240 lines for complete frame
    bne x13, x10, showpalette_y_loop

  pop x10
  pop x11
  pop x12
  pop x13
  pop x14
  ret

# -----------------------------------------------------------------------------
clrscr: # Clear pixel buffer
# -----------------------------------------------------------------------------
  push x10
  push x11

  li x10, pixelbuffer
  li x11, pixelbuffer + 320*240 # The buffer contains one byte per pixel only.

1:addi x11, x11, -4
  sw zero, 0(x11)
  bne x10, x11, 1b

  pop x11
  pop x10
  ret

# -----------------------------------------------------------------------------
refresh: # Push pixel buffer to display
# -----------------------------------------------------------------------------
  push x1
  push x9   # Scratch
  push x10  # Address of lcd_data register
  push x11  # Scratch
  push x12  # Position X
  push x13  # Position Y
  push x14  # Resolution X
  push x15  # Resolution Y
  push x16  # Address of pixel buffer
  push x17  # Address of palette data

  li x16, pixelbuffer
  li x17, palettedata

  li x10, lcd_data
  li x11, 0x2C | 0x100 # RAMWR command, and special bit for setting the line to select between command and data accordingly
  sw x11, 0(x10)

  li x14, 320
  li x15, 240

  li x12, 0
refresh_x_loop:
  li x13, 0
refresh_y_loop:

  mul x11, x13, x14   # y * 320
  add x11, x11, x12   # y * 320 + x
  add x11, x11, x16   # Add start of pixel buffer
  lbu x11, 0(x11)     # Color byte

  slli x11, x11, 1    # Two bytes per palette data entry
  add  x11, x11, x17  # Palette data start address

  lbu x9, 1(x11)
  sw  x9, 0(x10)
  lbu x9, 0(x11)
  sw  x9, 0(x10)

  addi x13, x13, 1
  bne x13, x15, refresh_y_loop

  addi x12, x12, 1
  bne x12, x14, refresh_x_loop

  pop x17
  pop x16
  pop x15
  pop x14
  pop x13
  pop x12
  pop x11
  pop x10
  pop x9
  pop x1
  ret

# -----------------------------------------------------------------------------
lcd_graphics_init: # Initialise the display for graphics mode
# -----------------------------------------------------------------------------

  push x1
  push x10
  push x11
  push x12

  # Wait for LCD_MODE going high

  li x11, lcd_ctrl
1:lw x12, 0(x11)
  andi x12, x12, LCD_MODE
  beq x12, zero, 1b

  # Wiggle the control wires for a clean start

  li x11, lcd_ctrl
  li x12,                              LCD_CS_N
  sw x12, 0(x11)

  li x8, 1*CYCLES_MS
  call delay_cycles

  li x11, lcd_ctrl
  li x12,                              LCD_CS_N | LCD_RST_N
  sw x12, 0(x11)

  li x8, 120*CYCLES_MS
  call delay_cycles

  li x11, lcd_ctrl
  li x12,                              LCD_RST_N
  sw x12, 0(x11)

  # Send initialisation sequence to LCD

  la x10, LCD_init_data
  li x11, lcd_data

2:lh x12, 0(x10)
  blt x12, zero, 3f

  sw x12, 0(x11)
  addi x10, x10, 2
  j 2b

3:pop x12
  pop x11
  pop x10
  pop x1
  ret

# -----------------------------------------------------------------------------
LCD_init_data:
# -----------------------------------------------------------------------------

  .hword LCD_CMD|0xCF, /* ILI9341_POWERB    */   0x00, 0xC1, 0x30
  .hword LCD_CMD|0xED, /* ILI9341_POWER_SEQ */   0x64, 0x03, 0x12, 0x81
  .hword LCD_CMD|0xE8, /* ILI9341_DTCA      */   0x85, 0x00, 0x78
  .hword LCD_CMD|0xCB, /* ILI9341_POWERA    */   0x39, 0x2C, 0x00, 0x34, 0x02
  .hword LCD_CMD|0xF7, /* ILI9341_PRC       */   0x20
  .hword LCD_CMD|0xEA, /* ILI9341_DTCB      */   0x00, 0x00
  .hword LCD_CMD|0xC0, /* ILI9341_LCMCTRL   */   0x23
  .hword LCD_CMD|0xC1, /* ILI9341_POWER2    */   0x10
  .hword LCD_CMD|0xC5, /* ILI9341_VCOM1     */   0x3e, 0x28
  .hword LCD_CMD|0xC7, /* ILI9341_VCOM2     */   0x86
  .hword LCD_CMD|0x36, /* ILI9341_MADCTL    */   0x08
  .hword LCD_CMD|0x3A, /* ILI9341_COLMOD    */   0x55
  .hword LCD_CMD|0xB1, /* ILI9341_FRMCTR1   */   0x00, 0x18
  .hword LCD_CMD|0xB6, /* ILI9341_DFC       */   0x08, 0x82, 0x27
  .hword LCD_CMD|0xF2, /* ILI9341_3GAMMA_EN */   0x00
  .hword LCD_CMD|0x26, /* ILI9341_GAMSET    */   0x01
  .hword LCD_CMD|0xE0, /* ILI9341_PVGAMCTRL */   0x0F, 0x31, 0x2B, 0x0C, 0x0E
  .hword                                         0x08, 0x4E, 0xF1, 0x37, 0x07
  .hword                                         0x10, 0x03, 0x0E, 0x09, 0x00
  .hword LCD_CMD|0xE1, /* ILI9341_NVGAMCTRL */   0x00, 0x0E, 0x14, 0x03, 0x11
  .hword                                         0x07, 0x31, 0xC1, 0x48, 0x08
  .hword                                         0x0F, 0x0C, 0x31, 0x36, 0x0F
  .hword LCD_CMD|0xF6, /* ILI9341_INTERFACE */   0x00, 0x40, 0x00
  .hword LCD_CMD|0x11  /* ILI9341_SLPOUT    */
  .hword LCD_CMD|0x29  /* ILI9341_DISPON    */
  .hword 0xFFFF

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
