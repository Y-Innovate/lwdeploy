          05 LLWDM302.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 USERID              PIC N(08).
             10 EMAIL.
                49 EMAIL-LEN PIC S9(4) USAGE COMP-5.
                49 EMAIL-TEXT PIC N(254).
             10 NOTIFYAPPROVE       PIC N.
             10 NOTIFYOWN           PIC N.
             10 NOTIFYAPP           PIC N.
             10 ISADMIN             PIC N.
             10 APPROVALSWAITING    PIC S9(9) USAGE COMP-5.
