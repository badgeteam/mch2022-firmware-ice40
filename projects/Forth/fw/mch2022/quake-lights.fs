
: flicker-engine ( addr len -- ) \ Accepts string. 'a' for darkness, 'z' for maximum brightness.
  begin
    2dup bounds ?do
      i c@ [char] a - 2520 * pwm-red io! \ 65535/26 = 2520.8
      100 ms                              \ For 10 Hz update rate
    loop
  esc? until
  2drop
  0 pwm-red io!
;

: flicker ( u -- )
  case
    0 of s" m"                                                   endof \ 0 normal
    1 of s" mmnmmommommnonmmonqnmmo"                             endof \ 1 FLICKER (first variety)
    2 of s" abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba" endof \ 2 SLOW STRONG PULSE
    3 of s" mmmmmaaaaammmmmaaaaaabcdefgabcdefg"                  endof \ 3 CANDLE (first variety)
    4 of s" mamamamamama"                                        endof \ 4 FAST STROBE
    5 of s" jklmnopqrstuvwxyzyxwvutsrqponmlkj"                   endof \ 5 GENTLE PULSE 1
    6 of s" nmonqnmomnmomomno"                                   endof \ 6 FLICKER (second variety)
    7 of s" mmmaaaabcdefgmmmmaaaammmaamm"                        endof \ 7 CANDLE (second variety)
    8 of s" mmmaaammmaaammmabcdefaaaammmmabcdefmmmaaaa"          endof \ 8 CANDLE (third variety)
    9 of s" aaaaaaaazzzzzzzz"                                    endof \ 9 SLOW STROBE (fourth variety)
   10 of s" mmamammmmammamamaaamammma"                           endof \ 10 FLUORESCENT FLICKER
   11 of s" abcdefghijklmnopqrrqponmlkjihgfedcba"                endof \ 11 SLOW PULSE NOT FADE TO BLACK
      >r s" a" r>                                                      \ All others: Off.
  endcase
  flicker-engine
;
