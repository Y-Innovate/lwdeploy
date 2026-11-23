      ******************************************************************
      * DCLGEN TABLE(TBLWD013)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD013 TABLE
           ( DEPLID                         INTEGER NOT NULL,
             JOBNO                          SMALLINT NOT NULL,
             LINENUM                        SMALLINT NOT NULL,
             LINETEXT                       VARGRAPHIC(80) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD013.
           10 DEPLID               PIC S9(9) USAGE COMP-5.
           10 JOBNO                PIC S9(4) USAGE COMP-5.
           10 LINENUM              PIC S9(4) USAGE COMP-5.
           10 LINETEXT.
              49 LINETEXT-LEN PIC S9(4) USAGE COMP-5.
              49 LINETEXT-TEXT PIC N(80).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
