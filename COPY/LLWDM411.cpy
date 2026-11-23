          05 LLWDM411.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 ENVID               PIC S9(9) USAGE COMP-5.
             10 VERSIONID           PIC S9(9) USAGE COMP-5.
             10 STARTAFTER          PIC N(26).
             10 REQUESTNOTE.
                49 REQUESTNOTE-LEN PIC S9(4) USAGE COMP-5.
                49 REQUESTNOTE-TEXT PIC N(255).
             10 DEPLID              PIC S9(9) USAGE COMP-5.
             10 APPCODE             PIC N(08).
             10 APPNAME.
                49 APPNAME-LEN PIC S9(4) USAGE COMP-5.
                49 APPNAME-TEXT PIC N(60).
             10 ENVCODE             PIC N(08).
             10 ENVNAME.
                49 ENVNAME-LEN PIC S9(4) USAGE COMP-5.
                49 ENVNAME-TEXT PIC N(60).
             10 VERSIONNAME.
                49 VERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                49 VERSIONNAME-TEXT PIC N(30).
             10 LOCATION.
                49 LOCATION-LEN PIC S9(4) USAGE COMP-5.
                49 LOCATION-TEXT PIC N(255).
             10 DEPLSTATUS          PIC N.
             10 DEPLOYUSER          PIC N(08).
             10 APPROVERGROUP       PIC N(08).
             10 APPROVALCOUNT       PIC S9(4) USAGE COMP-5.
             10 APPROVEDCOUNT       PIC S9(4) USAGE COMP-5.
             10 STARTEDDATE         PIC N(26).
             10 ENDEDDATE           PIC N(26).
             10 REQUESTEDBY         PIC N(08).
             10 REQUESTEDDATE       PIC N(26).
             10 CANCANCEL           PIC N.
             10 CANRETRY            PIC N.
             10 CANAPPROVE          PIC N.
