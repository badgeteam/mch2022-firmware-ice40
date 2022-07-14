\ #######   MEMORY   ##########################################

: unused ( -- u ) $3000 here - ; \ 12 kb

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
