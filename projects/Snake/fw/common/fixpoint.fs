
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
