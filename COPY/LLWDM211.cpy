          05 LLWDM211.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 ENVID-FILTER        PIC S9(9) USAGE COMP-5.
             10 VERSIONID-FILTER    PIC S9(9) USAGE COMP-5.
             10 DEPLSTATUS-FILTER   PIC N.
             10 REQUESTEDBY-FILTER  PIC N(08).
             10 DEPLID-FILTER       PIC S9(9) USAGE COMP-5.
             10 APPCODE-FILTER      PIC N(08).
             10 ENVCODE-FILTER      PIC N(08).
             10 VERSIONNAME-FILTER  PIC N(30).
             10 DEPLID-SINCE        PIC S9(9) USAGE COMP-5.
             10 ADMINVIEW           PIC N.
             10 DEP-COUNT           PIC S9(4) USAGE COMP-5.
             10 DEP-ENTRY OCCURS 20 TIMES
                  DEPENDING ON DEP-COUNT.
                15 DEPLID              PIC S9(9) USAGE COMP-5.
                15 DEP-APPID           PIC S9(9) USAGE COMP-5.
                15 APPCODE             PIC N(08).
                15 ENVID               PIC S9(9) USAGE COMP-5.
                15 ENVCODE             PIC N(08).
                15 VERSIONID           PIC S9(9) USAGE COMP-5.
                15 VERSIONNAME.
                   49 VERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 VERSIONNAME-TEXT PIC N(30).
                15 DEPLSTATUS          PIC N.
                15 STARTAFTER          PIC N(26).
                15 REQUESTEDBY         PIC N(08).
                15 REQUESTEDDATE       PIC N(26).
                15 ENDEDDATE           PIC N(26).
