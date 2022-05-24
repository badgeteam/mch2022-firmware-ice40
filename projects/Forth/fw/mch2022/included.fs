
\ Definitions in high-level Forth that can be compiled by the small
\ nucleus itself. They are included into the bitstream for default.

\ #######   CORE   ############################################

: [']
    '
; immediate 0 foldable

: [char]
    char
; immediate 0 foldable

: (
    [char] ) parse 2drop
; immediate 0 foldable

: u>= ( u1 u2 -- ? ) u< invert ; 2 foldable
: u<= ( u1 u2 -- ? ) u> invert ; 2 foldable
: >=  ( n1 n2 -- ? )  < invert ; 2 foldable
: <=  ( n1 n2 -- ? )  > invert ; 2 foldable

: else
    postpone ahead
    swap
    postpone then
; immediate

: while
    postpone if
    swap
; immediate

: repeat
     postpone again
     postpone then
; immediate

: create ( "<name>" -- ; -- addr )
    :
    here 2 cells + postpone literal
    postpone ;
;

: buffer: ( u "<name>" -- ; -- addr )
   create allot 0 foldable
;

: >body ( addr -- addr' )
    @ -1 1 rshift and \ Remove the literal opcode MSB
;

: m* ( n1 n2 -- d )
    2dup xor >r
    abs swap abs um*
    r> 0< if dnegate then
; 2 foldable

: variable ( x "name" -- ; -- addr )
    create ,
    0 foldable
;

: constant ( x "name" -- ; -- x ) : postpone literal postpone ; 0 foldable ;

: sgn ( u1 n1 -- n2 ) \ n2 is u1 with the sign of n1
    0< if negate then
; 2 foldable

\ Divide d1 by n1, giving the symmetric quotient n3 and the remainder
\ n2.
: sm/rem ( d1 n1 -- n2 n3 )
    2dup xor >r     \ combined sign, for quotient
    over >r         \ sign of dividend, for remainder
    abs >r dabs r>
    um/mod          ( remainder quotient )
    swap r> sgn     \ apply to remainder
    swap r> sgn     \ apply to quotient
; 3 foldable

\ Divide d1 by n1, giving the floored quotient n3 and the remainder n2.
\ Adapted from hForth
: fm/mod ( d1 n1 -- n2 n3 )
    dup >r 2dup xor >r
    >r dabs r@ abs
    um/mod
    r> 0< if
        swap negate swap
    then
    r> 0< if
        negate         \ negative quotient
        over if
            r@ rot - swap 1-
        then
    then
    r> drop
; 3 foldable

: */mod ( n1 n2 n3 -- n4 n5 ) >r m* r> sm/rem ; 3 foldable
: */    ( n1 n2 n3 -- n4 )    */mod nip ; 3 foldable

: spaces ( n -- )
    begin
        dup 0>
    while
        space 1-
    repeat
    drop
;

( Pictured numeric output                    JCB 08:06 07/18/14)
\ Adapted from hForth

\ "The size of the pictured numeric output string buffer shall
\ be at least (2*n) + 2 characters, where n is the number of
\ bits in a cell."

create BUF0
16 cells 2 + 128 max
allot here constant BUF

0 variable hld

: <# ( -- )
    BUF hld !
;

: hold ( c -- )
    hld @ 1- dup hld ! c!
;

: sign ( n -- )
    0< if
        [char] - hold
    then
;

: .digit ( u -- c )
  9 over <
  [char] A [char] 9 1 + -
  and +
  [char] 0 +
;

: # ( ud -- ud* )
    0 base @ um/mod >r base @ um/mod swap
    .digit hold r>
;

: #s ( ud -- 0 0 )
    begin
        #
        2dup d0=
    until
;

: #> ( ud -- addr len )
    2drop hld @ BUF over -
;

: (d.) ( d -- addr len )
    dup >r dabs <# #s r> sign #>
;

: ud. ( ud -- )
    <# #s #> type space
;

: d. ( d -- )
    (d.) type space
;

: . ( n -- )
    s>d d.
;

: u. ( u -- )
    0 d.
;

: rtype ( caddr u1 u2 -- ) \ display character string specified by caddr u1
                           \ in a field u2 characters wide.
  2dup u< if over - spaces else drop then
  type
;

: d.r ( d length -- )
    >r (d.)
    r> rtype
;

: .r ( n length -- )
    >r s>d r> d.r
;

: u.r ( u length -- )
    0 swap d.r
;

( Memory operations                          JCB 18:02 05/31/15)

: move ( addr1 addr2 u -- )
    >r 2dup u< if
        r> cmove>
    else
        r> cmove
    then
;

: /mod ( n1 n2 -- n3 n4 ) >r s>d r> sm/rem ; 2 foldable
: /    ( n1 n2 -- n3 )    /mod nip ; 2 foldable
: mod  ( n1 n2 -- n3 )    /mod drop ; 2 foldable

: ."
    [char] " parse
    state @ if
        postpone sliteral
        postpone type
    else
        type
    then
; immediate 0 foldable

\ #######   CORE EXT   ########################################

: pad ( -- addr )
    here aligned
;

: within ( n1|u1 n2|u2 n3|u3 -- flag ) over - >r - r> u< ; 3 foldable

: s"
    [char] " parse
    state @ if
        postpone sliteral
    then
; immediate

( CASE                                       JCB 09:15 07/18/14)
\ From ANS specification A.3.2.3.2

: case ( -- 0 ) 0 ; immediate  ( init count of ofs )

: of  ( #of -- orig #of+1 / x -- )
    1+    ( count ofs )
    >r    ( move off the stack in case the control-flow )
          ( stack is the data stack. )
    postpone over  postpone = ( copy and test case value)
    postpone if    ( add orig to control flow stack )
    postpone drop  ( discards case value if = )
    r>             ( we can bring count back now )
; immediate

: endof ( orig1 #of -- orig2 #of )
    >r   ( move off the stack in case the control-flow )
         ( stack is the data stack. )
    postpone else
    r>   ( we can bring count back now )
; immediate

: endcase  ( orig1..orign #of -- )
    postpone drop  ( discard case value )
    0 ?do
      postpone then
    loop
; immediate

\ #######   DICTIONARY   ######################################

: cornerstone ( "name" -- )
  create
    forth 2@        \ preserve FORTH and DP after this
    , 2 cells + ,
  does>
    2@ forth 2! \ restore FORTH and DP
;

\ -------------------------------------------------------------
\  Double tools
\ -------------------------------------------------------------

: 2or  ( d1 d2 -- d ) >r swap >r or  r> r> or  ; 4 foldable
: 2and ( d1 d2 -- d ) >r swap >r and r> r> and ; 4 foldable
: 2xor ( d1 d2 -- d ) >r swap >r xor r> r> xor ; 4 foldable

: d0<   ( d -- ? ) nip 0< ; 2 foldable

: d= ( x0 x1 y0 y1 -- ? )

  swap ( x0 x1 y1 y0 )
  >r   ( x0 x1 y1 R: y0 )
  =    ( x0 x1=y1 R: y0 )
  swap ( x1=y1 x0 R: y0 )
  r>   ( x1=y1 x0 y0 )
  =    ( x1=y1 x0=y0 )
  and
; 4 foldable

: d<> d= not ; 4 foldable

: d2/  ( x1 x2 -- x1' x2' ) >r 1 rshift r@ 8 cells 1- lshift or r> 2/       ; 2 foldable
: dshr ( x1 x2 -- x1' x2' ) >r 1 rshift r@ 8 cells 1- lshift or r> 1 rshift ; 2 foldable

\ : 2lshift  ( ud u -- ud* ) begin dup while >r d2*  r> 1- repeat drop ; 3 foldable
\ : 2arshift (  d u --  d* ) begin dup while >r d2/  r> 1- repeat drop ; 3 foldable
\ : 2rshift  ( ud u -- ud* ) begin dup while >r dshr r> 1- repeat drop ; 3 foldable

: 2lshift ( low high u -- )
  dup >r ( low high u R: u )
  lshift ( low high* )
  over 8 cells r@ - rshift or
  over r@ 8 cells - lshift or
  swap r> lshift swap
; 3 foldable

: 2rshift ( low high u -- )
  >r swap ( high low R: u )
  r@ rshift
  over 8 cells r@ - lshift or
  over r@ 8 cells - rshift or
  swap
  r> rshift
; 3 foldable

: 2arshift ( low high u -- )
  dup >r 8 cells u< ( low high R: u )
  if
    swap ( high low R: u )
    r@ rshift
    over 8 cells r@ - lshift or
  else
    nip dup r@ 8 cells - arshift
  then
  swap r> arshift
; 3 foldable

: 2nip ( d1 d2 -- d2 )
  >r nip nip r>
; 4 foldable

: 2rot ( d1 d2 d3 -- d2 d3 d1 )
  >r >r ( d1 d2 R: d3 )
  2swap ( d2 d1 R: d3 )
  r> r> ( d2 d1 d3 )
  2swap ( d2 d3 d1 )
; 6 foldable

: d<            \ ( al ah bl bh -- flag )
    rot         \ al bl bh ah
    2dup =
    if
        2drop u<
    else
        > nip nip
    then
; 4 foldable

: d>  ( d1 d2 -- ? ) 2swap d< ; 4 foldable
: d>= ( d1 d2 -- ? ) d< not   ; 4 foldable
: d<= ( d1 d2 -- ? ) d> not   ; 4 foldable

: dmin ( d1 d2 -- d ) 2over 2over d< if 2drop else 2nip then ; 4 foldable
: dmax ( d1 d2 -- d ) 2over 2over d< if 2nip else 2drop then ; 4 foldable

: du<           \ ( al ah bl bh -- flag )
    rot         \ al bl bh ah
    2dup =
    if
        2drop u<
    else
        u> nip nip
    then
; 4 foldable

: du>  ( d1 d2 -- ? ) 2swap du< ; 4 foldable
: du>= ( d1 d2 -- ? ) du< not   ; 4 foldable
: du<= ( d1 d2 -- ? ) du> not   ; 4 foldable

\ -------------------------------------------------------------
\  Fixpoint output
\ -------------------------------------------------------------

: hold< ( c -- ) \ Add a character at the end of the number string
  hld @   dup 1- dup hld !    BUF hld @ -  move
  BUF 1- c!
;

: f# ( u -- u ) base @ um* .digit hold< ;

: f.n ( f n -- ) ( f-Low f-High n -- ) \ Prints a s15.16 number

  >r ( Low High R: n )

  dup 0< if [char] - emit then
  dabs
  ( uLow uHigh )
  0 <# #s   ( uLow 0 0 )
  drop swap ( 0 uLow )

  [char] , hold<
  r> 0 ?do f# loop

  #> type space
;

: f. ( f -- ) 8 cells f.n ;

\ -------------------------------------------------------------
\  Fixpoint calculations
\ -------------------------------------------------------------

: 2variable ( d -- ) create , , 0 foldable ;
\ : 2constant ( d -- ) create , , 0 foldable does> 2@ ;
: 2constant ( d -- ) swap : postpone literal postpone literal postpone ; 0 foldable ;

: s>f ( n -- f ) 0 swap ; 1 foldable  \ Signed integer --> Fixpoint s15.16
\ : f>s ( f -- n ) nip    ; 2 foldable  \ Fixpoint s15.16 --> Signed integer

: f* ( f1 f2 -- f )

        dup >r dabs
  2swap dup >r dabs

            ( d c b a )
  swap >r   ( d c a R: b )
  2dup *    ( d c a ac R: b )
  >r        ( d c a R: b ac )
  >r        ( d c R: b ac a )
  over      ( d c d R: b ac a )
  r> um*    ( d c L H R: b ac )
  r> +      ( d c L H' R: b )
  rot       ( d L H' c R: b )
  r@        ( d L H' c b R: b )
  um* d+    ( d L' H'' R: b )
  rot       ( L' H'' d R: b )
  r>        ( L' H'' d b )
  um* nip 0 ( L' H'' db 0 )
  d+        ( L'' H''' )

  r> r> xor 0< if dnegate then

; 4 foldable

0. 2variable dividend
0. 2variable shift
0. 2variable divisor

: (ud/mod) ( -- )

  16 cells
  begin

    \ Shift the long chain of four cells.

       dividend cell+ @ dup 8 cells 1- rshift >r 2*    dividend cell+ !
    r> dividend       @ dup 8 cells 1- rshift >r 2* or dividend       !
    r>    shift cell+ @ dup 8 cells 1- rshift >r 2* or    shift cell+ !
    r>    shift       @                          2* or    shift       !

    \ Subtract divisor when shifted out value is large enough

    shift 2@ divisor 2@  du>=

    if \ Greater or Equal: Subtract !
      shift 2@ divisor 2@ d- shift 2!
      dividend cell+ @ 1+ dividend cell+ !
    then

    1- dup 0=
  until
  drop
;

: ud/mod ( ud1 ud2 -- ud-rem ud-div )

     divisor 2!
  0. shift 2!
     dividend 2!

  (ud/mod)

  shift 2@
  dividend 2@

; 4 foldable

: f/ ( f1 f2 -- f )

  dup >r dabs  divisor 2!
  dup >r dabs  0 Shift 2! 0 swap dividend 2!

  (ud/mod)

  dividend 2@
  r> r> xor 0< if dnegate then

; 4 foldable
\ #######   MEMORY   ##########################################

: unused ( -- u ) $3200 here - ; \ 12.5 kb

\ #######   IO   ##############################################

: cycles ( -- u ) $8000 io@ ;

   24 constant cycles/us  \ For 24 MHz
24000 constant cycles/ms

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

: randombit ( -- 0 | 1 ) $2000 io@ 2 rshift 1 and ;
: random ( -- x ) 0  16 0 do 2* randombit or 100 0 do loop loop ;

: ticks ( -- u ) $4000 io@ ;

: nextirq ( cycles -- ) \ Trigger the next interrupt u cycles after the last one.
  $4000 io@  \ Read current tick
  -           \ Subtract the cycles already elapsed
  8 -          \ Correction for the cycles neccessary to do this
  invert        \ Timer counts up to zero to trigger the interrupt
  $4000 io!      \ Prepare timer for the next irq
;

: sram@ ( addr -- x ) $0800 io! $0810 io@ ;
: sram! ( x addr -- ) $0800 io! $0810 io! ;

: esc? ( -- ? ) key? if key 27 = else false then ;

$608C $31FE ! \ Location $31FE is an interrupt vector ! Place ALU exit opcode here.

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

  1 ( LCD_CS_N ) 4 ( LCD_MODE ) or                    lcd-ctrl io!
  1 ms
  1 ( LCD_CS_N ) 4 ( LCD_MODE ) or 2 ( LCD_RST_N ) or lcd-ctrl io!
  120 ms
                 4 ( LCD_MODE )    2 ( LCD_RST_N ) or lcd-ctrl io!

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


dint -lcd new

\ -----------------------------------------------------------------------------
\   PMOD-Lab
\ -----------------------------------------------------------------------------

  $0100     constant in

  $0200     constant out
  $0200 1 + constant out-clr
  $0200 2 + constant out-set
  $0200 3 + constant out-xor

  $0400     constant dir
  $0400 1 + constant dir-clr
  $0400 2 + constant dir-set
  $0400 3 + constant dir-xor

  $08B0 constant leds-special \ [6:4]: In [2:0]: Constant current drivers
  $08C0 constant pwm-red
  $08D0 constant pwm-green
  $08E0 constant pwm-blue


\ -----------------------------------------------------------------------------
\   Shortcuts for quick manual pin handling
\ -----------------------------------------------------------------------------

: h ( u -- ) \ Set pin high
  1 swap lshift dup out-set io!
                    dir-set io!
;

: l ( u -- ) \ Set pin low
  1 swap lshift dup out-clr io!
                    dir-set io!
;

: t ( u -- ) \ Toggle pin
  1 swap lshift dup out-xor io!
                    dir-set io!
;

: z ( u -- ) \ Set pin as input
  1 swap lshift     dir-clr io!
;

\ -----------------------------------------------------------------------------
\   IO state that should be in view
\ -----------------------------------------------------------------------------

0. 2variable (ms)
0 variable green-sunshine
0 variable average-sunshine

4 constant avgshift \ Moving exponential average
: expavg ( avg x -- avg' ) swap dup avgshift arshift - + ;

: sunshine-indicator ( u -- ) \ 0 to 16
  0 umax
  17 0 do
    i over <
    if
      [char] - $80 or
    else
      i over =
      if
        [char] *
      else
        bl
      then
    then
    i 40 + char!
  loop
  drop
;

: pinstate ( -- )

  \ State of PMOD IN, OUT and DIR registers in hexadecimal

  in io@
  dup 4 rshift $F and .digit  4 char!
               $F and .digit  5 char!

  out io@
  dup 4 rshift $F and .digit 12 char!
               $F and .digit 13 char!

  dir io@
  dup 4 rshift $F and .digit 20 char!
               $F and .digit 21 char!

  \ High-Low-Indicators for the PMOD pin states

  8 0 do

    32 38 i - char!
    32 78 i - char!

    in io@ 1 i lshift and if [char] H $80 or 38 i - char!
                        else [char] L $80 or 78 i - char! then

    dir io@ 1 i lshift and
    if
      out io@ 1 i lshift and if [char] 1      38 i - char!
                           else [char] 0      78 i - char! then
    then
  loop

  \ Brightness measurement

  pwm-green io@
  pwm-blue  io@ or
  if
    \ When blue or green shine, no brightness measurements are possible.
    0 sunshine-indicator
    0 average-sunshine !
  else
    leds-special io@ 5 rshift 1 and 1 xor green-sunshine +!

    (ms) cell+ @ 15 and 0= \ Low part of millisecond counter, do every 16th ms:
    if
      average-sunshine @
        green-sunshine @ expavg
      dup average-sunshine !

      avgshift rshift 6 - sunshine-indicator \ Adjust indicator to the observed values

      \ Pulse green LED to charge the junction
      2 leds-special io!
      0 leds-special io!

      0 green-sunshine !
    then
  then

  \ leds-special io@ $20 and if [char] - else [char] * then 23 char!
;

\ -----------------------------------------------------------------------------
\  Clock for counting milliseconds and update values on display
\ -----------------------------------------------------------------------------

: interrupt ( -- )
  (ms) 2@ 1. d+ (ms) 2!
  cycles/ms nextirq

  $0820 io@ \ Save "access address" as we change this one in interrupt handler
  pinstate
  $0820 io! nop nop nop \ Three cycles delay for the value to be active again
;

: time ( -- ud )
  begin
    (ms) @        \ High-Teil
    (ms) cell+ @  \  Low-Teil
    over ( high low high )
    (ms) @ ( high low high high* )
    =
  until
  swap
;

' interrupt 1 rshift $31FE ! \ Generate JMP opcode for vector location

\ -----------------------------------------------------------------------------
\  Fun with colors
\ -----------------------------------------------------------------------------

\ For use with three byte brightness values

: rgb ( r g b -- ) 8 lshift pwm-blue io! 8 lshift pwm-green io! 8 lshift pwm-red io! ;

\ For use with a 6:5:6 LCD color constant

: color ( x -- )
  dup %0000000000011111 and  0 rshift 3 lshift >r
  dup %0000011111100000 and  5 rshift 2 lshift >r
      %1111100000000000 and 11 rshift 3 lshift r> r> rgb
;

\ -----------------------------------------------------------------------------
\  PMOD laboratory and user interface
\ -----------------------------------------------------------------------------

: blink ( -- )
  $FF dir io!
  begin
    $AA out io! 500 ms
    $55 out io! 500 ms
  esc? until
;

: printrandom ( -- )
  begin
    random dup 0<
    if
      [char] /
    else
      [char] \
    then

    over $4000 and if $80 or then \ Random highlight

    swap

    \ Calculate position from the random number in a 8x8 grid
    dup  $07 and          10 + 40 *
    swap $38 and 3 rshift 28 +
    +

    char!
    30 ms
  esc? until
;

: pmod-lab ( -- )
  lcd-init
  +lcd
  nocaption
  page

  \            0123456789012345678901234567890123456789
  highlight ." In:    Out:    Dir:      High:[        ]"        cr
            ."                           Low:[        ]" normal cr
  caption
  eint
  cr
  ." May the Forth be with you!" cr
  cr
  ." Connect terminal with" cr
  ." 115200 baud 8N1 LF to ttyACM1" cr
  cr
  ." Switch pin 0 high:  " highlight ." 0 h" normal cr
  ." Switch pin 4 low:   " highlight ." 4 l" normal cr
  ." Toggle pin 1:       " highlight ." 1 t" normal cr
  ." Set pin 2 as input: " highlight ." 2 z" normal cr
  cr
  highlight
  ." : blink " normal ." ( -- )" highlight cr
  ."   $FF dir io!" cr
  ."   begin" cr
  ."     $AA out io! 500 ms" cr
  ."     $55 out io! 500 ms" cr
  ."   esc? until" cr
  ." ;" cr
  ." blink" cr
  normal
  cr
  ." Type " highlight ." WORDS" normal ."  to see a list of commands" cr
  cr
  ." Press ESC to continue." cr

  printrandom
  welcome
;

' pmod-lab init !

\ #######   DUMP   ############################################

: dump
    ?dup
    if
        1- 4 rshift 1+
        0 do
            cr dup dup .x space space
            16 0 do
                dup c@ .x2 1+
            loop
            space swap
            16 0 do
                dup c@ dup bl 127 within invert if
                    drop [char] .
                then
                emit 1+
            loop
            drop
        loop
    then
    drop
;

\ #######   INSIGHT   #########################################


( Deep insight into stack, dictionary and code )
( Matthias Koch )

: .s ( -- )
  \ Save initial depth
  depth dup >r

  \ Flush stack contents to temporary storage
  begin
    dup
  while
    1-
    swap
    over cells pad + !
  repeat
  drop

  \ Print original depth
  ." [ "
  r@ .x2
  ." ] "

  \ Print all elements in reverse order
  r@
  begin
    dup
  while
    r@ over - cells pad + @ .x
    1-
  repeat
  drop

  \ Restore original stack
  0
  begin
    dup r@ u<
  while
    dup cells pad + @ swap
    1+
  repeat
  rdrop
  drop
;

: insight ( -- )  ( Long listing of everything inside of the dictionary structure )
    base @ hex cr
    forth @
    begin
        dup
    while
         ." Addr: "     dup .x
        ."  Link: "     dup link@ .x
        ."  Flags: "    dup cell+ c@ 128 and if ." I " else ." - " then
                        dup @ 7 and ?dup if 1- u. else ." - " then
        ."  Code: "     dup cell+ count 127 and + aligned .x
        space           dup cell+ count 127 and type
        link@ cr
    repeat
    drop
    base !
;

0 variable disasm-$    ( Current position for disassembling )
0 variable disasm-cont ( Continue up to this position )

: name. ( Address -- )  ( If the address is Code-Start of a dictionary word, it gets named. )

  dup ['] s, 24 + = \ Is this a string literal ?
  if
    ."   --> s" [char] " emit space
    disasm-$ @ count type
    [char] " emit

    disasm-$ @ c@ 1+ aligned disasm-$ +!
    drop exit
  then

  >r
  forth @
  begin
    dup
  while
    dup cell+ count 127 and + aligned ( Dictionary Codestart )
      r@ = if ."   --> " dup cell+ count 127 and type then
    link@
  repeat
  drop r>

  $000C =                            \ A call to execute
  disasm-$ @ 2 cells - @ $C000 and $C000 =  \ after a literal which has bit $4000 set means:
  and                                  \ Memory fetch.
  if
    ."   --> " disasm-$ @ 2 cells - @ $3FFF and .x ." @"
  then
;

: alu. ( Opcode -- ) ( If this opcode is from an one-opcode definition, it gets named. This way inlined ALUs get a proper description. )

  dup $6127 = if ." >r"    drop exit then
  dup $6B11 = if ." r@"    drop exit then
  dup $6B1D = if ." r>"    drop exit then
  dup $600C = if ." rdrop" drop exit then

  $FF73 and
  >r
  forth @
  begin
    dup
  while
    dup cell+ count 127 and + aligned @ ( Dictionary First-Opcode )
        dup $E080 and $6080 =
        if
          $FF73 and r@ = if rdrop cell+ count 127 and type space exit then
        else
          drop
        then

    link@
  repeat
  drop r> drop
;


: memstamp ( Addr -- ) dup .x ." : " @ .x ."   " ; ( Shows a memory location nicely )

: disasm-step ( -- )
  disasm-$ @ memstamp
  disasm-$ @ @        ( Fetch next opcode )
  1 cells disasm-$ +! ( Increment position )

  dup $8000 and         if ." Imm  " $7FFF and       dup .x 6 spaces                      .x       exit then ( Immediate )
  dup $E000 and $0000 = if ." Jmp  " $1FFF and cells dup                                  .x name. exit then ( Branch )
  dup $E000 and $2000 = if ." JZ   " $1FFF and cells disasm-cont @ over max disasm-cont ! .x       exit then ( 0-Branch )
  dup $E000 and $4000 = if ." Call " $1FFF and cells dup                                  .x name. exit then ( Call )
                           ." Alu"   13 spaces dup alu. $80 and if ." exit" then                             ( ALU )
;

: seec ( -- ) ( Continues to see )
  base @ hex cr
  0 disasm-cont !
  begin
    disasm-$ @ @
    dup  $E080 and $6080 =           ( Loop terminates with ret )
    swap $E000 and 0= or             ( or when an unconditional jump is reached. )
    disasm-$ @ disasm-cont @ u>= and ( Do not stop when there has been a conditional jump further )

    disasm-step cr
  until

  base !
;

: see ( -- ) ( Takes name of definition and shows its contents from beginning to first ret )
  ' disasm-$ !
  seec
;

cornerstone new

