          05 LLWDM201.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 TABLEID             PIC N(08).
             10 TABKEY-SINCE        PIC N(08).
             10 REF-COUNT           PIC S9(4) USAGE COMP-5.
             10 REF-ENTRY OCCURS 20 TIMES
                  DEPENDING ON REF-COUNT.
                15 REF-TABLEID         PIC N(08).
                15 TABKEY              PIC N(08).
                15 TABVALUE.
                   49 TABVALUE-LEN PIC S9(4) USAGE COMP-5.
                   49 TABVALUE-TEXT PIC N(255).
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
