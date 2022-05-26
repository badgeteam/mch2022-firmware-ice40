

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

' interrupt 1 rshift $0002 ! \ Generate JMP opcode for vector location

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
