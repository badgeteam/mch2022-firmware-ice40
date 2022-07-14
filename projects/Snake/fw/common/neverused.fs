
\ Traverse dictionary, scan whole memory for jumps and calls for current definition, and if none found:
\ Give these out as list of never used definitions.
\ By design, this will not show definitions that unconditionally jump back to their own first opcode.

: neverused ( -- )
  cr
  forth @
  begin
    dup
  while

    dup cell+ count 127 and + aligned ( Link Codestart ) 2/

    false ( Link Codestart Flag )

    here unused + 2/ $0000 do
                  over ( $0000 or ) i 2* @ = ( dup if ." JMP  " then ) or
                  over   $4000 or   i 2* @ = ( dup if ." Call " then ) or
                loop

    nip

    0= if dup cell+ count 127 and type cr then

    link@
  repeat
  drop
;

