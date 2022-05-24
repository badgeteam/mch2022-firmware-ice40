
\ -------------------------------------------------------------
\   Most positive and negative s15.16 values possible
\ -------------------------------------------------------------

$FFFF $7FFF 2constant +inf  \  32767,9999847412109375
$0000 $8000 2constant -inf  \ -32768,0000000000000000

\ -------------------------------------------------------------
\  Sine and Cosine with Cordic algorithm
\ -------------------------------------------------------------

hex
create numbertable
C90F , 76B1 , 3EB6 , 1FD5 , 0FFA , 07FF , 03FF , 01FF , 00FF , 007F , 003F , 001F , 000F , 0007 , 0003 , 0001 ,
decimal

: e^ka ( u -- x ) 2* numbertable + @ ; 1 foldable

\ -----------------------------------------------------------------------------
\   Common building blocks for different CORDIC modes
\ -----------------------------------------------------------------------------

0. 2variable cordic-x
0. 2variable cordic-y
0. 2variable cordic-z

: cordic-step-plus ( i -- ) >r
    cordic-x 2@ cordic-y 2@ r@ 2arshift d+
    cordic-y 2@ cordic-x 2@ r@ 2arshift d- cordic-y  2!
    cordic-z 2@             r> e^ka 0   d+ cordic-z  2!
                                           cordic-x  2!
;

: cordic-step-minus ( i -- ) >r
    cordic-x 2@ cordic-y 2@ r@ 2arshift d-
    cordic-y 2@ cordic-x 2@ r@ 2arshift d+ cordic-y  2!
    cordic-z 2@             r> e^ka 0   d- cordic-z  2!
                                           cordic-x  2!
;

\ -----------------------------------------------------------------------------
\   Angle --> Sine and Cosine
\ -----------------------------------------------------------------------------

: cordic-sincos ( f-angle -- f-cosine f-sine )
                ( Angle between -Pi/2 and +Pi/2 ! )

  $0,9B74      cordic-x 2! \ Scaling value to cancel gain of the algorithm
   0,0         cordic-y 2!
               cordic-z 2!

  0
  begin
    dup
    cordic-z @ 0< \ 2@ d0<
    if
      cordic-step-plus
    else
      cordic-step-minus
    then

    1+ dup 16 =
  until
  drop
;

: (sin) ( f-angle -- f-sine )   cordic-sincos cordic-y 2@ ; 2 foldable
: (cos) ( f-angle -- f-cosine ) cordic-sincos cordic-x 2@ ; 2 foldable

3,14159   2constant pi
pi 2,0 f/ 2constant pi/2
pi 4,0 f/ (cos) f. \ Displays cos(Pi/4)

: cos ( f-angle -- f-cosine )
  dabs
  pi/2 ud/mod drop 3 and ( Quadrant f-angle )

  case
    0 of                 (cos)         endof
    1 of dnegate pi/2 d+ (cos) dnegate endof
    2 of                 (cos) dnegate endof
    3 of dnegate pi/2 d+ (cos)         endof
  endcase

; 2 foldable

: sin ( f-angle -- f-sine )
  dup >r \ Save sign
  dabs
  pi/2 ud/mod drop 3 and ( Quadrant f-angle )

  case
    0 of                 (sin)          endof
    1 of dnegate pi/2 d+ (sin)          endof
    2 of                 (sin)  dnegate endof
    3 of dnegate pi/2 d+ (sin)  dnegate endof
  endcase

  r> 0< if dnegate then
; 2 foldable

: cossin ( f-angle -- f-cosine f-sine )
  dup >r \ Save sign
  dabs
  pi/2 ud/mod drop 3 and ( Quadrant f-angle )

  case
    0 of                 cordic-sincos cordic-x 2@         cordic-y 2@         endof
    1 of dnegate pi/2 d+ cordic-sincos cordic-x 2@ dnegate cordic-y 2@         endof
    2 of                 cordic-sincos cordic-x 2@ dnegate cordic-y 2@ dnegate endof
    3 of dnegate pi/2 d+ cordic-sincos cordic-x 2@         cordic-y 2@ dnegate endof
  endcase

  r> 0< if dnegate then
; 2 foldable

\ -----------------------------------------------------------------------------
\  Integer XY vector --> Polar coordinates
\ -----------------------------------------------------------------------------

: cordic-vectoring ( x y -- d-r f-angle )

  \ The CORDIC algorithm on its own works fine with angles between -Pi/2 ... +Pi/2.
  \ Need to handle angles beyond, which translates to if x < 0,  by an additional step:

  over 0<  \ x < 0 ?
  if
    negate swap negate swap

    dup 0< if \ Now y < 0 ?
      pi         cordic-z 2!
    else
      pi dnegate cordic-z 2!
    then
  else
    0,0  cordic-z 2!
  then

  \ Improve accuracy by exploiting 32 bit dynamic range during calculations

  s>d 12 2lshift cordic-y 2!
  s>d 12 2lshift cordic-x 2!

  0
  begin
    dup
    cordic-y @ 0< \ 2@ d0<
    if
      cordic-step-minus
    else
      cordic-step-plus
    then

    1+ dup 16 =
  until
  drop
;

: atan2     ( x y -- f-angle )             cordic-vectoring cordic-z 2@             ; 2 foldable
: xy>polar  ( x y -- f-angle d-magnitude ) atan2 cordic-x 2@ $0,9B74 f* 12 2arshift ; 2 foldable
: magnitude ( x y -- d-magnitude )         xy>polar 2nip                            ; 2 foldable

\ -------------------------------------------------------------
\  Square and root
\ -------------------------------------------------------------

: sqr ( f -- f^2 ) 2dup f* ; 2 foldable

: sqrt ( f -- sqrt ) ( L H )

  >r >r

  0,0

    2dup $0080 or      sqr   r> r@ over >r  du<= if $0080 or then
    2dup $0040 or      sqr   r> r@ over >r  du<= if $0040 or then
    2dup $0020 or      sqr   r> r@ over >r  du<= if $0020 or then
    2dup $0010 or      sqr   r> r@ over >r  du<= if $0010 or then

    2dup $0008 or      sqr   r> r@ over >r  du<= if $0008 or then
    2dup $0004 or      sqr   r> r@ over >r  du<= if $0004 or then
    2dup $0002 or      sqr   r> r@ over >r  du<= if $0002 or then
    2dup $0001 or      sqr   r> r@ over >r  du<= if $0001 or then

    over $8000 or over sqr   r> r@ over >r  du<= if swap $8000 or swap then
    over $4000 or over sqr   r> r@ over >r  du<= if swap $4000 or swap then
    over $2000 or over sqr   r> r@ over >r  du<= if swap $2000 or swap then
    over $1000 or over sqr   r> r@ over >r  du<= if swap $1000 or swap then

    over $0800 or over sqr   r> r@ over >r  du<= if swap $0800 or swap then
    over $0400 or over sqr   r> r@ over >r  du<= if swap $0400 or swap then
    over $0200 or over sqr   r> r@ over >r  du<= if swap $0200 or swap then
    over $0100 or over sqr   r> r@ over >r  du<= if swap $0100 or swap then

  rdrop rdrop
; 2 foldable

\ -------------------------------------------------------------
\  Exponential function
\ -------------------------------------------------------------

\ s31.32 comma parts of all but first coefficient in Horner expansion of
\ a partial sum of the series expansion of exp(x).  The whole parts are 0
\ and are supplied in code.

create exp-coef

$1745 , \  1/11
$1999 , \  1/10
$1C71 , \  1/9
$2000 , \  1/8
$24AD , \  1/7
$2AAA , \  1/6
$3333 , \  1/5
$4000 , \  1/4
$5555 , \  1/3
$8000 , \  1/2

: exp-1to1 ( x -- expx )
  \ Calculate exp(x) for x an s31.32 value.  Values are correct when
  \ when rounded to six decimal places when x is between +/-0.7.  Uses an
  \ 11-term partial sum evaluated using Horner's method.
  \ Calculate Horner terms
  1,0   \ Starting Horner term is 1
  10 0 do
    \ Multiply last term by x and coefficient, then add to get new term
    2over f* i   2* exp-coef + @     0 f* 0 1 d+
  loop
  \ Last part of expansion
  2over f* 0 1 d+
  2nip
; 2 foldable

$B172 $0000 2constant lnof2 \      0,6931457519531250

\ Return the floor of an s15.16 value df
: floor ( df -- df ) nip 0 swap ; 2 foldable

: pow2 ( x -- 2^x )
  \ Return 2 raised to the power x where x is s15.16
  \ If x is 0, return 1
  2dup 0,0 d= if 2drop 1,0 exit then
  \ If x < -16, 0 is returned.  If x >= 15, returns s15.16 ceiling
  2dup -16,0 d< if 2drop 0,0 exit then
  2dup 15,0 d< not if 2drop +inf exit then
  \ Get largest integer n such that n <= x so x = z + n, 0 <= z < 1
  2dup floor 2swap 2over d-
  ( n z )
  \ Get exp(z*ln2) = 2^z, then shift n times to get 2^x = (2^n)*(2^z)
  lnof2 f* exp-1to1 2swap nip
  ( 2^z n )  \ n now a single
  dup 0= if
    drop
  else
    dup 0< if
      negate 2rshift
    else
      2lshift
    then
  then
; 2 foldable

$7154 $0001 2constant 1overlnof2

: exp ( f -- exp ) \ exp(x) = pow2(x/ln(2))
  1overlnof2 f* pow2
; 2 foldable

\ -------------------------------------------------------------------------
\  Helper for logarithmic functions
\ -------------------------------------------------------------------------

: log2-1to2 ( y -- log2y )
  \ Helper function that requires y is s31.32 value with 1 <= y < 2
  0 0 2swap 0
  ( retval y cum_m )
  \ while((cum_m < 33) && (y > 1))
  begin dup 2over
    ( retval y cum_m cum_m y )
    1,0 d> swap 33 < and while
    ( retval y cum_m )
    rot rot 0 -rot        \ m = 0, z = y
    ( retval cum_m m z)
    \ Do z = z*z, m = m+1 until 2 <= z.  We also get z < 4
    begin
      2dup f* rot 1 + -rot
      ( retval cum_m m z )
      2dup 2,0 d< not
    until
    \ At this point z = y^(2^m) so that log2(y) = (2^(-m))*log2(z)
    \ = (2^(-m))*(1 + log2(z/2)) and 1 <= z/2 < 2
    \ We will add m to cum_m and add 2*(-cum_m) to the returned value,
    \ then iterate with a new y = z/2
    ( retval cum_m m z )
    2swap + -rot dshr >r >r   \ cum_m = cum_m + m, y = z/2
    ( retval cum_m ) ( R: y=z/2 )
    \ retval = retval + 2^-cum_m
    dup 1,0 rot 0 do dshr loop
    ( retval cum_m 2^-cum_m )
    rot >r d+
    ( retval ) ( R: y cum_m )
    r> r> r> rot
    ( retval y cum_m )
  repeat
  drop 2drop

; 2 foldable

\ -------------------------------------------------------------------------
\  Logarithmic functions
\ -------------------------------------------------------------------------

: log2 ( x -- log2x )
  \ Calculates base 2 logarithm of positive s15.16 value x

  \ Treat error and special cases
  \ Check that x > 0.  If not, return "minus infinity"
  2dup 0,0 d> not if 2drop -inf exit then
  \ If x = 1, return 0
  2dup 1,0 d= if 2drop 0,0 exit then

  \ Find the n such that 1 <= (2^(-n))*x < 2
  \ This n is the integer part (characteristic) of log2(x)
  0 -rot
  ( n=0 y=x )
  2dup 1,0 d> if
    \ Do n = n+1, y = y/2 while (y >= 2)
    begin 2dup 2,0 d< not while
      ( n y )
      dshr rot 1 + -rot
    repeat
  else
    \ Do n = n-1, y = 2*y while (y < 1)
    begin 2dup 1,0 d< while
      ( n y )
      d2* rot 1 - -rot
    repeat
  then

  \ Now y = (2^(-n))*x so log2(x) = n + log2(y) and we use the
  \ helper function to get log2(y) since 1 <= y < 2
  log2-1to2 rot 0 swap d+
  ( log2x )
; 2 foldable


: ln ( x -- lnx )
  \ Return the natural logarithm of a postive s15.16 value x
  log2 lnof2 f*
; 2 foldable

