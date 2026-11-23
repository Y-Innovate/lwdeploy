      ******************************************************************
      * DCLGEN TABLE(TBLWD007)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD007 TABLE
           ( VARID                          INTEGER NOT NULL,
             APPID                          INTEGER NOT NULL,
             ENVID                          INTEGER,
             VERSIONID                      INTEGER,
             VARNAME                        VARGRAPHIC(16) NOT NULL,
             VARVALUE                       VARGRAPHIC(255) NOT NULL,
             DESCRIPTION                    VARGRAPHIC(255),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD007.
           10 VARID                PIC S9(9) USAGE COMP-5.
           10 APPID                PIC S9(9) USAGE COMP-5.
           10 ENVID                PIC S9(9) USAGE COMP-5.
           10 ENVID-IND            PIC S9(4) USAGE COMP-5.
           10 VERSIONID            PIC S9(9) USAGE COMP-5.
           10 VERSIONID-IND        PIC S9(4) USAGE COMP-5.
           10 VARNAME.
              49 VARNAME-LEN PIC S9(4) USAGE COMP-5.
              49 VARNAME-TEXT PIC N(16).
           10 VARVALUE.
              49 VARVALUE-LEN PIC S9(4) USAGE COMP-5.
              49 VARVALUE-TEXT PIC N(255).
           10 DESCRIPTION.
              49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
              49 DESCRIPTION-TEXT PIC N(255).
           10 DESCRIPTION-IND      PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
