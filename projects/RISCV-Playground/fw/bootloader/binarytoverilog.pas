
// Number output helpers as Base cannot be changed in Pascal :-)

function byte2hex(zahl : byte) : string;
const
    hexa : array [0..15] of char = '0123456789ABCDEF';
begin
  byte2hex := hexa[zahl shr 4] + hexa[zahl and 15];
end;

function word2hex(zahl : word) : string;
begin
  word2hex := Byte2Hex((zahl and $FF00) shr 8) + Byte2Hex(zahl and $00FF);
end;

function dword2hex(zahl : dword) : string;
begin
  dword2hex := word2Hex((zahl and $FFFF0000) shr 16) + word2Hex(zahl and $0000FFFF);
end;


var eingabe : file of dword;
    ausgabe : text;
    schreiben : dword;
begin

  assign(eingabe, paramstr(1));
  reset(eingabe);

  assign(ausgabe, paramstr(2));
  rewrite(ausgabe);


  while not eof(eingabe) do
  begin
    read(eingabe, schreiben);
    writeln(ausgabe, dword2hex(schreiben));
  end;

  close(eingabe);
  close(ausgabe);

end.
