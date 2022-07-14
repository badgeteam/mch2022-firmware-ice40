
\ ------------------------------------------------------------------------------
\   A few IO registers
\ ------------------------------------------------------------------------------

  $08C0 constant pwm-red
  $08D0 constant pwm-green
  $08E0 constant pwm-blue

: buttons $08F0 io@ ; \ Read button state

\ ------------------------------------------------------------------------------
\   Ledcomm
\ ------------------------------------------------------------------------------

$1010 constant l-data
$2010 constant l-flags
$2020 constant timebase \ Default: 1200 / 24 MHz = 50 us
$2030 constant charging \ Default:   24 / 24 MHz =  1 us

: stop   ( -- ) $0010 l-flags bis! ;
: start  ( -- ) $0010 l-flags bic! ;

: bright ( -- ) $0000 l-flags io! ; \ Release reset, switch to bright mode
: dark   ( -- ) $0008 l-flags io! ; \ Release reset, switch to dark   mode

: l-emit? ( -- ? ) pause l-flags io@ 1 and 0<> ;
: l-key?  ( -- ? ) pause l-flags io@ 2 and 0<> ;
: l-link? ( -- ? ) pause l-flags io@ 4 and 0<> ;

: l-emit  ( c -- ) begin l-emit? until l-data io! ;
: l-key   ( c -- ) begin l-key?  until l-data io@ ;

: l-exchange ( >x -- x> true | false ) \ Send and receive one cell, do not block if link fails.

  begin
    l-link? 0= if drop false exit then
    l-emit?
  until

  l-data io!

  begin
    l-link? 0= if      false exit then
    l-key?
  until

  l-data io@
  true
;

: waitforlink ( -- connected )

  begin

    %0111010001010110111101011. \ Quake lights, but in binary: 10 FLUORESCENT FLICKER

    25 0 do
      over 1 and if bright else dark then
      dshr

      100 ms \ Normal timing for quake lights

      \ Add a bit randomness to timing because Ledcomm does not see the other device when both are in sync perfectly.
      \ Another solution is to have one device in bright mode the other in dark mode.

      random $7F and us

      l-link? if 2drop unloop true  exit then  \ Connection up and running

      buttons 1 6 lshift and 0<>
      esc? or if 2drop unloop false exit then  \ Pressed ESC or Menu

    loop
    2drop

  again
;

: chat ( -- ) \ Let humans have a conversation!
  cr
  stop \ Reset Ledcomm
  bright

  begin
    waitforlink
    if
      begin
        l-link? l-key? emit? and and if l-key highlight emit normal then
        l-link? key? l-emit? and and if   key dup l-emit normal emit then
        l-link? not
      until
    else
      stop exit
    then
  again
;

\ ------------------------------------------------------------------------------
\   Snake game in Forth
\ ------------------------------------------------------------------------------

: hello-snake ( -- )

  +lcd page

  cr
  highlight
  ."  --..,_                     _,.--.     " cr
  ."     `'.'.                .'`__ o  `;__." cr
  ."        '.'.            .'.'`  '---'`  `" cr
  ."   cjr    '.`'--....--'`.'              " cr
  ."            `'--....--'`                " cr
  normal
  cr
  cr

  ." Press " highlight ." A" normal ."  for one player" cr
  cr
  ." Press " highlight ." B" normal ."  for two players over Ledcomm" cr
  cr
 \ ." Insert a pair of identical round" cr
 \ ." red, orange or yellow" cr
 \ ." high-brightness LEDs" cr
 \ ." into your badges." cr
 \ cr
  highlight
  ." Anode:   Pmod pin 1 (P47)" cr
  ." Cathode: Pmod pin 2 (P48)" cr
  normal
  cr
  ." Press " highlight ." MENU" normal ."  to come back here" cr
;

\ ------------------------------------------------------------------------------
\   Snake appearance
\ ------------------------------------------------------------------------------

0 variable snake-x
0 variable snake-y
0 variable direction

64 constant maxlength
maxlength cells buffer: snakepos
0 variable head
0 variable tail

: xy>cell ( x y -- u ) 8 lshift or ;
: cell>xy ( u -- x y ) dup $FF and swap 8 rshift ;

: snakelength ( -- u ) head @ tail @ - maxlength 1- and ;

: printsnake ( -- )
  tail @
  begin
    dup cells snakepos + @ cell>xy 40 * + [char] o swap char!
    1+ maxlength 1- and
    dup head @ =
  until
  cells snakepos + @ cell>xy 40 * + [char] * swap char!
;

\ ------------------------------------------------------------------------------
\   Same for player two
\ ------------------------------------------------------------------------------

0 variable snake-x-two
0 variable snake-y-two
0 variable direction-two

maxlength cells buffer: snakepos-two
0 variable head-two
0 variable tail-two

: snakelength-two ( -- u ) head-two @ tail-two @ - maxlength 1- and ;

: printsnake-two ( -- )
  tail-two @
  begin
    dup cells snakepos-two + @ cell>xy 40 * + [char] o $80 or swap char!
    1+ maxlength 1- and
    dup head-two @ =
  until
  cells snakepos-two + @ cell>xy 40 * + [char] * $80 or swap char!
;

\ ------------------------------------------------------------------------------
\   Snake element movement
\ ------------------------------------------------------------------------------

: eat ( x y -- ) \ Let snake grow (up to maximum)

  snakelength maxlength 1- = if
  tail @ 1+ maxlength 1- and tail !
  then

  head @ 1+ maxlength 1- and head !
  xy>cell snakepos head @ cells + !
;

: crawl ( x y -- ) \ Let snake crawl by clipping tail before letting grow
  tail @ 1+ maxlength 1- and tail !
  eat
;

: collision ( x y -- flag ) \ Check for collision of x,y with current elements of snake
  xy>cell >r

  tail @
  begin
    dup cells snakepos + @ r@ = if drop rdrop true exit then
    1+ maxlength 1- and
    dup head @ =
  until
  drop rdrop false
;

\ ------------------------------------------------------------------------------
\   Snake element movement for player two
\ ------------------------------------------------------------------------------

: eat-two ( x y -- ) \ Let snake grow (up to maximum)

  snakelength-two maxlength 1- = if
  tail-two @ 1+ maxlength 1- and tail-two !
  then

  head-two @ 1+ maxlength 1- and head-two !
  xy>cell snakepos-two head-two @ cells + !
;

: crawl-two ( x y -- ) \ Let snake crawl by clipping tail before letting grow
  tail-two @ 1+ maxlength 1- and tail-two !
  eat-two
;

: collision-two ( x y -- flag ) \ Check for collision of x,y with current elements of snake
  xy>cell >r

  tail-two @
  begin
    dup cells snakepos-two + @ r@ = if drop rdrop true exit then
    1+ maxlength 1- and
    dup head-two @ =
  until
  drop rdrop false
;

\ ------------------------------------------------------------------------------
\   Pseudo random number generator so that both sides use the same values
\ ------------------------------------------------------------------------------

$BEEF variable seed

: prng ( -- x ) \ 16-bit xorshift PRNG
  seed @
  dup 7 lshift xor
  dup 9 rshift xor
  dup 8 lshift xor
  dup seed !
;

\ ------------------------------------------------------------------------------
\   Snake(s) love(s) food!
\ ------------------------------------------------------------------------------

0 variable apple-x
0 variable apple-y

: newapple ( -- )
  prng 40 um* nip apple-x !
  prng 30 um* nip apple-y !
;

\ ------------------------------------------------------------------------------
\   A little fun with colors
\ ------------------------------------------------------------------------------

: hue>rgb ( h -- r g b ) \ Hue values range from 0 to 511 and repeat.

  511 and 3 *

  dup 8 rshift
  case
    0 of          $FF and     255 swap   0 endof
    1 of $FF swap $FF and -        255   0 endof
    2 of          $FF and       0  255 rot endof
    3 of $FF swap $FF and -     0 swap 255 endof
    4 of          $FF and            0 255 endof
    5 of $FF swap $FF and -   255    0 rot endof
    drop 0 swap 0 swap 0 swap
  endcase
;

: hue ( h -- )
  hue>rgb
  \ Full RGB values are a it too bright, so adjust 8 bit RGB values to 16 bit values manually
  6 lshift pwm-blue io! 4 lshift pwm-green io! 5 lshift pwm-red io!
;

\ ------------------------------------------------------------------------------
\   Game logic
\ ------------------------------------------------------------------------------

0 variable time
0 variable multiplayer

: init-snakes ( -- )
  page

  0 snake-x !   0 snake-x-two !
  0 snake-y !   0 snake-y-two !

  3 head !      3 head-two !
  0 tail !      0 tail-two !

  snakepos     maxlength cells 0 fill
  snakepos-two maxlength cells 0 fill

  head     @ cells snakepos     + @ cell>xy snake-y     ! snake-x     !
  head-two @ cells snakepos-two + @ cell>xy snake-y-two ! snake-x-two !

  8 direction ! 8 direction-two !
  0 time !
  newapple
;

: game-loop ( -- )

  $BEEF seed !

  multiplayer @
  if
    cr cr cr ." Waiting for connection..."
    stop bright waitforlink 0= if stop exit then
  then

  -lcd init-snakes

  500 ms \ Get ready!

  begin
    \ Wait for end of screen update actvity
    waitretrace

    \ Now quickly clear character buffer and paint new snake.
    1200 begin 1- 32 over char! dup 0= until drop

                     printsnake
    multiplayer @ if printsnake-two then

    \ Paint apple.
    apple-x @ apple-y @ 40 * + [char] @ $80 or swap char!

    \ Scan buttons for own direction
    buttons  dup $F and ?dup if direction ! then
         1 6 lshift and if exit then \ Button "Menu"

    \ Exchange directions with the other player
    multiplayer @
    if
      direction @ l-exchange 0= if exit then direction-two !
      120 0 do cycles/ms delay-cycles l-link? 0= if unloop exit then loop
    else
      120 ms
    then

    direction @
    case
      8 of snake-x @ 1+ 39 umin snake-x ! endof
      1 of snake-y @ 1+ 29 umin snake-y ! endof
      4 of snake-x @ 1-  0  max snake-x ! endof
      2 of snake-y @ 1-  0  max snake-y ! endof
    endcase

    snake-x @ snake-y @
    2dup 2dup apple-x @ apple-y @ d=
    if eat newapple else crawl then
    collision

    multiplayer @
    if
      direction-two @
      case
        8 of snake-x-two @ 1+ 39 umin snake-x-two ! endof
        1 of snake-y-two @ 1+ 29 umin snake-y-two ! endof
        4 of snake-x-two @ 1-  0  max snake-x-two ! endof
        2 of snake-y-two @ 1-  0  max snake-y-two ! endof
      endcase

      snake-x-two @ snake-y-two @
      2dup 2dup apple-x @ apple-y @ d=
      if eat-two newapple else crawl-two then
      collision-two
      or
    then

    if init-snakes then \ In case of collision: Start new game.

    time @ 1+ dup hue time !
    prng drop \ Advance PRNG with time so that apples appear on different locations

  esc? until
;

: snake ( -- )
  dint lcd-init nocaption

  begin
    stop \ Switch off Ledcomm
    hello-snake \ Display welcome screen

    \ Wait for A or B (or both) being pressed
    begin
      esc? if exit then \ Stop if ESC is pressed on terminal
      buttons
      dup %10 9 lshift and 0<> multiplayer !  \ Button B
          %11 9 lshift and                    \ A or B
    until

    game-loop
  again
;

' snake init !
