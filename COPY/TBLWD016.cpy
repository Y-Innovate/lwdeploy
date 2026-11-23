      ******************************************************************
      * DCLGEN TABLE(TBLWD016)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD016 TABLE
           ( RUNID                          INTEGER NOT NULL,
             FILENO                         SMALLINT NOT NULL,
             DDNAME                         GRAPHIC(8) NOT NULL,
             STEPNAME                       GRAPHIC(8),
             PROCSTEP                       GRAPHIC(8),
             LINECOUNT                      INTEGER NOT NULL,
             TRUNCATED                      GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD016.
           10 RUNID                PIC S9(9) USAGE COMP-5.
           10 FILENO               PIC S9(4) USAGE COMP-5.
           10 DDNAME               PIC N(8).
           10 STEPNAME             PIC N(8).
           10 STEPNAME-IND         PIC S9(4) USAGE COMP-5.
           10 PROCSTEP             PIC N(8).
           10 PROCSTEP-IND         PIC S9(4) USAGE COMP-5.
           10 LINECOUNT            PIC S9(9) USAGE COMP-5.
           10 TRUNCATED            PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
