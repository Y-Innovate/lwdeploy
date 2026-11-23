          05 LLWDM405.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 APPID               PIC S9(9) USAGE COMP-5.
             10 VERSIONNAME.
                49 VERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
                49 VERSIONNAME-TEXT PIC N(30).
             10 LOCTYPE             PIC N.
             10 LOCATION.
                49 LOCATION-LEN PIC S9(4) USAGE COMP-5.
                49 LOCATION-TEXT PIC N(255).
             10 DESCRIPTION.
                49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 DESCRIPTION-TEXT PIC N(1000).
             10 VERSIONID           PIC S9(9) USAGE COMP-5.
             10 VERSIONSTATUS       PIC N.
             10 ISUSED              PIC N.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
