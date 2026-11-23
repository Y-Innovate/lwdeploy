      ******************************************************************
      * DCLGEN TABLE(TBLWD017)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD017 TABLE
           ( RUNID                          INTEGER NOT NULL,
             FILENO                         SMALLINT NOT NULL,
             LINENUM                        INTEGER NOT NULL,
             LINETEXT                       VARGRAPHIC(255) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD017.
           10 RUNID                PIC S9(9) USAGE COMP-5.
           10 FILENO               PIC S9(4) USAGE COMP-5.
           10 LINENUM              PIC S9(9) USAGE COMP-5.
           10 LINETEXT.
              49 LINETEXT-LEN PIC S9(4) USAGE COMP-5.
              49 LINETEXT-TEXT PIC N(255).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
