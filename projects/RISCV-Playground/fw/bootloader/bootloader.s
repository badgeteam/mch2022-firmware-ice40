#
#    Bootloader for RISC-V Playground
#

# -----------------------------------------------------------------------------
#   Swiches for capabilities of this chip
# -----------------------------------------------------------------------------

.option norelax
.option rvc

# -----------------------------------------------------------------------------
#   Constants for memory areas
# -----------------------------------------------------------------------------

.equ characters,    0x10000000
.equ font,          0x20000000
.equ file,          0x90000000

# -----------------------------------------------------------------------------
#   Register constants for a few hardware ports
# -----------------------------------------------------------------------------

.equ uart_data,     0x40010000
.equ uart_flags,    0x40020000

.equ lcd_ctrl,      0x40001000 # LCD control lines
.equ lcd_data,      0x40002000 # LCD data, writeonly. Set 0x100 for commands.

.equ LCD_CS_N,   1
.equ LCD_RST_N,  2
.equ LCD_MODE,   4
.equ LCD_UPDATE, 8
.equ LCD_CMD, 0x100

.equ CYCLES_US,    12
.equ CYCLES_MS, 12000

# -----------------------------------------------------------------------------
#   Cold start entry here
# -----------------------------------------------------------------------------

.text

Reset:
  csrrci zero, mstatus, 8   # Clear Machine Interrupt Enable Bit
  li sp, 0x80000000 + 1024  # Set stack pointer to end of bootloader block

LCD_init:
  li x14, lcd_ctrl

  # Wait for LCD_MODE going high

  lw x15, 0(x14)
  andi x15, x15, LCD_MODE
  beq x15, zero, LCD_init

  # Wiggle the control wires for a clean start

  li x14, lcd_ctrl
  li x15,                              LCD_CS_N
  sw x15, 0(x14)

  li x8, 1*CYCLES_MS
  c.jal delay_cycles

  li x14, lcd_ctrl
  li x15,                              LCD_CS_N | LCD_RST_N
  sw x15, 0(x14)

  li x8, 120*CYCLES_MS
  c.jal delay_cycles

  li x14, lcd_ctrl
  li x15,                              LCD_RST_N
  sw x15, 0(x14)

  # Send initialisation sequence to LCD

  la x13, LCD_init_data
  li x14, lcd_data

1:lh x15, 0(x13)
  blt x15, zero, FetchFirmware

  sw x15, 0(x14)
  addi x13, x13, 2
  j 1b


FetchFirmware:

  li x10, 128*1024

1:addi x10, x10, -4

  li x11, file
  add x11, x11, x10

  lw x12, 0(x11)
  sw x12, 0(x10)

  bne x10, zero, 1b

Boot:

  lw x10, 0(zero)
  beq x10, zero, Echo # No file given? The file interface will delivers zero then which are invalid opcodes.
  jalr zero, zero, 0  # Enter freshly loaded firmware.

Echo:

  c.jal serial_key
  c.jal serial_emit
  j Echo

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
  .hword LCD_CMD|0x35, /* ILI9341_TEON      */   0x00
  .hword 0xFFFF

# -----------------------------------------------------------------------------
delay_cycles: # r8:cycles
# -----------------------------------------------------------------------------
  rdcycle x15       # Start

1:rdcycle x14       # Current
  sub x14, x14, x15 # Elapsed = Current - Start
  bltu x14, x8, 1b  # Loop if elapsed < cycles

  ret

# -----------------------------------------------------------------------------
serial_emit: # Emit one character from x8
# -----------------------------------------------------------------------------
  li x14, uart_flags

1:lw x15, 0(x14)
  andi x15, x15, 0x200 # Check "busy sending" flag
  bne x15, zero, 1b

  li x14, uart_data
  sw x8, 0(x14)
  ret

# -----------------------------------------------------------------------------
serial_key: # Receive one character into x8
# -----------------------------------------------------------------------------
  li x14, uart_flags

1:lw x15, 0(x14)
  andi x15, x15, 0x100 # Check "valid data" flag
  beq x15, zero, 1b

  li x14, uart_data
  lbu x8, 0(x14)
  ret

.org 1024, 0
