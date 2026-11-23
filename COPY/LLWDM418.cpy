          05 LLWDM418.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DEPLID              PIC S9(9) USAGE COMP-5.
             10 DECISION            PIC N.
             10 COMMENTTEXT.
                49 COMMENTTEXT-LEN PIC S9(4) USAGE COMP-5.
                49 COMMENTTEXT-TEXT PIC N(255).
             10 DEPLSTATUS          PIC N.
             10 APPROVEDCOUNT       PIC S9(4) USAGE COMP-5.
             10 APPROVALCOUNT       PIC S9(4) USAGE COMP-5.
