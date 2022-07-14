
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
