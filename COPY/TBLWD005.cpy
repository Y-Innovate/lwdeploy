      ******************************************************************
      * DCLGEN TABLE(TBLWD005)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD005 TABLE
           ( VERSIONID                      INTEGER NOT NULL,
             APPID                          INTEGER NOT NULL,
             VERSIONNAME                    VARGRAPHIC(30) NOT NULL,
             LOCTYPE                        GRAPHIC(1) NOT NULL,
             LOCATION                       VARGRAPHIC(255) NOT NULL,
             DESCRIPTION                    VARGRAPHIC(1000),
             VERSIONSTATUS                  GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD005.
           10 VERSIONID            PIC S9(9) USAGE COMP-5.
           10 APPID                PIC S9(9) USAGE COMP-5.
           10 VERSIONNAME.
              49 VERSIONNAME-LEN PIC S9(4) USAGE COMP-5.
              49 VERSIONNAME-TEXT PIC N(30).
           10 LOCTYPE              PIC N(1).
           10 LOCATION.
              49 LOCATION-LEN PIC S9(4) USAGE COMP-5.
              49 LOCATION-TEXT PIC N(255).
           10 DESCRIPTION.
              49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
              49 DESCRIPTION-TEXT PIC N(1000).
           10 DESCRIPTION-IND      PIC S9(4) USAGE COMP-5.
           10 VERSIONSTATUS        PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
