      ******************************************************************
      * DCLGEN TABLE(TBLWD008)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD008 TABLE
           ( TEMPLATEID                     INTEGER NOT NULL,
             APPID                          INTEGER NOT NULL,
             TEMPLATENAME                   VARGRAPHIC(60) NOT NULL,
             SORTORDER                      SMALLINT NOT NULL,
             MAXRC                          SMALLINT NOT NULL,
             CURRENTREV                     SMALLINT NOT NULL,
             TEMPLATESTATUS                 GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD008.
           10 TEMPLATEID           PIC S9(9) USAGE COMP-5.
           10 APPID                PIC S9(9) USAGE COMP-5.
           10 TEMPLATENAME.
              49 TEMPLATENAME-LEN PIC S9(4) USAGE COMP-5.
              49 TEMPLATENAME-TEXT PIC N(60).
           10 SORTORDER            PIC S9(4) USAGE COMP-5.
           10 MAXRC                PIC S9(4) USAGE COMP-5.
           10 CURRENTREV           PIC S9(4) USAGE COMP-5.
           10 TEMPLATESTATUS       PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
