
\ -------------------------------------------------------------
\  Sinc using Cordic and Taylor for small values
\ -------------------------------------------------------------

: sinc ( f -- f )
  pi f* \ Normalised sinc function

  2dup dabs  0,25 pi f*  d<
  if   \ Taylor apprixomation for values close to zero
    \ 2dup f* 6,0 f/ dnegate 1,0 d+  \ For ranges up to +-0.09

    \ Better accuracy, ranges up to +-0.25
    sqr ( f^2 )
    2dup sqr ( f^2 f^4 )
    120,0 f/
    2swap 6,0 f/ dnegate d+
    1,0 d+
  else \ Direct calculation
    2dup sin 2swap f/
  then

;  2 foldable

\ -------------------------------------------------------------
\ Gaussian
\ -------------------------------------------------------------

1,0 2variable gauss-a
0,0 2variable gauss-b
2,0 2variable gauss-2c^2

: gaussian ( f -- f* )
  gauss-b 2@ d- sqr
  gauss-2c^2 2@ f/
  dnegate exp
  gauss-a 2@ f*

; 2 foldable

