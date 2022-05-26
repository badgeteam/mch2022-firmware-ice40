( J1 base words implemented in assembler     JCB 17:27 12/31/11)

: T          $0000 ;
: N          $0100 ;
: T+N        $0200 ;
: T&N        $0300 ;
: T|N        $0400 ;
: T^N        $0500 ;
: ~T         $0600 ;
: N==T       $0700 ;
: N<T        $0800 ;
: T2/        $0900 ;
: T2*        $0a00 ;
: rT         $0b00 ;
: N-T        $0c00 ;
: io[T]      $0d00 ;
: status     $0e00 ;
: Nu<T       $0f00 ;

\ Specials for HX8K

: NlshiftT   $1000 ;
: NrshiftT   $1100 ;
: NarshiftT  $1200 ;
: rstatus    $1300 ;

: L-UM*      $1400 ;
: H-UM*      $1500 ;
: T+1        $1600 ;
: T-1        $1700 ;

: 3OS        $1800 ;


: T->N       $0010 or ;
: T->R       $0020 or ;
: N->[T]     $0030 or ;
: N->io[T]   $0040 or ;
: IORD       $0050 or ;
: fDINT      $0060 or ;
: fEINT      $0070 or ;
: RET        $0080 or ;

: d-2        $0002 or ;
: d-1        $0003 or ;
: d+1        $0001 or ;
: r-1        $000c or ;
: r+1        $0004 or ;

: imm        $8000 or tw, ;
: alu        $6000 or tw, ;
: ubranch    $0000 or tw, ;
: 0branch    $2000 or tw, ;
: scall      $4000 or tw, ;

:: noop      T                       alu ;
:: +         T+N                 d-1 alu ;
:: -         N-T                 d-1 alu ;
:: xor       T^N                 d-1 alu ;
:: and       T&N                 d-1 alu ;
:: or        T|N                 d-1 alu ;
:: invert    ~T                      alu ;
:: =         N==T                d-1 alu ;
:: <         N<T                 d-1 alu ;
:: u<        Nu<T                d-1 alu ;
:: swap      N     T->N              alu ;
:: dup       T     T->N          d+1 alu ;
:: drop      N                   d-1 alu ;
:: over      N     T->N          d+1 alu ;
:: nip       T                   d-1 alu ;
:: >r        N     T->R      r+1 d-1 alu ;
:: r>        rT    T->N      r-1 d+1 alu ;
:: r@        rT    T->N          d+1 alu ;
:: io@       io[T] IORD              alu ;
:: !         3OS   N->[T]        d-2 alu ;
:: io!       3OS   N->io[T]      d-2 alu ;
:: 2/        T2/                     alu ;
:: 2*        T2*                     alu ;
:: depth     status T->N         d+1 alu ;
:: exit      T  RET              r-1 alu ;

:: dint      T     fDINT             alu ;
:: eint      T     fEINT             alu ;

\ Specials for HX8K

:: lshift    NlshiftT            d-1 alu ;
:: rshift    NrshiftT            d-1 alu ;
:: arshift   NarshiftT           d-1 alu ;
:: rdepth    rstatus T->N        d+1 alu ;

:: um*low    L-UM*               d-1 alu ;
:: um*high   H-UM*               d-1 alu ;
:: 1+        T+1                     alu ;
:: 1-        T-1                     alu ;

\ Elided words
\ These words are supported by the hardware but are not
\ part of ANS Forth.  They are named after the word-pair
\ that matches their effect
\ Using these elided words instead of
\ the pair saves one cycle and one instruction.

:: 2dupand   T&N   T->N          d+1 alu ;
:: 2dup<     N<T   T->N          d+1 alu ;
:: 2dup=     N==T  T->N          d+1 alu ;
:: 2dupor    T|N   T->N          d+1 alu ;
:: 2dup+     T+N   T->N          d+1 alu ;
:: 2dup-     N-T   T->N          d+1 alu ;
:: 2dupu<    Nu<T  T->N          d+1 alu ;
:: 2dupxor   T^N   T->N          d+1 alu ;
:: dup>r     T     T->R      r+1     alu ;
:: overand   T&N                     alu ;
:: over>     N<T                     alu ;
:: over=     N==T                    alu ;
:: overor    T|N                     alu ;
:: over+     T+N                     alu ;
:: overu>    Nu<T                    alu ;
:: overxor   T^N                     alu ;
:: rdrop     T                   r-1 alu ;
:: tuck!     T     N->[T]        d-1 alu ;
:: tuckio!   T     N->io[T]      d-1 alu ;
:: 2dup!     T     N->[T]            alu ;
:: 2dupio!   T     N->io[T]          alu ;

:: dropdup   N                       alu ;
:: dropr@    rT                      alu ;
:: dropr>    rT              r-1     alu ;
:: droprdrop N               r-1 d-1 alu ;
:: niprdrop  T               r-1 d-1 alu ;

:: !r>       rT    N->[T]    r-1 d-1 alu ;
:: io!r>     rT    N->io[T]  r-1 d-1 alu ;

:: 2drop     3OS                 d-2 alu ;
:: 2droprdrop 3OS            r-1 d-2 alu ;
:: 3rd       3OS   T->N          d+1 alu ;

\ Specials for HX8K

:: dup1+     T+1   T->N          d+1 alu ;
:: dup>r1+   T+1   T->R      r+1     alu ;
:: tuck!1+   T+1   N->[T]        d-1 alu ;
:: 2dupum*low  L-UM* T->N        d+1 alu ;
:: 2dupum*high H-UM* T->N        d+1 alu ;

:: overswaplshift    NlshiftT        alu ;
:: overswaprshift    NrshiftT        alu ;
:: overswaparshift   NarshiftT       alu ;
