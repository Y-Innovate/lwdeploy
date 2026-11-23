          05 LLWDM216.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 RUNID               PIC S9(9) USAGE COMP-5.
             10 FILENO-SINCE        PIC S9(4) USAGE COMP-5.
             10 SPF-COUNT           PIC S9(4) USAGE COMP-5.
             10 SPF-ENTRY OCCURS 20 TIMES
                  DEPENDING ON SPF-COUNT.
                15 FILENO              PIC S9(4) USAGE COMP-5.
                15 DDNAME              PIC N(08).
                15 STEPNAME            PIC N(08).
                15 PROCSTEP            PIC N(08).
                15 LINECOUNT           PIC S9(9) USAGE COMP-5.
                15 TRUNCATED           PIC N.
