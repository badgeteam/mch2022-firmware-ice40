
\ -------------------------------------------------------------
\  Interface to real graphics hardware necessary.
\  This is just for ASCII art in terminal !
\ -------------------------------------------------------------

  : u.base10 ( u -- ) base @ decimal swap 0 <# #s #> type base ! ;
  : ESC[ ( -- ) 27 emit 91 emit ;
  : at-xy ( column row -- ) 1+ swap 1+ swap ESC[ u.base10 ." ;" u.base10 ." H" ;
  : page ESC[ ." 2J" 0 0 at-xy ;

: putpixel ( x y -- )  at-xy [char] * emit ;


\ -------------------------------------------------------------
\  Bresenham line
\ -------------------------------------------------------------

0 variable line-x1   0 variable line-y1
0 variable line-sx   0 variable line-sy
0 variable line-dx   0 variable line-dy
0 variable line-err

: line ( x0 y0 x1 y1 -- )

  line-y1 ! line-x1 !

  over line-x1 @ -   dup 0< if 1 else -1 then line-sx !   abs        line-dx !
  dup  line-y1 @ -   dup 0< if 1 else -1 then line-sy !   abs negate line-dy !
  line-dx @ line-dy @ + line-err !

  begin
    2dup putpixel
    2dup line-x1 @ line-y1 @ d<>
  while
    line-err @ 2* >r
    r@ line-dy @ > if line-dy @ line-err +! swap line-sx @ + swap then
    r> line-dx @ < if line-dx @ line-err +!      line-sy @ +      then
  repeat
  2drop
;

\ -------------------------------------------------------------
\ Artwork for 8x8 Bitmap Font, taken mostly from Commodore C64
\ -------------------------------------------------------------

hex
create font

0000 , 0000 , 0000 , 0000 ,  \ 32: Space
1818 , 1818 , 0000 , 0018 ,  \ 33 !
6666 , 0066 , 0000 , 0000 ,  \ 34 "
6666 , 66FF , 66FF , 0066 ,  \ 35 #
3E18 , 3C60 , 7C06 , 0018 ,  \ 36 $
6662 , 180C , 6630 , 0046 ,  \ 37 %
663C , 383C , 6667 , 003F ,  \ 38 &
1818 , 0018 , 0000 , 0000 ,  \ 39 '  (*)
180C , 3030 , 1830 , 000C ,  \ 40 (
1830 , 0C0C , 180C , 0030 ,  \ 41 )
6600 , FF3C , 663C , 0000 ,  \ 42 *
1800 , 7E18 , 1818 , 0000 ,  \ 43 +
0000 , 0000 , 1800 , 3018 ,  \ 44 ,
0000 , 7E00 , 0000 , 0000 ,  \ 45 -
0000 , 0000 , 1800 , 0018 ,  \ 46 .
0300 , 0C06 , 3018 , 0060 ,  \ 47 /
663C , 766E , 6666 , 003C ,  \ 48 0
1818 , 1838 , 1818 , 007E ,  \ 49 1
663C , 0C06 , 6030 , 007E ,  \ 50 2
663C , 1C06 , 6606 , 003C ,  \ 51 3
0E06 , 661E , 067F , 0006 ,  \ 52 4
607E , 067C , 6606 , 003C ,  \ 53 5
663C , 7C60 , 6666 , 003C ,  \ 54 6
667E , 180C , 1818 , 0018 ,  \ 55 7
663C , 3C66 , 6666 , 003C ,  \ 56 8
663C , 3E66 , 6606 , 003C ,  \ 57 9
0000 , 0018 , 1800 , 0000 ,  \ 58 :
0000 , 0018 , 1800 , 3018 ,  \ 59 ;
180E , 6030 , 1830 , 000E ,  \ 60 <
0000 , 007E , 007E , 0000 ,  \ 61 =
1870 , 060C , 180C , 0070 ,  \ 62 >
663C , 0C06 , 0018 , 0018 ,  \ 63 ?

663C , 6E6E , 6260 , 003C ,  \ 64 @
3C18 , 7E66 , 6666 , 0066 ,  \ 65 A
667C , 7C66 , 6666 , 007C ,  \ 66 B
663C , 6060 , 6660 , 003C ,  \ 67 C
6C78 , 6666 , 6C66 , 0078 ,  \ 68 D
607E , 7860 , 6060 , 007E ,  \ 69 E
607E , 7860 , 6060 , 0060 ,  \ 70 F
663C , 6E60 , 6666 , 003C ,  \ 71 G
6666 , 7E66 , 6666 , 0066 ,  \ 72 H
183C , 1818 , 1818 , 003C ,  \ 73 I
0C1E , 0C0C , 6C0C , 0038 ,  \ 74 J
6C66 , 7078 , 6C78 , 0066 ,  \ 75 K
6060 , 6060 , 6060 , 007E ,  \ 76 L
7763 , 6B7F , 6363 , 0063 ,  \ 77 M
7666 , 7E7E , 666E , 0066 ,  \ 78 N
663C , 6666 , 6666 , 003C ,  \ 79 O
667C , 7C66 , 6060 , 0060 ,  \ 80 P
663C , 6666 , 3C66 , 000E ,  \ 81 Q
667C , 7C66 , 6C78 , 0066 ,  \ 82 R
663C , 3C60 , 6606 , 003C ,  \ 83 S
187E , 1818 , 1818 , 0018 ,  \ 84 T
6666 , 6666 , 6666 , 003C ,  \ 85 U
6666 , 6666 , 3C66 , 0018 ,  \ 86 V
6363 , 6B63 , 777F , 0063 ,  \ 87 W
6666 , 183C , 663C , 0066 ,  \ 88 X
6666 , 3C66 , 1818 , 0018 ,  \ 89 Y
067E , 180C , 6030 , 007E ,  \ 90 Z
303C , 3030 , 3030 , 003C ,  \ 91 [
6000 , 1830 , 060C , 0003 ,  \ 92 \  (*)
0C3C , 0C0C , 0C0C , 003C ,  \ 93 ]
1C08 , 0063 , 0000 , 0000 ,  \ 94 ^  (*)
0000 , 0000 , 0000 , 00FF ,  \ 95 _

1818 , 000C , 0000 , 0000 ,  \ 96  ` (*)
0000 , 063C , 663E , 003E ,  \ 97  a
6000 , 7C60 , 6666 , 007C ,  \ 98  b
0000 , 603C , 6060 , 003C ,  \ 99  c
0600 , 3E06 , 6666 , 003E ,  \ 100 d
0000 , 663C , 607E , 003C ,  \ 101 e
0E00 , 3E18 , 1818 , 0018 ,  \ 102 f
0000 , 663E , 3E66 , 7C06 ,  \ 103 g
6000 , 7C60 , 6666 , 0066 ,  \ 104 h
1800 , 3800 , 1818 , 003C ,  \ 105 i
0600 , 0600 , 0606 , 3C06 ,  \ 106 j
6000 , 6C60 , 6C78 , 0066 ,  \ 107 k
3800 , 1818 , 1818 , 003C ,  \ 108 l
0000 , 7F66 , 6B7F , 0063 ,  \ 109 m
0000 , 667C , 6666 , 0066 ,  \ 110 n
0000 , 663C , 6666 , 003C ,  \ 111 o
0000 , 667C , 7C66 , 6060 ,  \ 112 p
0000 , 663E , 3E66 , 0606 ,  \ 113 q
0000 , 667C , 6060 , 0060 ,  \ 114 r
0000 , 603E , 063C , 007C ,  \ 115 s
1800 , 187E , 1818 , 000E ,  \ 116 t
0000 , 6666 , 6666 , 003E ,  \ 117 u
0000 , 6666 , 3C66 , 0018 ,  \ 118 v
0000 , 6B63 , 3E7F , 0036 ,  \ 119 w
0000 , 3C66 , 3C18 , 0066 ,  \ 120 x
0000 , 6666 , 3E66 , 780C ,  \ 121 y
0000 , 0C7E , 3018 , 007E ,  \ 122 z
180E , 7018 , 1818 , 000E ,  \ 123 {  (*)
1818 , 1818 , 1818 , 1818 ,  \ 124 |  (*)
1870 , 0E18 , 1818 , 0070 ,  \ 125 }  (*)
0000 , 6E3B , 0000 , 0000 ,  \ 126 ~  (*)
FFFF , FFFF , FFFF , FFFF ,  \ 127 DEL

decimal

: ascii>bitpattern ( c -- c-addr ) \ Translates ASCII to address of bitpatterns.
  32 umax 127 umin
  32 - 8 * font +
; 1 foldable

\ -------------------------------------------------------------
\  Write a string with 8x8 bitmap font of the Commodore 64
\ -------------------------------------------------------------

0 variable font-x   0 variable font-y

: drawbytepattern ( c -- )
  8 0 do dup 128 and if font-x @ font-y @ putpixel then 2* 1 font-x +! loop
  drop -8 font-x +!
;

: drawcharacterbitmap ( c-addr -- )
  8 0 do dup c@ drawbytepattern 1 font-y +! 1+ loop
  drop -8 font-y +! 8 font-x +!
;

: get-first-char ( addr len -- addr   len c ) over c@ ;
: cut-first-char ( addr len -- addr+1 len-1 ) 1- swap 1+ swap ;

: drawstring ( addr u x y -- )
  font-y ! font-x !

  begin
    dup 0<>
  while \ Adjust the following code to add your own unicode characters.
    get-first-char ascii>bitpattern drawcharacterbitmap cut-first-char
  repeat
  2drop
;

\ -------------------------------------------------------------
\  A small graphics demo
\ -------------------------------------------------------------

: demo ( -- )
  page

\   0  0  5 95 line
\   5  0 10 95 line
\
\  85  0 90 95 line
\  90  0 95 95 line

  s"    _"         8  0 drawstring
  s"   ^-)"        8  8 drawstring
  s"    (.._"      8 16 drawstring
  s"     \`\\"     8 24 drawstring
  s"      |>"      8 32 drawstring
  s" ____/|____"   8 40 drawstring

  s" Mecrisp"     16 48 drawstring
;
