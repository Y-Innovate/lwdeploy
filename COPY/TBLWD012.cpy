      ******************************************************************
      * DCLGEN TABLE(TBLWD012)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD012 TABLE
           ( DEPLID                         INTEGER NOT NULL,
             JOBNO                          SMALLINT NOT NULL,
             TEMPLATEID                     INTEGER NOT NULL,
             TEMPLATEREV                    SMALLINT NOT NULL,
             JOBTITLE                       VARGRAPHIC(60) NOT NULL,
             MAXRC                          SMALLINT NOT NULL,
             JOBSTATUS                      GRAPHIC(1) NOT NULL,
             LINECOUNT                      SMALLINT NOT NULL,
             LASTRUNID                      INTEGER,
             SKIPREASON                     VARGRAPHIC(255),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD012.
           10 DEPLID               PIC S9(9) USAGE COMP-5.
           10 JOBNO                PIC S9(4) USAGE COMP-5.
           10 TEMPLATEID           PIC S9(9) USAGE COMP-5.
           10 TEMPLATEREV          PIC S9(4) USAGE COMP-5.
           10 JOBTITLE.
              49 JOBTITLE-LEN PIC S9(4) USAGE COMP-5.
              49 JOBTITLE-TEXT PIC N(60).
           10 MAXRC                PIC S9(4) USAGE COMP-5.
           10 JOBSTATUS            PIC N(1).
           10 LINECOUNT            PIC S9(4) USAGE COMP-5.
           10 LASTRUNID            PIC S9(9) USAGE COMP-5.
           10 LASTRUNID-IND        PIC S9(4) USAGE COMP-5.
           10 SKIPREASON.
              49 SKIPREASON-LEN PIC S9(4) USAGE COMP-5.
              49 SKIPREASON-TEXT PIC N(255).
           10 SKIPREASON-IND       PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
