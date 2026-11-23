      ******************************************************************
      * DCLGEN TABLE(TBLWD009)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD009 TABLE
           ( TEMPLATEID                     INTEGER NOT NULL,
             REVISION                       SMALLINT NOT NULL,
             CHANGENOTE                     VARGRAPHIC(255),
             LINECOUNT                      SMALLINT NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD009.
           10 TEMPLATEID           PIC S9(9) USAGE COMP-5.
           10 REVISION             PIC S9(4) USAGE COMP-5.
           10 CHANGENOTE.
              49 CHANGENOTE-LEN PIC S9(4) USAGE COMP-5.
              49 CHANGENOTE-TEXT PIC N(255).
           10 CHANGENOTE-IND       PIC S9(4) USAGE COMP-5.
           10 LINECOUNT            PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
