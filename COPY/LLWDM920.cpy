          05 LLWDM920.
             10 RETURNCODE         PIC N(02).
             10 REASONCODE         PIC N(02).
             10 INFOMESSAGE        PIC N(72).
             10 RUNID              PIC S9(9) USAGE COMP-5.
             10 BUILD-MODE         PIC X.
                88 MODE-CICS                 VALUE 'C'.
                88 MODE-BATCH                VALUE 'B'.
             10 REC-COUNT          PIC S9(4) USAGE COMP-5.
             10 REC                PIC X(80) OCCURS 400 TIMES.
