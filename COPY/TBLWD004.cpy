      ******************************************************************
      * DCLGEN TABLE(TBLWD004)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD004 TABLE
           ( APPID                          INTEGER NOT NULL,
             APPCODE                        GRAPHIC(8) NOT NULL,
             APPNAME                        VARGRAPHIC(60) NOT NULL,
             DESCRIPTION                    VARGRAPHIC(1000),
             ACCESSGROUP                    GRAPHIC(8) NOT NULL,
             OWNERGROUP                     GRAPHIC(8) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD004.
           10 APPID                PIC S9(9) USAGE COMP-5.
           10 APPCODE              PIC N(8).
           10 APPNAME.
              49 APPNAME-LEN PIC S9(4) USAGE COMP-5.
              49 APPNAME-TEXT PIC N(60).
           10 DESCRIPTION.
              49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
              49 DESCRIPTION-TEXT PIC N(1000).
           10 DESCRIPTION-IND      PIC S9(4) USAGE COMP-5.
           10 ACCESSGROUP          PIC N(8).
           10 OWNERGROUP           PIC N(8).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
