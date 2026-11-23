          05 LLWDM215.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 RUNID               PIC S9(9) USAGE COMP-5.
             10 STEPNO-SINCE        PIC S9(4) USAGE COMP-5.
             10 STP-COUNT           PIC S9(4) USAGE COMP-5.
             10 STP-ENTRY OCCURS 20 TIMES
                  DEPENDING ON STP-COUNT.
                15 STEPNO              PIC S9(4) USAGE COMP-5.
                15 STEPNAME            PIC N(08).
                15 PROCSTEP            PIC N(08).
                15 PGMNAME             PIC N(08).
                15 STEPRC              PIC S9(4) USAGE COMP-5.
                15 ABENDCODE           PIC N(05).
                15 FLUSHED             PIC N.
