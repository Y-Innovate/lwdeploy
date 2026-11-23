          05 LLWDM205.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 VERSIONSTATUS-FILTER PIC N.
             10 VERSIONID-SINCE     PIC S9(9) USAGE COMP-5.
             10 VER-COUNT           PIC S9(4) USAGE COMP-5.
             10 VER-ENTRY OCCURS 20 TIMES
                  DEPENDING ON VER-COUNT.
                15 VERSIONID           PIC S9(9) USAGE COMP-5.
                15 VERSIONNAME.
                   49 VERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 VERSIONNAME-TEXT PIC N(30).
                15 LOCTYPE             PIC N.
                15 LOCATION.
                   49 LOCATION-LEN PIC S9(4) USAGE COMP-5.
                   49 LOCATION-TEXT PIC N(255).
                15 VERSIONSTATUS       PIC N.
                15 ISUSED              PIC N.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
