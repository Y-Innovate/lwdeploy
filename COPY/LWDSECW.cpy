      *===============================================================*
      * LWDSECW: Working storage for LWDSECP, the job token: random   *
      * with CPACF (LWDA991), stored only as a SHA-256 hash.          *
      *===============================================================*
       01 W-SECRETS.
          05 W-A991-PGM         PIC X(8) VALUE 'LWDA991'.
          05 C-HEX              PIC X(16) VALUE '0123456789ABCDEF'.
          05 W-TOKEN            PIC X(64).
          05 W-TOKENHASH        PIC X(32).
          05 W-SEC-I            PIC S9(4) USAGE COMP-5.
          05 W-SEC-J            PIC S9(4) USAGE COMP-5.
          05 W-SEC-K            PIC S9(4) USAGE COMP-5.
          05 W-SEC-BYTE-PAIR.
             10 FILLER          PIC X VALUE LOW-VALUE.
             10 W-SEC-BYTE      PIC X.
          05 W-SEC-BYTE-NUM REDEFINES W-SEC-BYTE-PAIR
                                PIC S9(4) USAGE COMP-5.
       01 W-LLWDA991.
           COPY LLWDA991.
