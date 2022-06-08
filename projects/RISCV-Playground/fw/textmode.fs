
\ -----------------------------------------------------------------------------
\   Timing and tools
\ -----------------------------------------------------------------------------

   12 constant cycles/us  \ For 12 MHz
12000 constant cycles/ms

: delay-cycles ( cycles -- )
  cycles ( cycles start )
  begin
    pause
    2dup ( cycles start cycles start )
    cycles ( cycles start cycles start current )
    swap - ( cycles start cycles elapsed )
    u<=
  until
  2drop
;

: us ( u -- )       cycles/us *  delay-cycles      ;
: ms ( u -- ) 0 ?do cycles/ms    delay-cycles loop ;

: randombit ( -- 0 | 1 ) $40000010 @ 8 rshift 1 and ;
: random ( -- x ) 0  32 0 do 2* randombit or 100 0 do loop loop ;

: esc? ( -- ? ) key? if key 27 = else false then ;

\ -----------------------------------------------------------------------------
\   320x240 LCD Display ILI9341
\ -----------------------------------------------------------------------------

\ Registers:

  $40000000 1 12 lshift or constant lcd-ctrl  \ LCD control lines
  $40000000 1 13 lshift or constant lcd-data  \ LCD data, writeonly. Set $100 for commands.

  $40000000 1 14 lshift or constant lcd-color0 \ Bits 31:16 Background. Bits 15:0 Foreground. (Normal)
  $40000000 1 15 lshift or constant lcd-color1 \ Bits 31:16 Background. Bits 15:0 Foreground. (Highlight)

  $40000000 1 14 lshift or      constant fg0 \ Bits 15:0 Normal foreground
  $40000000 1 14 lshift or 2 or constant bg0 \ Bits 15:0 Normal background
  $40000000 1 15 lshift or      constant fg1 \ Bits 15:0 Highlight foreground
  $40000000 1 15 lshift or 2 or constant bg1 \ Bits 15:0 Highlight background

\ -----------------------------------------------------------------------------

\ : cmd>lcd ( c -- ) $100 or lcd-data ! ; \ Logic handles the command/data line
\ :    >lcd ( c -- ) $FF and lcd-data ! ;  \ and pulses write line.

\ -----------------------------------------------------------------------------

create lcd-init-data

  $CF ( ILI9341_POWERB    ) $100 or h, $00 h, $C1 h, $30 h,
  $ED ( ILI9341_POWER_SEQ ) $100 or h, $64 h, $03 h, $12 h, $81 h,
  $E8 ( ILI9341_DTCA      ) $100 or h, $85 h, $00 h, $78 h,
  $CB ( ILI9341_POWERA    ) $100 or h, $39 h, $2C h, $00 h, $34 h, $02 h,
  $F7 ( ILI9341_PRC       ) $100 or h, $20 h,
  $EA ( ILI9341_DTCB      ) $100 or h, $00 h, $00 h,
  $C0 ( ILI9341_LCMCTRL   ) $100 or h, $23 h,
  $C1 ( ILI9341_POWER2    ) $100 or h, $10 h,
  $C5 ( ILI9341_VCOM1     ) $100 or h, $3e h, $28 h,
  $C7 ( ILI9341_VCOM2     ) $100 or h, $86 h,
  $36 ( ILI9341_MADCTL    ) $100 or h, $08 h,
  $3A ( ILI9341_COLMOD    ) $100 or h, $55 h,
  $B1 ( ILI9341_FRMCTR1   ) $100 or h, $00 h, $18 h,
  $B6 ( ILI9341_DFC       ) $100 or h, $08 h, $82 h, $27 h,
  $F2 ( ILI9341_3GAMMA_EN ) $100 or h, $00 h,
  $26 ( ILI9341_GAMSET    ) $100 or h, $01 h,

  $E0 ( ILI9341_PVGAMCTRL ) $100 or h, $0F h, $31 h, $2B h, $0C h, $0E h,
                                       $08 h, $4E h, $F1 h, $37 h, $07 h,
                                       $10 h, $03 h, $0E h, $09 h, $00 h,
  $E1 ( ILI9341_NVGAMCTRL ) $100 or h, $00 h, $0E h, $14 h, $03 h, $11 h,
                                       $07 h, $31 h, $C1 h, $48 h, $08 h,
                                       $0F h, $0C h, $31 h, $36 h, $0F h,

  $F6 ( ILI9341_INTERFACE ) $100 or h, $00 h, $40 h, $00 h,

  $11 ( ILI9341_SLPOUT    ) $100 or h,
  $29 ( ILI9341_DISPON    ) $100 or h,

  $35 ( ILI9341_TEON      ) $100 or h, $00 h,

  $FFFF h, align


: lcd-init ( -- )

  ." Trying to get access to LCD... Press ESC to exit." cr

  begin
    esc? if risc-v quit then
    lcd-ctrl @ 4 ( LCD_MODE ) and
  until

  1 ( LCD_CS_N )                    lcd-ctrl !
  1 ms
  1 ( LCD_CS_N ) 2 ( LCD_RST_N ) or lcd-ctrl !
  120 ms
                 2 ( LCD_RST_N )    lcd-ctrl !

  lcd-init-data
  begin
    dup h@ $FFFF <>
  while
    dup h@ lcd-data !
    2 +
  repeat
  drop
;

\ -----------------------------------------------------------------------------
\  Text mode with character buffer
\ -----------------------------------------------------------------------------

: font! ( x addr -- ) $20000000 or c! ;
: font@ ( addr -- x ) $20000000 or c@ ;

: char! ( x addr -- ) $10000000 or c! ;
: char@ ( addr -- x ) $10000000 or c@ ;

\ -----------------------------------------------------------------------------
\   Character handling for text mode
\ -----------------------------------------------------------------------------

0 variable xpos
0 variable ypos

false variable textmarker

: highlight ( -- )  true textmarker ! ;
: normal    ( -- ) false textmarker ! ;

0 variable captionchars

: caption ( -- ) \ Fix caption lines when scrolling
  ypos @ 40 * xpos @ + captionchars !
;

: nocaption ( -- ) 0 captionchars ! ; \ Remove caption protection

: page ( -- ) \ Clear display
  1200 captionchars @ do 32 i char! loop
  captionchars @ 40 /mod ypos ! xpos !
;

: clr ( -- ) page ; \ Just an intuitive alias for page

: addline ( -- )
  ypos @ 29 < if
    1 ypos +!
  else
    1200 40 captionchars @ + do i char@ i 40 - char! loop
    1200 1160 do 32 i char! loop
  then
  0 xpos !
;

: addchar ( c -- )
  textmarker @ if $80 or then
  xpos @ 39 > if addline 0 xpos ! then
  ypos @ 40 * xpos @ + char!
  1 xpos +!
;

: stepback ( -- )
  xpos @
  if
    -1 xpos +!
  else
    ypos @ if -1 ypos +! 39 xpos ! then
  then
;

: lcd-emit ( c -- )
  case
    10 of addline  endof \ Line Feed
     8 of stepback endof \ Backspace
    dup $C0 and $80 <> if dup 127 umin addchar then \ Display block glyph for UTF-8 chars.
  endcase
;

: dispatch-emit ( c -- ) dup lcd-emit serial-emit ;

: +lcd ( -- ) ['] dispatch-emit hook-emit ! page ;
: -lcd ( -- ) [']   serial-emit hook-emit ! ;

\ -----------------------------------------------------------------------------
\  Color constants by Andrew Palm
\ -----------------------------------------------------------------------------

\ Colors are 565 RGB (5 bits Red, 6 bits green, 5 bits blue)

$0000 constant BLACK       \    0,   0,   0
$000F constant NAVY        \    0,   0, 128
$03E0 constant DARKGREEN   \    0, 128,   0
$03EF constant DARKCYAN    \    0, 128, 128
$7800 constant MAROON      \  128,   0,   0
$780F constant PURPLE      \  128,   0, 128
$7BE0 constant OLIVE       \  128, 128,   0
$C618 constant LIGHTGREY   \  192, 192, 192
$7BEF constant DARKGREY    \  128, 128, 128
$001F constant BLUE        \    0,   0, 255
$07E0 constant GREEN       \    0, 255,   0
$07FF constant CYAN        \    0, 255, 255
$F800 constant RED         \  255,   0,   0
$F81F constant MAGENTA     \  255,   0, 255
$FFE0 constant YELLOW      \  255, 255,   0
$FFFF constant WHITE       \  255, 255, 255
$FD20 constant ORANGE      \  255, 165,   0
$AFE5 constant GREENYELLOW \  173, 255,  47
$F81F constant PINK        \  255,   0, 255

\ Default colors are:
\
\   yellow fg0 h!  \ Normal foreground
\   navy   bg0 h!  \ Normal background
\   cyan   fg1 h!  \ Highlight foreground
\   navy   bg1 h!  \ Highlight background

lcd-init +lcd




