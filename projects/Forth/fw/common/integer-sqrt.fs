
: intsqrt ( u -- sqrt )
  >r
  0
    dup $0080 or dup * r@ u<= if $0080 or then
    dup $0040 or dup * r@ u<= if $0040 or then
    dup $0020 or dup * r@ u<= if $0020 or then
    dup $0010 or dup * r@ u<= if $0010 or then

    dup $0008 or dup * r@ u<= if $0008 or then
    dup $0004 or dup * r@ u<= if $0004 or then
    dup $0002 or dup * r@ u<= if $0002 or then
    dup $0001 or dup * r@ u<= if $0001 or then

  rdrop
; 1 foldable

