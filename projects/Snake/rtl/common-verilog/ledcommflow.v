
// Ledcomm protocol (with flow control) implemented in logic as drop-in replacement for UART

`default_nettype none

module ledcommflow(

  output reg Anode_OUT,
  input wire Kathode_IN,
  output reg Kathode_OUT,
  output reg Kathode_DIR,

  input clk,
  input resetq,

  input  wr,
  input  rd,
  input  [15:0] tx_data,
  output [15:0] rx_data,
  output busy,
  output valid,

  output Verbindungbesteht, // Haben wir gerade eine funktionierende Verbindung ?

  input  Dunkelheit,        // Wenn das Bit gesetzt ist, wird im Dunkelen gewartet,
                            // ansonsten werden helle Synchronisationspulse abgestrahlt.
  input [15:0] Basiszeit,   // Zahl der Taktzyklen für eine Basiszeit
  input [15:0] Ladezeit     // Zahl der Taktzyklen fürs Laden der Kathode
);


  // ######   Ledcomm-Protokoll   #############################

  reg  [15:0] Taktteiler;
  wire [15:0] TaktteilerN = Taktteiler + 1;

  reg  [5:0] Strahlzaehler;
  reg  [5:0] Lauschzaehler;

  reg [15:0] Lichtmuster;
  reg [15:0] Sendedaten;
  reg [15:0] Datenregister;

  reg  [5:0] Verbindungsdauer;

  localparam Empfangspufferbits    = 2;  // Minimum: 2 Bits.
  localparam Empfangspufferzeichen = 2**Empfangspufferbits;

  reg [15:0] empfangenes [Empfangspufferzeichen-1:0];

  reg  [Empfangspufferbits-1:0] lesezeiger;
  reg  [Empfangspufferbits-1:0] schreibzeiger;

  assign valid = ~(lesezeiger == schreibzeiger);
  wire drosselung_beantragen = (schreibzeiger - lesezeiger) >= Empfangspufferzeichen - 2; // Bitte um Pause, wenn nur noch für zwei Elemente Platz ist.

  assign rx_data = empfangenes[lesezeiger];

  reg EtwasVersenden;
  reg [15:0] Ausgehendes;

  assign busy = EtwasVersenden | ~Verbindungbesteht;

  wire  [5:0] StrahlzaehlerN = Strahlzaehler - 1;
  wire  [5:0] LauschzaehlerN = Lauschzaehler - 1;
  wire [16:0] LichtmusterN = {Lichtmuster, ~Kathode_IN}; // Nächstes Helligkeitsbit entgegen nehmen

  reg Wartebitte;
  reg Sendepause;

  assign Verbindungbesteht = Verbindungsdauer >= 18; // Verbindung besteht erst nach 18 mal Zublinkern stabil.

  always @(posedge clk)
  if (!resetq)
  begin
    Taktteiler <= 0;

    Strahlzaehler <= 0;
    Lauschzaehler <= 0;

    Lichtmuster <= 0;
    Sendedaten <= 0;
    Datenregister <= 0;

    Verbindungsdauer <= 0;

    lesezeiger <= 0;
    schreibzeiger <= 0;

    EtwasVersenden <= 0;

    Sendepause <= 0;
    Wartebitte <= 0;

    {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b100; // Beide Pins: Ausgang Low
  end
  else
  begin

    if (rd) lesezeiger <= lesezeiger + 1;

    if (wr)
    begin
      Ausgehendes <= tx_data;
      EtwasVersenden <= 1;
    end

    Taktteiler <= (TaktteilerN < Basiszeit) ? TaktteilerN : 0; // Zählt von 0 bis Basiszeit - 1

    if ((Taktteiler != 0) & (Taktteiler == Ladezeit) & ( {Kathode_DIR, Kathode_OUT, Anode_OUT } == 3'b110 )) // Wird gerade geladen ?
                                                         {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b010; // Entladung kann 1 us später beginnen.

    if (Taktteiler == 0)
    begin // Tick mit Basiszeit

      if (Strahlzaehler != 0)
      begin
        Strahlzaehler <= StrahlzaehlerN;

        if (StrahlzaehlerN == 0)
        begin
          {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b110; // Umgekehrt laden
          Lauschzaehler <= 32;
          Wartebitte    <= drosselung_beantragen;
        end
        else {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b101; // Leuchten lassen !

      end
      else
      begin
        Lichtmuster <= LichtmusterN[15:0]; // Nächstes Helligkeitsbit entgegen nehmen

        if (Lauschzaehler == 28) Sendepause <= ~Lichtmuster[0]; // Die Wartebitte-Pause wird hier erkannt und berücksichtigt.
        // Lichtmuster[0]: 29, 28, 27, 26. Bei 30 und 25 geht es schief.

        if (Wartebitte ? LichtmusterN[8:0] == 9'b11100_0000 : LichtmusterN[4:0] == 5'b11100) // Ankommender Puls erkannt
        begin
          {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b101; // Leuchten lassen !
          if (~Verbindungbesteht) Verbindungsdauer <= Verbindungsdauer + 1;

          // Nächsten ausgehenden Puls vorbereiten

          if (~Verbindungbesteht) Strahlzaehler <= 8; // Solange noch keine Verbindung besteht, Null-Pulse versenden.
          else // Verbindung besteht. Daten senden.
          begin

            if (Sendedaten != 0)
            begin // An bestehender Übertragung weiterarbeiten
              if (Sendedaten == 16'b1000_0000_0000_0000) Strahlzaehler <= 12;
                                                    else Strahlzaehler <= Sendedaten[15] ? 4 : 8 ;
              Sendedaten <= {Sendedaten[14:0], 1'b0};
            end
            else // Neue Daten holen
            begin
              if (Sendepause | !EtwasVersenden) Strahlzaehler <= 8;
              else
              begin
                EtwasVersenden <= 0;

                if (Ausgehendes == 0) Strahlzaehler <= 12;
                else
                begin
                  Strahlzaehler <= 4;
                  casez (Ausgehendes)
                    16'b1???????????????: Sendedaten <= {Ausgehendes[14:0],  1'b1};
                    16'b01??????????????: Sendedaten <= {Ausgehendes[13:0],  2'b10};
                    16'b001?????????????: Sendedaten <= {Ausgehendes[12:0],  3'b100};
                    16'b0001????????????: Sendedaten <= {Ausgehendes[11:0],  4'b1000};
                    16'b00001???????????: Sendedaten <= {Ausgehendes[10:0],  5'b10000};
                    16'b000001??????????: Sendedaten <= {Ausgehendes[ 9:0],  6'b100000};
                    16'b0000001?????????: Sendedaten <= {Ausgehendes[ 8:0],  7'b1000000};
                    16'b00000001????????: Sendedaten <= {Ausgehendes[ 7:0],  8'b10000000};
                    16'b000000001???????: Sendedaten <= {Ausgehendes[ 6:0],  9'b100000000};
                    16'b0000000001??????: Sendedaten <= {Ausgehendes[ 5:0], 10'b1000000000};
                    16'b00000000001?????: Sendedaten <= {Ausgehendes[ 4:0], 11'b10000000000};
                    16'b000000000001????: Sendedaten <= {Ausgehendes[ 3:0], 12'b100000000000};
                    16'b0000000000001???: Sendedaten <= {Ausgehendes[ 2:0], 13'b1000000000000};
                    16'b00000000000001??: Sendedaten <= {Ausgehendes[ 1:0], 14'b10000000000000};
                    16'b000000000000001?: Sendedaten <= {Ausgehendes[   0], 15'b100000000000000};
                    16'b0000000000000001: Sendedaten <= {                   16'b1000000000000000};
                  endcase
                end
              end // Etwas Versenden
            end // Neue Daten holen


          end // Verbindung besteht

          // Angekommende Daten bearbeiten

          if (Wartebitte ? LichtmusterN[16:0] == 17'b1111111111100_0000 : LichtmusterN[12:0] == 13'b1111111111100) // Übertragungspuls wird mit 11 bis 14 Basiszeiten erkannt
          begin
            empfangenes[schreibzeiger] <= Datenregister;
            schreibzeiger <= schreibzeiger + 1;
            Datenregister <= 0;
          end
          else
          begin
            if (Wartebitte ? LichtmusterN[12:0] == 13'b111111100_0000 : LichtmusterN[8:0] == 9'b111111100)
                   Datenregister <= {Datenregister[14:0], 1'b0}; // Null-Puls wird mit 7-10 Basiszeiten erkannt
              else Datenregister <= {Datenregister[14:0], 1'b1}; // Eins-Puls wird mit 3-6 Basiszeiten erkannt
          end

        end // Noch keinen ankommenden Puls erkannt
        else
        begin

          if (LauschzaehlerN != 0)
          begin
            Lauschzaehler <= LauschzaehlerN;
            {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b110; // Umgekehrt laden
          end
          else
          begin // Taktlauscher-Init, wenn kein Puls erkannt wurde
            Sendedaten <= 0; // Keine Daten zum Herausrotieren und Abstrahlen ! Wichtig !
            Verbindungsdauer <= 0;

            EtwasVersenden <= 0; // Keine Daten von der letzten Verbindung übernehmen. *** Einstellen nach Wunsch.

            //  Verbindungsdauer @ Synchrondauer = if Verbindungsende then

            if (Dunkelheit)
            begin // Für einen dunkelen Taktlauscher
              Strahlzaehler <= 0;
              Lauschzaehler <= 1;
              {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b110; // Umgekehrt laden
            end
            else
            begin // Für einen hellen Taktlauscher
              Strahlzaehler <= 8;
              {Kathode_DIR, Kathode_OUT, Anode_OUT } <= 3'b101; // Leuchten lassen !
            end

          end // Taktlauscher-Init

        end // LichtmusterN...

      end // Strahlzaehler <> 0

    end // Tick

  end // always

endmodule
