          05 LLWDM004.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 OPCODE              PIC N.
             10 APPCODE             PIC N(08).
             10 APPNAME.
                49 APPNAME-LEN PIC S9(4) USAGE COMP-5.
                49 APPNAME-TEXT PIC N(60).
             10 APPDESCRIPTION.
                49 APPDESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 APPDESCRIPTION-TEXT PIC N(1000).
             10 ACCESSGROUP         PIC N(08).
             10 OWNERGROUP          PIC N(08).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
