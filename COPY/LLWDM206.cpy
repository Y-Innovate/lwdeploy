          05 LLWDM206.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 ENV-COUNT           PIC S9(4) USAGE COMP-5.
             10 ENV-ENTRY OCCURS 20 TIMES
                  DEPENDING ON ENV-COUNT.
                15 ENVID               PIC S9(9) USAGE COMP-5.
                15 ENVCODE             PIC N(08).
                15 ENVNAME.
                   49 ENVNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 ENVNAME-TEXT PIC N(60).
                15 SORTORDER           PIC S9(4) USAGE COMP-5.
                15 PROMOGATE           PIC N.
                15 APPROVALREQ         PIC N.
                15 APPROVALCOUNT       PIC S9(4) USAGE COMP-5.
                15 ENVSTATE            PIC N.
                15 CURRENTVERSIONID    PIC S9(9) USAGE COMP-5.
                15 CURRENTVERSIONNAME.
                   49 CURRENTVERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 CURRENTVERSIONNAME-TEXT PIC N(30).
                15 CURRENTDEPLID       PIC S9(9) USAGE COMP-5.
                15 DEPLOYEDDATE        PIC N(26).
                15 ACTIVEDEPLID        PIC S9(9) USAGE COMP-5.
                15 CANDEPLOY           PIC N.
                15 CANAPPROVE          PIC N.
