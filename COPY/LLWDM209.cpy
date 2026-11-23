          05 LLWDM209.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 TEMPLATEID          PIC S9(9) USAGE COMP-5.
             10 REVISION-SINCE      PIC S9(4) USAGE COMP-5.
             10 REV-COUNT           PIC S9(4) USAGE COMP-5.
             10 REV-ENTRY OCCURS 20 TIMES
                  DEPENDING ON REV-COUNT.
                15 REVISION            PIC S9(4) USAGE COMP-5.
                15 CHANGENOTE.
                   49 CHANGENOTE-LEN PIC S9(4) USAGE COMP-5.
                   49 CHANGENOTE-TEXT PIC N(255).
                15 LINECOUNT           PIC S9(9) USAGE COMP-5.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
