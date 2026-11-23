          05 LLWDM290.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DEPLID-SINCE        PIC S9(9) USAGE COMP-5.
             10 APQ-COUNT           PIC S9(4) USAGE COMP-5.
             10 APQ-ENTRY OCCURS 20 TIMES
                  DEPENDING ON APQ-COUNT.
                15 DEPLID              PIC S9(9) USAGE COMP-5.
                15 APPID               PIC S9(9) USAGE COMP-5.
                15 APPCODE             PIC N(08).
                15 APPNAME.
                   49 APPNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 APPNAME-TEXT PIC N(60).
                15 ENVID               PIC S9(9) USAGE COMP-5.
                15 ENVCODE             PIC N(08).
                15 ENVNAME.
                   49 ENVNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 ENVNAME-TEXT PIC N(60).
                15 VERSIONNAME.
                   49 VERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 VERSIONNAME-TEXT PIC N(30).
                15 APPROVEDCOUNT       PIC S9(4) USAGE COMP-5.
                15 APPROVALCOUNT       PIC S9(4) USAGE COMP-5.
                15 STARTAFTER          PIC N(26).
                15 REQUESTEDBY         PIC N(08).
                15 REQUESTEDDATE       PIC N(26).
