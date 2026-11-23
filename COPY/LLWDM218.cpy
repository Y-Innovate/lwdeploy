          05 LLWDM218.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DEPLID              PIC S9(9) USAGE COMP-5.
             10 APR-COUNT           PIC S9(4) USAGE COMP-5.
             10 APR-ENTRY OCCURS 20 TIMES
                  DEPENDING ON APR-COUNT.
                15 USERID              PIC N(08).
                15 DECISION            PIC N.
                15 COMMENTTEXT.
                   49 COMMENTTEXT-LEN PIC S9(4) USAGE COMP-5.
                   49 COMMENTTEXT-TEXT PIC N(255).
                15 CREATEDDATE         PIC N(26).
