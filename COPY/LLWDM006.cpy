          05 LLWDM006.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 ENVID               PIC S9(9) USAGE COMP-5.
             10 OPCODE              PIC N.
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 ENVCODE             PIC N(08).
             10 ENVNAME.
                49 ENVNAME-LEN PIC S9(4) USAGE COMP-5.
                49 ENVNAME-TEXT PIC N(60).
             10 ENVDESCRIPTION.
                49 ENVDESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 ENVDESCRIPTION-TEXT PIC N(1000).
             10 SORTORDER           PIC S9(4) USAGE COMP-5.
             10 PROMOGATE           PIC N.
             10 DEPLOYUSER          PIC N(08).
             10 APPROVALREQ         PIC N.
             10 APPROVERGROUP       PIC N(08).
             10 APPROVALCOUNT       PIC S9(4) USAGE COMP-5.
             10 DEPLOYERGROUP       PIC N(08).
             10 EXECNODE            PIC N(08).
             10 ENVSTATE            PIC N.
             10 CURRENTVERSIONID    PIC S9(9) USAGE COMP-5.
             10 CURRENTVERSIONNAME.
                49 CURRENTVERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                49 CURRENTVERSIONNAME-TEXT PIC N(30).
             10 CURRENTDEPLID       PIC S9(9) USAGE COMP-5.
             10 DEPLOYEDDATE        PIC N(26).
             10 ACTIVEDEPLID        PIC S9(9) USAGE COMP-5.
             10 CANDEPLOY           PIC N.
             10 CANAPPROVE          PIC N.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
