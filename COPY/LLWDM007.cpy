          05 LLWDM007.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 VARID               PIC S9(9) USAGE COMP-5.
             10 OPCODE              PIC N.
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 ENVID               PIC S9(9) USAGE COMP-5.
             10 VERSIONID           PIC S9(9) USAGE COMP-5.
             10 VARNAME.
                49 VARNAME-LEN PIC S9(4) USAGE COMP-5.
                49 VARNAME-TEXT PIC N(16).
             10 VARVALUE.
                49 VARVALUE-LEN PIC S9(4) USAGE COMP-5.
                49 VARVALUE-TEXT PIC N(255).
             10 VARDESCRIPTION.
                49 VARDESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 VARDESCRIPTION-TEXT PIC N(255).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
