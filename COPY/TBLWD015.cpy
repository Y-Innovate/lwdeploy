      ******************************************************************
      * DCLGEN TABLE(TBLWD015)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD015 TABLE
           ( RUNID                          INTEGER NOT NULL,
             STEPNO                         SMALLINT NOT NULL,
             STEPNAME                       GRAPHIC(8) NOT NULL,
             PROCSTEP                       GRAPHIC(8),
             PGMNAME                        GRAPHIC(8),
             STEPRC                         SMALLINT,
             ABENDCODE                      GRAPHIC(5),
             FLUSHED                        GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD015.
           10 RUNID                PIC S9(9) USAGE COMP-5.
           10 STEPNO               PIC S9(4) USAGE COMP-5.
           10 STEPNAME             PIC N(8).
           10 PROCSTEP             PIC N(8).
           10 PROCSTEP-IND         PIC S9(4) USAGE COMP-5.
           10 PGMNAME              PIC N(8).
           10 PGMNAME-IND          PIC S9(4) USAGE COMP-5.
           10 STEPRC               PIC S9(4) USAGE COMP-5.
           10 STEPRC-IND           PIC S9(4) USAGE COMP-5.
           10 ABENDCODE            PIC N(5).
           10 ABENDCODE-IND        PIC S9(4) USAGE COMP-5.
           10 FLUSHED              PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
