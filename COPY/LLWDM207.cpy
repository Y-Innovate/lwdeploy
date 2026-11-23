          05 LLWDM207.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 ENVID               PIC S9(9) USAGE COMP-5.
             10 VERSIONID           PIC S9(9) USAGE COMP-5.
             10 VARID-SINCE         PIC S9(9) USAGE COMP-5.
             10 VAR-COUNT           PIC S9(4) USAGE COMP-5.
             10 VAR-ENTRY OCCURS 20 TIMES
                  DEPENDING ON VAR-COUNT.
                15 VARID               PIC S9(9) USAGE COMP-5.
                15 VAR-APPID           PIC S9(9) USAGE COMP-5.
                15 VAR-ENVID           PIC S9(9) USAGE COMP-5.
                15 VAR-VERSIONID       PIC S9(9) USAGE COMP-5.
                15 VARNAME.
                   49 VARNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 VARNAME-TEXT PIC N(16).
                15 VARVALUE.
                   49 VARVALUE-LEN PIC S9(4) USAGE COMP-5.
                   49 VARVALUE-TEXT PIC N(255).
                15 VARDESCRIPTION.
                   49 VARDESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                   49 VARDESCRIPTION-TEXT PIC N(255).
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
