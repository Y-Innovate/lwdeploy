          05 LLWDM204.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID-SINCE         PIC S9(9) USAGE COMP-5.
             10 ADMINVIEW           PIC N.
             10 APP-COUNT           PIC S9(4) USAGE COMP-5.
             10 APP-ENTRY OCCURS 20 TIMES
                  DEPENDING ON APP-COUNT.
                15 APPID               PIC S9(9) USAGE COMP-5.
                15 APPCODE             PIC N(08).
                15 APPNAME.
                   49 APPNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 APPNAME-TEXT PIC N(60).
                15 ISMEMBER            PIC N.
                15 ISOWNER             PIC N.
                15 ISAPPROVER          PIC N.
                15 ACCESSGROUP         PIC N(08).
                15 OWNERGROUP          PIC N(08).
