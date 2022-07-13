
dint -lcd new

\ ------------------------------------------------------------------------------
\   Snake game in Forth
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
\   Snake loves food!
\ ------------------------------------------------------------------------------

0 variable apple-x
0 variable apple-y

: newapple ( -- )
  random 40 um* nip apple-x !
  random 30 um* nip apple-y !
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

: init-snake ( -- )
  page
  0 snake-x !
  0 snake-y !

  3 head !
  0 tail !

  snakepos maxlength cells 0 fill
  newapple
  head @ cells snakepos + @ cell>xy snake-y ! snake-x !

  8 direction !
  0 time !
;

: snake ( -- )
  dint -lcd
  nocaption

  init-snake

  begin
    \ Wait for end of screen update actvity
    waitretrace

    \ Now quickly clear character buffer and paint new snake.
    1200 begin 1- 32 over char! dup 0= until drop
    printsnake

    \ Paint apple.
    apple-x @ apple-y @ 40 * + [char] @ $80 or swap char!

    buttons $F and ?dup if direction ! then

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

    collision if init-snake then

    time @ 1+ dup hue time !

    100 snakelength - ms
  esc? until
;

snake
