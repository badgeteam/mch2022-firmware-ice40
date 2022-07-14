
\ -----------------------------------------------------------------------------
\   Usage gforth cross.fs <machine.fs> <program.fs>
\
\   Where machine.fs defines the target machine
\   and program.fs is the target program
\ -----------------------------------------------------------------------------
\
\   Based on Swapforth cross.fs by James Bowman
\   Modified and heavily commented by Matthias Koch
\
\ -----------------------------------------------------------------------------

variable lst \ Listing output file handle

\ -----------------------------------------------------------------------------
\  Allocate memory for the target dictionary residing in host memory space
\  with primitives for address translation.
\ -----------------------------------------------------------------------------

: tcell  ( -- cellsize ) 2 ;

: tbits  ( -- bits ) tcell 8 * ;
: tmask  ( -- mask ) 1 tbits lshift 1- ;
: tcells ( n -- n*cell ) tcell * ;
: tcell+ ( n -- n+cell ) tcell + ;

1024 32 * tcell * allocate throw constant tflash       \ Target flash image
1024 64 * tcell * allocate throw constant _tbranches   \ Branch targets, to simplify resolving control structures

tflash      1024 32 * tcell * erase
_tbranches  1024 64 * tcell * erase

: tbranches cells _tbranches + ;

variable tdp 0 tdp ! \ Target dictionary pointer: Current location to write into target image.

: org       tdp ! ;
: there    ( -- t-addr ) tdp @ ;

: tc!      ( c t-addr -- )  tflash + c! ;
: tc@      ( t-addr -- c )  tflash + c@ ;
: tw!      ( w t-addr -- )  tflash + w! ;
: tw@      ( t-addr -- w )  tflash + uw@ ;  \ Unsigned, as expected for 16 bit target memory contents.

: twalign  ( -- )   tdp @ tcell 1- + tcell negate and tdp ! ; \ Make target dictionary pointer even
: tc,      ( c -- ) there tc! 1 tdp +! ;     \ Add byte to target dictionary
: tw,      ( w -- ) there tw! tcell tdp +! ;  \ Add cell to target dictionary

\ -----------------------------------------------------------------------------
\  Create a new empty wordlist for crosscompilation tools in order
\  to not mix them with the tools available in the Gforth host.
\ -----------------------------------------------------------------------------

wordlist constant target-wordlist
: add-order ( wid -- ) >r get-order r> swap 1+ set-order ;
: :: get-current >r target-wordlist set-current : r> set-current ;

\ -----------------------------------------------------------------------------
\  Load the assembler source into the freshly prepared crosscompilation environment.
\ -----------------------------------------------------------------------------

next-arg included

\ -----------------------------------------------------------------------------
\  A few things in Gforth shall be available in the crosscompilation environment.
\  For example, ( comments ) are useful the same way in both environments.
\  Add them to the new wordlist.
\ -----------------------------------------------------------------------------

:: ( postpone ( ;
:: \ postpone \ ;

:: org          org ;
:: include      include ;
:: included     included ;
:: [if]         postpone [if] ;
:: [else]       postpone [else] ;
:: [then]       postpone [then] ;

\ -----------------------------------------------------------------------------
\  Efficiently generating opcode(s) for literals in target machine language.
\ -----------------------------------------------------------------------------

: literal ( w -- )
    dup $8000 and if
        invert recurse
        ~T alu
    else
        $8000 or tw,
    then
;

\ -----------------------------------------------------------------------------
\  Handling tail-call optimisation for opcodes at given address.
\ -----------------------------------------------------------------------------

: tail-call-optimisation ( opcode-addr -- ? )

    \ Check if the last opcode before ; was a call. This can be replaced by a jump opcode to give tail-call optimisation.
    dup tw@ $e000 and $4000 =
    if
        dup tw@ $1fff and over tw! \ Transform call opcode into jmp opcode.
        true
    else
    \ No, this wasn't a call opcode. Maybe an ALU opcode without return stack usage which we can add the necessary bits for ret to ?
        dup tw@ $e00c and $6000 = if
            dup tw@ $0080 or r-1 over tw!
            true
        else
            false
        then
    then
    nip
;

\ -----------------------------------------------------------------------------
\  Target Forth dictionary creation utilities.
\ -----------------------------------------------------------------------------

\  Take care.
\  There are two different, independent dictionary chains.
\  (1) The dictionary entries defined with the header-... macros are available in the final crosscompiled nucleus.
\  (2) The definitions done in the nucleus.fs source with the usual : are available in the host during crosscompilation.
\      There are a lot more named definitions in nucleus.fs than in the dictionaty chain of the final binary image.
\      Very useful in order to get named labels while processing the nucleus source whithout bloating the resulting binary !


\ These definitions are for building (1), the final dictionary available in the binary image

variable link 0 link !

:: header                ( -- ) twalign there   link @ 2 lshift      tw,   link !   bl parse  dup        tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-imm            ( -- ) twalign there   link @ 2 lshift      tw,   link !   bl parse  dup 128 or tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-imm-0-foldable ( -- ) twalign there   link @ 2 lshift 1 or tw,   link !   bl parse  dup 128 or tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-0-foldable     ( -- ) twalign there   link @ 2 lshift 1 or tw,   link !   bl parse  dup        tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-1-foldable     ( -- ) twalign there   link @ 2 lshift 2 or tw,   link !   bl parse  dup        tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-2-foldable     ( -- ) twalign there   link @ 2 lshift 3 or tw,   link !   bl parse  dup        tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-3-foldable     ( -- ) twalign there   link @ 2 lshift 4 or tw,   link !   bl parse  dup        tc,  bounds do  i c@ tc,  loop  twalign  ;
:: header-4-foldable     ( -- ) twalign there   link @ 2 lshift 5 or tw,   link !   bl parse  dup        tc,  bounds do  i c@ tc,  loop  twalign  ;

\ The following definitions are for building (2), the named labels available only during crosscompilation

\ -----------------------------------------------------------------------------
\  The crosscompiler.
\  This is basically giving the assembler the look and feel of Forth.
\ -----------------------------------------------------------------------------

\ Scan ahead in the input line in order to parse the next word without removing it from the input buffer.
\ Just for pretty listing file printing, nothing special happens here.
: wordstr ( "name" -- c-addr u ) >in @ >r bl word count r> >in ! ;

variable wordstart

\ Remember: The current wordlist does not include : but :: which allows to add new host-side definitions into the crosscompilation environment.
\ Now add : for the crosscompiler. This allows the "assembler" to use Forth syntax !

:: : ( "name" -- )
    \ This is just to create a nicely formated listing file.
    hex there s>d <# bl hold # # # # #> lst @ write-file throw wordstr lst @ write-line throw

    \ Real work is done here:
    there wordstart !
    create  tdp @ tcell / ,  \ Current target dictionary pointer is prepared for use as call destination
    does>   @ scall          \ When the resulting definition in the crosscompilation environment is executed, it writes a call opcode into the binary image.
;

:: :noname   ( -- ) ; \ This is doing nothing. Just syntactical sugar for the human in order to have a matching pair for ;
:: ;fallthru ( -- ) ; \ Syntactical sugar, too.

:: , ( w -- ) twalign tw, ; \ Add a word to target dictionary, this time visible from within the crosscompilation environment.

:: allot ( u -- ) 0 ?do 0 tc, loop ; \ "Allot" space in the target dictionary by filling in zeros.

:: ;
    tdp @ wordstart @ =
    if
      \ Handle empty definitions without emitting any code into the binary.
      s" exit" evaluate
    else
      \ Check the last opcode in this definition. Tail-call optimisation possible ?
        tdp @ tcell - tail-call-optimisation \ Gives true if optimisation was successful.

      \ Check if there is any control flow to this location. Maybe their opcodes can be tail-call opitimised, too.
        tdp @ 0 do
            i tbranches @ tdp @ = if
                i tbranches @ tail-call-optimisation and
            then
        loop

        0= if s" exit" evaluate then \ Not all tail-call optimisations for this location were fine.
    then
;

\ -----------------------------------------------------------------------------
\  Code generator tools
\ -----------------------------------------------------------------------------

:: jmp ( "name" -- ) ' >body @ ubranch ;  \ Add        jump opcode to destination label
:: jz  ( "name" -- ) ' >body @ 0branch ;  \ Add conditional opcode to destination label

\ Create allows the creation of named memory locations.
\ They are named in host only during crosscompilation.
\ For target usage, they just write a literal into the binary image.

:: create ( "name" -- ) twalign create there , does> @ literal ;

\ The idea of inline: is to parse the next definition, which needs to be a single opcode routine,
\ and to append that opcode to the target dictionary when executed.

:: inline: ( "name" -- )
    parse-name evaluate
    tdp @ tcell - >r
    r@ tw@ $8000 or r> tw!
    s" w," evaluate
;

\ Replaces the variable with an inline fetch using a high-call. Usage "<variable> @i"

:: @i ( addr -- x ) \ Effect similar to @ on final execution ( -- ) on compilation.
    tdp @ tcell - >r                   \ Get last opcode, which should be a literal
    r@ tw@ $4000 or r> tw!              \ and prepare the address for a high-call.
    $000E 1 rshift $4000 or tw,          \ Insert a call to execute, which is close to the beginning of the nucleus. We cannot tick target definitions at this stage.
;

\ Generates a call to the next location. The following part of the definition is thus executed twice.

:: DOUBLE ( -- ) tdp @ tcell / 1+ scall ;

\ -----------------------------------------------------------------------------
\  Wordlist juggling tools to properly switch into and out of the crosscompilation environment.
\ -----------------------------------------------------------------------------

: target    only target-wordlist add-order definitions ;
: ]         target ;
:: meta     forth definitions ;
:: [        forth definitions ;

: t' ( -- t-addr ) bl parse target-wordlist search-wordlist 0= throw >body @ ; \ Tick for target definitions

\ -----------------------------------------------------------------------------
\  Numbers in crosscompilation environment.
\  Unfortunately, it isn't easily possible to rewire the host's number parsing capabilities...
\  Therefore, all numbers for target usage need to be prefixed with an ugly d# or h#
\ -----------------------------------------------------------------------------

: sign>number   ( c-addr1 u1 -- ud2 c-addr2 u2 )
    0. 2swap
    over c@ [char] - = if
        1 /string
        >number
        2swap dnegate 2swap
    else
        >number
    then
;

: base>number   ( caddr u base -- )
    base @ >r base !
    sign>number
    r> base !
    dup 0= if
        2drop drop literal
    else
        1 = swap c@ [char] . = and if
            drop dup literal 16 rshift literal
        else
            -1 abort" Bad number."
        then
    then ;

\ Stack effects for these are "final effects", actually they are writing literal opcodes.

:: d#     ( -- x )    bl parse 10 base>number ;
:: h#     ( -- x )    bl parse 16 base>number ;
:: [']    ( -- addr ) ' >body @ tcell * literal ;
:: [char] ( -- c )    char literal ;

\ -----------------------------------------------------------------------------
\  Control structures for the crosscompiler.
\  This is much more comfortable than using labels and jumps manually.
\ -----------------------------------------------------------------------------

: resolve ( orig -- )
    tdp @ over tbranches ! \ Forward reference from orig to this location
    dup tw@ tdp @ tcell / or swap tw!
;

:: if      tdp @ 0 0branch ;
:: then    resolve ;
:: else    tdp @ 0 ubranch swap resolve ;
:: begin   tdp @ ;
:: again   tcell / ubranch ;
:: until   tcell / 0branch ;
:: while   tdp @ 0 0branch ;
:: repeat  swap tcell / ubranch resolve ;

\ -----------------------------------------------------------------------------
\  A little mess just for handling output file names.
\  Quite unimportant for understanding the crosscompiler.
\ -----------------------------------------------------------------------------

: .trim ( a-addr u ) \ shorten string until it ends with '.'
    begin
        2dup + 1- c@ [char] . <>
    while
        1-
    repeat
;

( Strings                                    JCB 11:57 05/18/12)

: >str ( c-addr u -- str ) \ a new u char string from c-addr
    dup cell+ allocate throw dup >r
    2dup ! cell+    \ write size into first cell
                    ( c-addr u saddr )
    swap cmove r>
;
: str@  dup cell+ swap @ ;
: str! ( str c-addr -- c-addr' ) \ copy str to c-addr
    >r str@ r>
    2dup + >r swap
    cmove r>
;
: +str ( str2 str1 -- str3 )
    over @ over @ + cell+ allocate throw >r
    over @ over @ + r@ !
    r@ cell+ str! str! drop r>
;

: example
    s"  sailor" >str
    s" hello" >str
    +str str@ type
;

next-arg 2dup .trim >str constant prefix.
: .suffix  ( c-addr u -- c-addr u ) \ e.g. "bar" -> "foo.bar"
    >str prefix. +str str@
;
: create-output-file w/o create-file throw ;
: out-suffix ( s -- h ) \ Create an output file h with suffix s
    >str
    prefix. +str
    s" build/" >str +str str@
    create-output-file
;

: prepare-listing ( -- )
    s" lst" out-suffix lst !
;

\ -----------------------------------------------------------------------------
\  Finally, load the source file which shall be crosscompiled.
\ -----------------------------------------------------------------------------

prepare-listing

tcell org

variable insertquit \ This is a hack to backpatch the address of quit.

target included      \ Include the source file of the nucleus to be crosscompiled

[ tdp @ 0 org ] jmp main [ org ]
[ tdp @ insertquit @ org ] jmp quit [ org ]

meta

\ -----------------------------------------------------------------------------
\  Crosscompilation done. Write target binary image to file.
\ -----------------------------------------------------------------------------

decimal

0 value file

: dumpall
    s" hex" out-suffix to file

    hex
    8192 0 do
        i tcell * tw@
        s>d <# tcell 2* 0 do # loop #> file write-line throw
    loop
    file close-file
;

dumpall

cr ." Target memory usage: " tdp @ . ." Bytes" cr

bye
