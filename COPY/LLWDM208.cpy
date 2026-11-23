          05 LLWDM208.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 TPL-COUNT           PIC S9(4) USAGE COMP-5.
             10 TPL-ENTRY OCCURS 20 TIMES
                  DEPENDING ON TPL-COUNT.
                15 TEMPLATEID          PIC S9(9) USAGE COMP-5.
                15 TEMPLATENAME.
                   49 TEMPLATENAME-LEN PIC S9(4) USAGE COMP-5.
                   49 TEMPLATENAME-TEXT PIC N(60).
                15 SORTORDER           PIC S9(4) USAGE COMP-5.
                15 MAXRC               PIC S9(4) USAGE COMP-5.
                15 CURRENTREV          PIC S9(4) USAGE COMP-5.
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
