
\ -----------------------------------------------------------------------------
\ 320x240 LCD Display ILI9341
\ -----------------------------------------------------------------------------

\ Registers:

  $0890 constant lcd-ctrl  \ LCD control lines
  $08A0 constant lcd-data  \ LCD data, writeonly. Set $100 for commands.

  $0850 constant fg0  \ Normal foreground
  $0860 constant bg0  \ Normal background
  $0870 constant fg1  \ Highlight foreground
  $0880 constant bg1  \ Highlight background

\ -----------------------------------------------------------------------------

: cmd>lcd ( c -- ) $100 or lcd-data io! ; \ Logic handles the command/data line
:    >lcd ( c -- ) $FF and lcd-data io! ;  \ and pulses write line.

\ -----------------------------------------------------------------------------

: lcd-init ( -- )

  ." Trying to get access to LCD... Press ESC to exit." cr

  begin
    esc? if welcome quit then
    lcd-ctrl io@ 4 ( LCD_MODE ) and
  until

  1 ( LCD_CS_N )                    lcd-ctrl io!
  1 ms
  1 ( LCD_CS_N ) 2 ( LCD_RST_N ) or lcd-ctrl io!
  120 ms
                 2 ( LCD_RST_N )    lcd-ctrl io!

  \ Initialisation sequence

  $CF ( ILI9341_POWERB    ) cmd>lcd $00 >lcd $C1 >lcd $30 >lcd
  $ED ( ILI9341_POWER_SEQ ) cmd>lcd $64 >lcd $03 >lcd $12 >lcd $81 >lcd
  $E8 ( ILI9341_DTCA      ) cmd>lcd $85 >lcd $00 >lcd $78 >lcd
  $CB ( ILI9341_POWERA    ) cmd>lcd $39 >lcd $2C >lcd $00 >lcd $34 >lcd $02 >lcd
  $F7 ( ILI9341_PRC       ) cmd>lcd $20 >lcd
  $EA ( ILI9341_DTCB      ) cmd>lcd $00 >lcd $00 >lcd
  $C0 ( ILI9341_LCMCTRL   ) cmd>lcd $23 >lcd
  $C1 ( ILI9341_POWER2    ) cmd>lcd $10 >lcd
  $C5 ( ILI9341_VCOM1     ) cmd>lcd $3e >lcd $28 >lcd
  $C7 ( ILI9341_VCOM2     ) cmd>lcd $86 >lcd
  $36 ( ILI9341_MADCTL    ) cmd>lcd $08 >lcd
  $3A ( ILI9341_COLMOD    ) cmd>lcd $55 >lcd
  $B1 ( ILI9341_FRMCTR1   ) cmd>lcd $00 >lcd $18 >lcd
  $B6 ( ILI9341_DFC       ) cmd>lcd $08 >lcd $82 >lcd $27 >lcd
  $F2 ( ILI9341_3GAMMA_EN ) cmd>lcd $00 >lcd
  $26 ( ILI9341_GAMSET    ) cmd>lcd $01 >lcd

  $E0 ( ILI9341_PVGAMCTRL ) cmd>lcd $0F >lcd $31 >lcd $2B >lcd $0C >lcd $0E >lcd
                                    $08 >lcd $4E >lcd $F1 >lcd $37 >lcd $07 >lcd
                                    $10 >lcd $03 >lcd $0E >lcd $09 >lcd $00 >lcd
  $E1 ( ILI9341_NVGAMCTRL ) cmd>lcd $00 >lcd $0E >lcd $14 >lcd $03 >lcd $11 >lcd
                                    $07 >lcd $31 >lcd $C1 >lcd $48 >lcd $08 >lcd
                                    $0F >lcd $0C >lcd $31 >lcd $36 >lcd $0F >lcd

  $F6 ( ILI9341_INTERFACE ) cmd>lcd $00 >lcd $40 >lcd $00 >lcd

  $11 ( ILI9341_SLPOUT    ) cmd>lcd
  $29 ( ILI9341_DISPON    ) cmd>lcd

  $35 ( ILI9341_TEON      ) cmd>lcd $00 >lcd
;

: waitretrace ( -- ) \ Wait for end of screen update actvity
    begin lcd-ctrl io@ $10 and    until \ LCD currently updating
    begin lcd-ctrl io@ $10 and 0= until \ LCD not updating anymore
;

\ -----------------------------------------------------------------------------
\  Text mode with character buffer
\ -----------------------------------------------------------------------------

: font! ( x addr -- ) $0820 io!         $0830 io! ; \ Writing of font bitmaps happens immediately
: font@ ( addr -- x ) $0820 io! nop nop $0830 io@ ; \ Font bitmaps can be read back three cycles after the address is set

: char! ( x addr -- ) $0820 io!         $0840 io! ; \ Writing of characters happens immediately
: char@ ( addr -- x ) $0820 io! nop nop $0840 io@ ; \ Characters can be read back three cycles after the address is set

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

\ Replace the io! at the end of emit with a jump to this
\ for hooking the LCD into the terminal.

: dispatch-emit ( c -- ) over lcd-emit io! ;

: +lcd ( -- ) ['] dispatch-emit 2/  ['] emit 6 + ! ;
: -lcd ( -- ) $78CE                 ['] emit 6 + ! ;

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
\   yellow fg0 io!  \ Normal foreground
\   navy   bg0 io!  \ Normal background
\   cyan   fg1 io!  \ Highlight foreground
\   navy   bg1 io!  \ Highlight background
