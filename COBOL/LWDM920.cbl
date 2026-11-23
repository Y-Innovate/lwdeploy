       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM920.
      *===============================================================*
      * This program is a DB2 module of the LWD application: it       *
      * builds the 80-byte JCL records of run RUNID, for the submit   *
      * task (CICS). It writes nothing.                               *
      *   JOB statement: job name of the run, the job classes, and    *
      *        USER= the deploy userid in mode C. Mode B leaves USER= *
      *        out, for LWDM915, the result step before iteration 4,  *
      *        which submits the next job of a run it was in itself.  *
      *   /*XEQ with the environment's EXECNODE, when it has one: the *
      *        job runs on that JES2 node.                            *
      *   The frozen JCL of the job (JCLLINES), in EBCDIC.            *
      *   The result step: REXX LWDR916 under JCL IF tests, with the  *
      *        run and its outcome in PARM: A abend, O within MAXRC,  *
      *        H above MAXRC. It sends them to POST /jobResults,      *
      *        with an Entra access token for the deploy userid. On   *
      *        DD LWDCONF: where to find LWD and Entra, Java and the  *
      *        jars of JWTSignerUtil, from the settings, and the      *
      *        Entra application of the deploy userid, from DEPLAPP.  *
      *        No DB2 in the job.                                     *
      * Nothing a user typed goes in except the frozen JCL itself,    *
      * which was approved as it is.                                  *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Run not found                                         *
      * 08 01 = Error: BUILD-MODE is not C or B                       *
      * 08 90 = Error: too many records, or a setting is missing      *
      * 08 91 = Error: no Entra application for the deploy userid in  *
      *         DEPLAPP                                               *
      * And the codes of LWDCTXP                                      *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD013 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-RUNID         PIC S9(9) COMP-5.
          05 W-DEPLID        PIC S9(9) COMP-5.
          05 W-JOBNO         PIC S9(4) COMP-5.
          05 W-MAXRC         PIC S9(4) COMP-5.
          05 W-JOBNAME-N     PIC N(8).
          05 W-DEPLOYUSER-N  PIC N(8).
          05 W-EXECNODE-N    PIC N(8).
          05 W-EXECNODE-IND  PIC S9(4) COMP-5.
          05 W-EXECNODE      PIC X(8).
          05 W-JOBNAME       PIC X(8).
          05 W-DEPLOYUSER    PIC X(8).
          05 W-RUNID-9       PIC 9(9).
          05 W-DEPLID-ED     PIC Z(8)9.
          05 W-JOBNO-ED      PIC Z9.
          05 W-MAXRC-ED      PIC Z(3)9.
          05 W-RESULT        PIC X.
          05 W-APOS          PIC X VALUE "'".
          05 W-DEPLAPP       PIC N(8) VALUE N'DEPLAPP'.
          05 W-EOF           PIC X.
          05 W-REC           PIC X(80).
          05 W-PTR           PIC S9(4) COMP-5.
          05 W-LT.
             49 W-LT-LEN     PIC S9(4) COMP-5.
             49 W-LT-TEXT    PIC N(80).
      *   Settings, in EBCDIC
          05 S-JOBCLASS      PIC X(8).
          05 S-MSGCLASS      PIC X(8).
          05 S-EXECLIB       PIC X(44).
          05 S-LWDURL        PIC X(72).
          05 S-LWDPORT       PIC X(72).
          05 S-LWDPATH       PIC X(72).
          05 S-LWDRING       PIC X(72).
          05 S-TENANT        PIC X(72).
          05 S-APISCOPE      PIC X(72).
          05 S-JAVAHOME      PIC X(72).
          05 S-JWTJARS       PIC X(72).
      *   Entra application of the deploy userid, in EBCDIC
          05 S-CLIENTID      PIC X(72).
          05 W-SETX          PIC X(72).

       LINKAGE SECTION.
       01 P-LLWDM920.
           COPY LLWDM920.

       PROCEDURE DIVISION USING P-LLWDM920.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R100-SETTINGS
           PERFORM R200-READ-RUN
           PERFORM R210-CLIENT-ID

           IF RETURNCODE OF P-LLWDM920 = N'00'
              PERFORM R300-JOBCARD
              PERFORM R400-FROZEN-JCL
              PERFORM R500-RESULT-STEPS
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM920
           MOVE N'00' TO REASONCODE OF P-LLWDM920
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM920

           MOVE 0 TO REC-COUNT OF P-LLWDM920
           MOVE RUNID OF P-LLWDM920 TO W-RUNID
           MOVE W-RUNID TO W-RUNID-9

           IF NOT MODE-CICS OF P-LLWDM920
           AND NOT MODE-BATCH OF P-LLWDM920
              MOVE N'08' TO RETURNCODE OF P-LLWDM920
              MOVE N'01' TO REASONCODE OF P-LLWDM920
              MOVE N'BUILD-MODE must be C or B' TO
                   INFOMESSAGE OF P-LLWDM920
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R100-SETTINGS: The settings that go into the JCL              *
      *===============================================================*
       R100-SETTINGS SECTION.
           MOVE N'JOBCLASS' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-JOBCLASS
           MOVE N'MSGCLASS' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-MSGCLASS
           MOVE N'EXECLIB' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-EXECLIB
      *    Where the result step finds LWD's REST API
           MOVE N'LWDURL' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-LWDURL
           MOVE N'LWDPORT' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-LWDPORT
           MOVE N'LWDPATH' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-LWDPATH
           MOVE N'LWDRING' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-LWDRING
      *    Its Entra token: tenant, scope of LWD's API, and Java with
      *    JWTSignerUtil, which signs the client assertion
           MOVE N'TENANT' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-TENANT
           MOVE N'APISCOPE' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-APISCOPE
           MOVE N'JAVAHOME' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-JAVAHOME
           MOVE N'JWTJARS' TO W-SETKEY
           PERFORM R110-SETTING
           MOVE W-SETX TO S-JWTJARS
           .
       R100-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R110-SETTING: Setting W-SETKEY in EBCDIC in W-SETX, at most   *
      * 72 characters, so a key=value record fits in 80               *
      *===============================================================*
       R110-SETTING SECTION.
           MOVE SPACES TO W-SETX
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF P-LLWDM920 = N'00'
              MOVE FUNCTION DISPLAY-OF(W-SETVALUE-TEXT
                   (1:FUNCTION MIN(W-SETVALUE-LEN, 72))) TO W-SETX
           END-IF
           .
       R110-SETTING-END.
           EXIT.

      *===============================================================*
      * R200-READ-RUN: Job name, deploy userid, highest RC and the    *
      * node the jobs of the environment run on                       *
      *===============================================================*
       R200-READ-RUN SECTION.
           IF RETURNCODE OF P-LLWDM920 = N'00'
              EXEC SQL
                 SELECT R.DEPLID,
                        R.JOBNO,
                        R.JOBNAME,
                        D.DEPLOYUSER,
                        J.MAXRC,
                        E.EXECNODE
                   INTO :W-DEPLID,
                        :W-JOBNO,
                        :W-JOBNAME-N,
                        :W-DEPLOYUSER-N,
                        :W-MAXRC,
                        :W-EXECNODE-N :W-EXECNODE-IND
                   FROM TBLWD014 R
                   JOIN TBLWD011 D
                     ON D.DEPLID = R.DEPLID
                   JOIN TBLWD012 J
                     ON J.DEPLID = R.DEPLID
                    AND J.JOBNO = R.JOBNO
                   JOIN TBLWD006 E
                     ON E.ENVID = D.ENVID
                  WHERE R.RUNID = :W-RUNID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE FUNCTION DISPLAY-OF(W-JOBNAME-N) TO W-JOBNAME
                 MOVE FUNCTION DISPLAY-OF(W-DEPLOYUSER-N) TO
                      W-DEPLOYUSER
                 MOVE SPACES TO W-EXECNODE
                 IF W-EXECNODE-IND >= 0
                    MOVE FUNCTION DISPLAY-OF(W-EXECNODE-N) TO
                         W-EXECNODE
                 END-IF
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM920
                 MOVE N'01' TO REASONCODE OF P-LLWDM920
                 MOVE N'Run not found' TO INFOMESSAGE OF P-LLWDM920
              WHEN OTHER
                 MOVE N'SELECT run' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-READ-RUN-END.
           EXIT.

      *===============================================================*
      * R210-CLIENT-ID: Entra application (client ID) of the deploy   *
      * userid, from DEPLAPP: LWW maps it to that userid              *
      *===============================================================*
       R210-CLIENT-ID SECTION.
           IF RETURNCODE OF P-LLWDM920 = N'00'
              MOVE SPACES TO S-CLIENTID
              EXEC SQL
                 SELECT TABVALUE
                   INTO :W-SETVALUE
                   FROM TBLWD001
                  WHERE TABLEID = :W-DEPLAPP
                    AND TABKEY = :W-DEPLOYUSER-N
                    AND TABVALUE IS NOT NULL
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE FUNCTION DISPLAY-OF(W-SETVALUE-TEXT
                      (1:FUNCTION MIN(W-SETVALUE-LEN, 72)))
                   TO S-CLIENTID
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LLWDM920
                 MOVE N'91' TO REASONCODE OF P-LLWDM920
                 STRING N'No Entra application for deploy userid '
                        W-DEPLOYUSER-N N' in DEPLAPP'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LLWDM920
              WHEN OTHER
                 MOVE N'SELECT DEPLAPP' TO W-SQL-WHAT
                 MOVE N'22' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R210-CLIENT-ID-END.
           EXIT.

      *===============================================================*
      * R300-JOBCARD: JOB statement, /*XEQ, and a comment that says   *
      * what it is                                                    *
      *===============================================================*
       R300-JOBCARD SECTION.
           MOVE SPACES TO W-REC
           MOVE 1 TO W-PTR
           STRING '//' W-JOBNAME ' JOB ' W-APOS 'LWD' W-APOS
                  ',CLASS=' DELIMITED BY SIZE
                  S-JOBCLASS DELIMITED BY SPACE
                  ',MSGCLASS=' DELIMITED BY SIZE
                  S-MSGCLASS DELIMITED BY SPACE
                  ',MSGLEVEL=(1,1)' DELIMITED BY SIZE
             INTO W-REC
             WITH POINTER W-PTR
      *    In mode C the statement continues with USER=
           IF MODE-CICS OF P-LLWDM920
              STRING ',' DELIMITED BY SIZE
                INTO W-REC
                WITH POINTER W-PTR
           END-IF
           PERFORM R900-ADD

           IF MODE-CICS OF P-LLWDM920
              MOVE SPACES TO W-REC
              STRING '//         USER=' W-DEPLOYUSER
                     DELIMITED BY SIZE
                INTO W-REC
              PERFORM R900-ADD
           END-IF

      *    An admin set the node (EXECNODE); JES2 sends the job there
           IF W-EXECNODE NOT = SPACES
              MOVE SPACES TO W-REC
              STRING '/*XEQ ' W-EXECNODE DELIMITED BY SIZE
                INTO W-REC
              PERFORM R900-ADD
           END-IF

           MOVE W-DEPLID TO W-DEPLID-ED
           MOVE W-JOBNO TO W-JOBNO-ED
           MOVE SPACES TO W-REC
           STRING '//* LWD DEPLOYMENT ' FUNCTION TRIM(W-DEPLID-ED)
                  ' JOB ' FUNCTION TRIM(W-JOBNO-ED)
                  ' RUN ' W-RUNID-9
                  DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-ADD
           .
       R300-JOBCARD-END.
           EXIT.

      *===============================================================*
      * R400-FROZEN-JCL: The lines of the job, as frozen at D1        *
      *===============================================================*
       R400-FROZEN-JCL SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT LINETEXT
                FROM TBLWD013
               WHERE DEPLID = :W-DEPLID
                 AND JOBNO = :W-JOBNO
               ORDER BY LINENUM
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'OPEN CURSOR' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           ELSE
              MOVE 'N' TO W-EOF
              PERFORM UNTIL W-EOF = 'Y'
                         OR RETURNCODE OF P-LLWDM920 NOT = N'00'
                 EXEC SQL
                    FETCH C1 INTO :W-LT
                 END-EXEC
                 EVALUATE SQLCODE
                 WHEN 0
                    MOVE SPACES TO W-REC
                    IF W-LT-LEN > 0
                       MOVE FUNCTION DISPLAY-OF
                            (W-LT-TEXT(1:W-LT-LEN)) TO W-REC
                    END-IF
                    PERFORM R900-ADD
                 WHEN 100
                    MOVE 'Y' TO W-EOF
                 WHEN OTHER
                    MOVE N'FETCH CURSOR' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE C1
              END-EXEC
           END-IF
           .
       R400-FROZEN-JCL-END.
           EXIT.

      *===============================================================*
      * R500-RESULT-STEPS: LWDR916 with the outcome, under IF tests.  *
      * After an abend the IF (ABEND) branch still runs.              *
      *===============================================================*
       R500-RESULT-STEPS SECTION.
           MOVE '//LWDRS    IF (ABEND) THEN' TO W-REC
           PERFORM R900-ADD
           MOVE 'A' TO W-RESULT
           PERFORM R510-RESULT-STEP

           MOVE '//         ELSE' TO W-REC
           PERFORM R900-ADD

           MOVE W-MAXRC TO W-MAXRC-ED
           MOVE SPACES TO W-REC
           STRING '//LWDRSRC  IF (RC <= ' FUNCTION TRIM(W-MAXRC-ED)
                  ') THEN' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-ADD
           MOVE 'O' TO W-RESULT
           PERFORM R510-RESULT-STEP

           MOVE '//         ELSE' TO W-REC
           PERFORM R900-ADD
           MOVE 'H' TO W-RESULT
           PERFORM R510-RESULT-STEP

           MOVE '//         ENDIF' TO W-REC
           PERFORM R900-ADD
           MOVE '//         ENDIF' TO W-REC
           PERFORM R900-ADD
           .
       R500-RESULT-STEPS-END.
           EXIT.

      *===============================================================*
      * R510-RESULT-STEP: One step that runs LWDR916 for W-RESULT.    *
      * No STEPLIB: the step runs only REXX, Java and the toolkit.    *
      * REGION=1024M: the JVM of JWTSignerUtil doesn't start in the   *
      * default region (found on t03).                                *
      *===============================================================*
       R510-RESULT-STEP SECTION.
           MOVE '//*' TO W-REC
           PERFORM R900-ADD
           
           MOVE SPACES TO W-REC
           STRING '//LWDRS' W-RESULT '   EXEC PGM=IKJEFT1B,'
                  'PARM=' W-APOS '%LWDR916 ' W-RUNID-9 ' ' W-RESULT
                  W-APOS ',REGION=1024M'
                  DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-ADD

           MOVE SPACES TO W-REC
           STRING '//SYSEXEC  DD DISP=SHR,DSN=' DELIMITED BY SIZE
                  S-EXECLIB DELIMITED BY SPACE
             INTO W-REC
           PERFORM R900-ADD

           MOVE '//SYSTSPRT DD SYSOUT=*' TO W-REC
           PERFORM R900-ADD
           MOVE '//SYSTSIN  DD DUMMY' TO W-REC
           PERFORM R900-ADD
           MOVE '//LWDCONF  DD *' TO W-REC
           PERFORM R900-ADD

           MOVE SPACES TO W-REC
           STRING 'URL=' S-LWDURL DELIMITED BY SIZE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'PORT=' S-LWDPORT DELIMITED BY SIZE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'PATH=' S-LWDPATH DELIMITED BY SIZE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'KEYRING=' S-LWDRING DELIMITED BY SIZE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'TENANT=' S-TENANT DELIMITED BY SPACE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'SCOPE=' S-APISCOPE DELIMITED BY SPACE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'CLIENTID=' S-CLIENTID DELIMITED BY SPACE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'JAVAHOME=' S-JAVAHOME DELIMITED BY SPACE INTO W-REC
           PERFORM R900-ADD
           MOVE SPACES TO W-REC
           STRING 'JWTJARS=' S-JWTJARS DELIMITED BY SPACE INTO W-REC
           PERFORM R900-ADD
           .
       R510-RESULT-STEP-END.
           EXIT.

      *===============================================================*
      * R900-ADD: Add W-REC to the records                            *
      *===============================================================*
       R900-ADD SECTION.
           IF RETURNCODE OF P-LLWDM920 = N'00'
              IF REC-COUNT OF P-LLWDM920 >= 400
                 MOVE N'08' TO RETURNCODE OF P-LLWDM920
                 MOVE N'90' TO REASONCODE OF P-LLWDM920
                 MOVE N'More than 400 JCL records' TO
                      INFOMESSAGE OF P-LLWDM920
              ELSE
                 ADD 1 TO REC-COUNT OF P-LLWDM920
                 MOVE W-REC TO REC OF P-LLWDM920
                               (REC-COUNT OF P-LLWDM920)
              END-IF
           END-IF
           .
       R900-ADD-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM920==.

       END PROGRAM LWDM920.
