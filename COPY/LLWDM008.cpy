          05 LLWDM008.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 TEMPLATEID          PIC S9(9) USAGE COMP-5.
             10 OPCODE              PIC N.
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 TEMPLATENAME.
                49 TEMPLATENAME-LEN PIC S9(4) USAGE COMP-5.
                49 TEMPLATENAME-TEXT PIC N(60).
             10 SORTORDER           PIC S9(4) USAGE COMP-5.
             10 MAXRC               PIC S9(4) USAGE COMP-5.
             10 CURRENTREV          PIC S9(4) USAGE COMP-5.
             10 TEMPLATESTATUS      PIC N.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
