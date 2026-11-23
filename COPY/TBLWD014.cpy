      ******************************************************************
      * DCLGEN TABLE(TBLWD014)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD014 TABLE
           ( RUNID                          INTEGER NOT NULL,
             DEPLID                         INTEGER NOT NULL,
             JOBNO                          SMALLINT NOT NULL,
             JOBNAME                        GRAPHIC(8) NOT NULL,
             RUNSTATUS                      GRAPHIC(1) NOT NULL,
             JOBRESULT                      GRAPHIC(1),
             JESJOBID                       GRAPHIC(8),
             SUBMITTEDDATE                  TIMESTAMP,
             ENDEDDATE                      TIMESTAMP,
             JOBRC                          SMALLINT,
             ABENDCODE                      GRAPHIC(5),
             JOBMESSAGE                     VARGRAPHIC(72),
             OUTPUTSTATUS                   GRAPHIC(1) NOT NULL,
             JOBHASH                        BINARY(32),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD014.
           10 RUNID                PIC S9(9) USAGE COMP-5.
           10 DEPLID               PIC S9(9) USAGE COMP-5.
           10 JOBNO                PIC S9(4) USAGE COMP-5.
           10 JOBNAME              PIC N(8).
           10 RUNSTATUS            PIC N(1).
           10 JOBRESULT            PIC N(1).
           10 JOBRESULT-IND        PIC S9(4) USAGE COMP-5.
           10 JESJOBID             PIC N(8).
           10 JESJOBID-IND         PIC S9(4) USAGE COMP-5.
           10 SUBMITTEDDATE        PIC X(26).
           10 SUBMITTEDDATE-IND    PIC S9(4) USAGE COMP-5.
           10 ENDEDDATE            PIC X(26).
           10 ENDEDDATE-IND        PIC S9(4) USAGE COMP-5.
           10 JOBRC                PIC S9(4) USAGE COMP-5.
           10 JOBRC-IND            PIC S9(4) USAGE COMP-5.
           10 ABENDCODE            PIC N(5).
           10 ABENDCODE-IND        PIC S9(4) USAGE COMP-5.
           10 JOBMESSAGE.
              49 JOBMESSAGE-LEN PIC S9(4) USAGE COMP-5.
              49 JOBMESSAGE-TEXT PIC N(72).
           10 JOBMESSAGE-IND       PIC S9(4) USAGE COMP-5.
           10 OUTPUTSTATUS         PIC N(1).
           10 JOBHASH              PIC X(32).
           10 JOBHASH-IND          PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
