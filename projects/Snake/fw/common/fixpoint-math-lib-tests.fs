
\ -----------------------------------------------------------------------------
\   Show a few arctangents
\ -----------------------------------------------------------------------------

  : p. xy>polar  d.  180,0 pi f/ f* f. cr ;
\ : p. atan2 180,0 pi f/ f* f. cr ;
\ : p. magnitude d. cr ;

 10000      0 p.  ( 0 )
 10000  10000 p.  ( 45 )
     0  10000 p.  ( 90 )
-10000  10000 p.  ( 135 )
-10000      0 p.  ( +-180 )
-10000 -10000 p.  ( -135 )
     0 -10000 p.  ( -90 )
 10000 -10000 p.  ( -45 )


 10   0 p.  ( 0 )
 10  10 p.  ( 45 )
  0  10 p.  ( 90 )
-10  10 p.  ( 135 )
-10   0 p.  ( +-180 )
-10 -10 p.  ( -135 )
  0 -10 p.  ( -90 )
 10 -10 p.  ( -45 )

\ -----------------------------------------------------------------------------
\   Accuracy testing
\   Save the output as atan2-test.dat, replace all commas with dots and check with Gnuplot:
\
\   Probed values:
\     plot "atan2-test.dat" u 1:2 w p
\   Results:
\     plot "atan2-test.dat" u 0:4 w l, "atan2-test.dat" u 0:(atan2($2, $1)/pi*180) w l
\     plot "atan2-test.dat" u 0:3 w l, "atan2-test.dat" u 0:(sqrt($2*$2 + $1*$1)) w l
\   Errors:
\     plot "atan2-test.dat" u 0:($4 - atan2($2, $1)/pi*180) w l
\     plot "atan2-test.dat" u 0:($3 - sqrt($2*$2 + $1*$1))  w l
\ -----------------------------------------------------------------------------

: atan2-test ( -- )
  cr cr

  100000 -100000 do  i  10000    2dup swap . .   p. 10 +loop
  100000 -100000 do  i -10000    2dup swap . .   p. 10 +loop

  100000 -100000 do     10000 i  2dup swap . .   p. 10 +loop
  100000 -100000 do    -10000 i  2dup swap . .   p. 10 +loop

  cr cr
;

\ -----------------------------------------------------------------------------
\   Test for Sine and Cosine
\ -----------------------------------------------------------------------------

: sincos-test ( -- )
  cr cr

  pi/2 dnegate
  begin
    2dup pi/2 d<
  while
    2dup f.
    2dup sin f.
    2dup cos f.
    cr
    1. d+
  repeat
  2drop
;

\ -----------------------------------------------------------------------------
\   Test for exponentials and logarithms
\ -----------------------------------------------------------------------------

: exp-test ( -- )
  cr cr

  -17,0
  begin
    2dup 17,0 d<
  while
    2dup f.
    2dup pow2 f.
    2dup exp  f.
    cr
    0,001 d+
  repeat
  2drop
;

: log-test ( -- )
  cr cr

  0,0
  begin
    2dup 1024,0 d<
  while
    2dup f.
    2dup log2 f.
    2dup ln  f.
    cr
    0,01 d+
  repeat
  2drop
;

\ -----------------------------------------------------------------------------
\   Test for square root
\ -----------------------------------------------------------------------------

: sqrt-test ( -- )
  cr cr

  0,0
  begin
    2dup 182,0,0 d<
  while
    2dup f.
    2dup sqr f.
    2dup sqr sqrt f.
    cr
    0,01 d+
  repeat
  2drop
;
