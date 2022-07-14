
\ -----------------------------------------------------------------------------
\   Test for Sinc
\ -----------------------------------------------------------------------------

: sinc-test ( -- )
  cr cr

  pi/2 8,0 f* dnegate


  begin
    2dup pi/2 2,0 f* dnegate d<
  while
    2dup f.
    2dup sinc f.
    cr
    0,001 d+
  repeat


  begin
    2dup pi/2 2,0 f* d<
  while
    2dup f.
    2dup sinc f.
    cr
    1. d+
  repeat


  begin
    2dup pi/2 8,0 f* d<
  while
    2dup f.
    2dup sinc f.
    cr
    1. d+
  repeat

  2drop
;

\ -----------------------------------------------------------------------------
\   Test for gaussian function
\ -----------------------------------------------------------------------------

: gaussian-test ( -- )
  cr cr

  -10,0
  begin
    2dup 10,0 d<
  while
    2dup f.
    2dup gaussian f.
    cr
    0,001 d+
  repeat
  2drop
;
