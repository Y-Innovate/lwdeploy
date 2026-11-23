          05 LLWDM219.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DEPLID              PIC S9(9) USAGE COMP-5.
             10 EVENTNO-SINCE       PIC S9(4) USAGE COMP-5.
             10 EVT-COUNT           PIC S9(4) USAGE COMP-5.
             10 EVT-ENTRY OCCURS 20 TIMES
                  DEPENDING ON EVT-COUNT.
                15 EVENTNO             PIC S9(4) USAGE COMP-5.
                15 EVENTTYPE           PIC N.
                15 JOBNO               PIC S9(4) USAGE COMP-5.
                15 COMMENTTEXT.
                   49 COMMENTTEXT-LEN PIC S9(4) USAGE COMP-5.
                   49 COMMENTTEXT-TEXT PIC N(255).
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
