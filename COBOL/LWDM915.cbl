       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM915.
      *===============================================================*
      * This program is a DB2 batch program of the LWD application:   *
      * the result step, the last step of every deployment job (S2),  *
      * until iteration 4. Since then LWDM920 puts REXX LWDR916 there,*
      * which sends the result to POST /jobResults (LWDM916). This    *
      * one stays for jobs submitted before, until none runs; the     *
      * job it submits next already has the new result step.          *
      * LWDM920 puts it there three times, under JCL IF tests, so it  *
      * learns the outcome from SYSIN, not the exact return codes:    *
      *   O = within the job's highest RC                             *
      *   H = above it                                                *
      *   A = a step abended                                          *
      * It only accepts a run of its own job, under the deploy userid *
      * of the deployment, and only once (the run must be S): the job *
      * name and userid come from LWDA990. Then:                      *
      *   O: job D. If another job waits, a new run of it is written  *
      *      to the internal reader (DD INTRDR, only in the O step),  *
      *      with the JCL of LWDM920, without USER=: it runs under    *
      *      the deploy userid that submits it (M9). Otherwise the    *
      *      deployment is S, the inventory is updated and the        *
      *      environment is free.                                     *
      *   H, A: run ended, job and deployment F, environment H; the   *
      *      deployment keeps the environment (R660).                 *
      * A late result: the scheduler (LWDM930) set the run F with     *
      * result T because it took longer than JOBMINS. Its outcome is  *
      * still recorded on the run, but nothing else changes: the      *
      * deployment may have been retried, continued or cancelled.     *
      * The JES job ID is recorded too. Static SQL, so the deploy     *
      * userid only needs the plan. Linked with DSNELI and LWDM920:   *
      * run it with DSN RUN under IKJEFT1B.                           *
      * ------------------------------------------------------------- *
      * Input: one record on SYSIN                                    *
      * Col 1-9 = RUNID, with leading zeros                           *
      * Col 11  = O, H or A                                           *
      * ------------------------------------------------------------- *
      * Output: RETURN-CODE                                           *
      *  0 = Recorded                                                 *
      *  4 = The run was recorded already, or is not submitted, or a  *
      *      late result was recorded on the run only                 *
      *  8 = Invalid input, not this job's run, or an error; rolled   *
      *      back. See SYSOUT                                         *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CARDS ASSIGN TO SYSIN
                  FILE STATUS IS W-FS.
           SELECT INTRDR ASSIGN TO INTRDR
                  FILE STATUS IS W-FS2.

       DATA DIVISION.
       FILE SECTION.
       FD CARDS
           RECORDING MODE F.
       01 CARD-REC        PIC X(80).
       FD INTRDR
           RECORDING MODE F.
       01 INTRDR-REC      PIC X(80).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.

       01 W-IO.
          05 RETURNCODE      PIC N(02).
          05 REASONCODE      PIC N(02).
          05 INFOMESSAGE     PIC N(72).

       01 WORK.
          05 W-FS            PIC XX.
          05 W-FS2           PIC XX.
          05 W-CARD.
             10 W-CARD-RUNID  PIC X(9).
             10 FILLER        PIC X.
             10 W-CARD-RESULT PIC X.
             10 FILLER        PIC X(69).
          05 W-RC            PIC S9(4) COMP-5 VALUE 0.
          05 W-RUNID         PIC S9(9) COMP-5.
          05 W-RESULT        PIC N.
          05 W-DEPLID        PIC S9(9) COMP-5.
          05 W-JOBNO         PIC S9(4) COMP-5.
          05 W-NEXTNO        PIC S9(4) COMP-5.
          05 W-NEXT-IND      PIC S9(4) COMP-5.
          05 W-ENVID         PIC S9(9) COMP-5.
          05 W-VERSIONID     PIC S9(9) COMP-5.
          05 W-RUNSTATUS     PIC N.
          05 W-OLDRESULT     PIC N.
          05 W-OLDRESULT-IND PIC S9(4) COMP-5.
          05 W-LATE          PIC X VALUE 'N'.
          05 W-DEPLSTATUS    PIC N.
          05 W-JOBNAME       PIC N(8).
          05 W-DEPLOYUSER    PIC N(8).
          05 W-JOBID         PIC N(8).
          05 W-I             PIC S9(4) COMP-5.
          05 W-MSG           PIC X(72).

       01 W-LLWDM920.
           COPY LLWDM920.

       PROCEDURE DIVISION.
       MAIN SECTION.
           MOVE N'00' TO RETURNCODE OF W-IO
           MOVE N'00' TO REASONCODE OF W-IO
           MOVE SPACES TO INFOMESSAGE OF W-IO

           PERFORM R010-READ-CARD
           IF W-RC = 0
              PERFORM R090-GET-USERID
              PERFORM R100-READ-RUN
           END-IF

           IF W-RC = 0 AND RETURNCODE OF W-IO = N'00'
              IF W-LATE = 'Y'
                 PERFORM R250-LATE-RESULT
              ELSE
                 PERFORM R200-RECORD
                 IF W-RESULT = C-O
                    PERFORM R300-JOB-DONE
                 ELSE
                    PERFORM R400-JOB-FAILED
                 END-IF
              END-IF
           END-IF

           IF RETURNCODE OF W-IO NOT = N'00'
              DISPLAY 'LWDM915 RUN ' W-CARD-RUNID ' '
                      FUNCTION DISPLAY-OF(RETURNCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(REASONCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(INFOMESSAGE OF W-IO)
              IF W-RC < 8
                 MOVE 8 TO W-RC
              END-IF
           END-IF

           IF W-RC < 8
              EXEC SQL COMMIT END-EXEC
           ELSE
              EXEC SQL ROLLBACK END-EXEC
           END-IF

           MOVE W-RC TO RETURN-CODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R010-READ-CARD: RUNID and result from SYSIN                   *
      *===============================================================*
       R010-READ-CARD SECTION.
           OPEN INPUT CARDS
           IF W-FS NOT = '00'
              DISPLAY 'LWDM915 OPEN SYSIN FILE STATUS ' W-FS
              MOVE 8 TO W-RC
           ELSE
              READ CARDS INTO W-CARD
              IF W-FS NOT = '00'
                 DISPLAY 'LWDM915 READ SYSIN FILE STATUS ' W-FS
                 MOVE 8 TO W-RC
              END-IF
              CLOSE CARDS
           END-IF

           IF W-RC = 0
              IF  W-CARD-RUNID IS NUMERIC
              AND (W-CARD-RESULT = 'O' OR 'H' OR 'A')
                 MOVE W-CARD-RUNID TO W-RUNID
                 MOVE FUNCTION NATIONAL-OF(W-CARD-RESULT) TO W-RESULT
              ELSE
                 DISPLAY 'LWDM915 INVALID INPUT ' W-CARD(1:11)
                 MOVE 8 TO W-RC
              END-IF
           END-IF
           .
       R010-READ-CARD-END.
           EXIT.

      *===============================================================*
      * R100-READ-RUN: The run must be of this job, under the deploy  *
      * userid of its deployment, and submitted                       *
      *===============================================================*
       R100-READ-RUN SECTION.
           IF RETURNCODE OF W-IO = N'00'
              MOVE JOBNAME OF W-LLWDA990 TO W-JOBNAME
              MOVE JOBID OF W-LLWDA990 TO W-JOBID

              EXEC SQL
                 SELECT R.DEPLID,
                        R.JOBNO,
                        R.RUNSTATUS,
                        R.JOBRESULT,
                        D.DEPLOYUSER,
                        D.DEPLSTATUS,
                        D.ENVID,
                        D.VERSIONID
                   INTO :W-DEPLID,
                        :W-JOBNO,
                        :W-RUNSTATUS,
                        :W-OLDRESULT :W-OLDRESULT-IND,
                        :W-DEPLOYUSER,
                        :W-DEPLSTATUS,
                        :W-ENVID,
                        :W-VERSIONID
                   FROM TBLWD014 R
                   JOIN TBLWD011 D
                     ON D.DEPLID = R.DEPLID
                  WHERE R.RUNID = :W-RUNID
                    AND R.JOBNAME = :W-JOBNAME
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 EVALUATE TRUE
                 WHEN W-DEPLOYUSER NOT = W-USERID
                    MOVE N'08' TO RETURNCODE OF W-IO
                    MOVE N'50' TO REASONCODE OF W-IO
                    MOVE N'Not the deploy userid of this deployment'
                      TO INFOMESSAGE OF W-IO
                 WHEN W-RUNSTATUS = C-F
                  AND W-OLDRESULT-IND >= 0
                  AND W-OLDRESULT = C-T
                    MOVE 'Y' TO W-LATE
                 WHEN W-RUNSTATUS NOT = C-S
                    DISPLAY 'LWDM915 RUN ' W-CARD-RUNID
                            ' IS RECORDED ALREADY OR NOT SUBMITTED'
                    MOVE 4 TO W-RC
                 END-EVALUATE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF W-IO
                 MOVE N'50' TO REASONCODE OF W-IO
                 MOVE N'No such run for this job name' TO
                      INFOMESSAGE OF W-IO
              WHEN OTHER
                 MOVE N'SELECT run' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R100-READ-RUN-END.
           EXIT.

      *===============================================================*
      * R200-RECORD: The JES job ID, and for O the end of the run     *
      *===============================================================*
       R200-RECORD SECTION.
           EXEC SQL
              UPDATE TBLWD014
                 SET JESJOBID    = :W-JOBID,
                     RUNSTATUS   = CASE WHEN :W-RESULT = :C-O
                                        THEN :C-E ELSE RUNSTATUS END,
                     JOBRESULT   = CASE WHEN :W-RESULT = :C-O
                                        THEN :C-O ELSE JOBRESULT END,
                     ENDEDDATE   = CURRENT TIMESTAMP,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE RUNID = :W-RUNID
                 AND RUNSTATUS = :C-S
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'UPDATE run' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R200-RECORD-END.
           EXIT.

      *===============================================================*
      * R250-LATE-RESULT: The run was set F/T by the scheduler; only  *
      * the run gets the real outcome. RETURN-CODE 4                  *
      *===============================================================*
       R250-LATE-RESULT SECTION.
           EXEC SQL
              UPDATE TBLWD014
                 SET JESJOBID    = :W-JOBID,
                     RUNSTATUS   = :C-E,
                     JOBRESULT   = :W-RESULT,
                     ENDEDDATE   = CURRENT TIMESTAMP,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE RUNID = :W-RUNID
                 AND RUNSTATUS = :C-F
                 AND JOBRESULT = :C-T
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              DISPLAY 'LWDM915 RUN ' W-CARD-RUNID
                      ' LATE RESULT RECORDED ON THE RUN ONLY'
              MOVE 4 TO W-RC
           WHEN 100
              DISPLAY 'LWDM915 RUN ' W-CARD-RUNID
                      ' IS RECORDED ALREADY'
              MOVE 4 TO W-RC
           WHEN OTHER
              MOVE N'UPDATE late run' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R250-LATE-RESULT-END.
           EXIT.

      *===============================================================*
      * R300-JOB-DONE: Job D; then the next job, or the end           *
      *===============================================================*
       R300-JOB-DONE SECTION.
           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-D,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-DEPLID
                    AND JOBNO  = :W-JOBNO
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE job' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

      *    Only a running deployment goes on
           IF  RETURNCODE OF W-IO = N'00'
           AND W-DEPLSTATUS = C-U
              EXEC SQL
                 SELECT MIN(JOBNO)
                   INTO :W-NEXTNO :W-NEXT-IND
                   FROM TBLWD012
                  WHERE DEPLID = :W-DEPLID
                    AND JOBNO > :W-JOBNO
                    AND JOBSTATUS = :C-W
              END-EXEC

              EVALUATE TRUE
              WHEN SQLCODE NOT = 0
                 MOVE N'SELECT next job' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              WHEN W-NEXT-IND < 0
                 PERFORM R310-SUCCEEDED
              WHEN OTHER
                 PERFORM R320-SUBMIT-NEXT
              END-EVALUATE
           END-IF
           .
       R300-JOB-DONE-END.
           EXIT.

      *===============================================================*
      * R310-SUCCEEDED: Deployment S, inventory, environment free     *
      *===============================================================*
       R310-SUCCEEDED SECTION.
           MOVE W-DEPLID TO W-OK-DEPLID
           MOVE W-ENVID TO W-OK-ENVID
           MOVE W-VERSIONID TO W-OK-VERSIONID
           PERFORM R670-DEPL-SUCCEEDED
           .
       R310-SUCCEEDED-END.
           EXIT.

      *===============================================================*
      * R320-SUBMIT-NEXT: A run of job W-NEXTNO, committed first, then*
      * written to the internal reader. If that fails, the run fails  *
      *===============================================================*
       R320-SUBMIT-NEXT SECTION.
           MOVE SPACES TO W-MSG
           MOVE W-DEPLID TO W-RUN-DEPLID
           MOVE W-NEXTNO TO W-RUN-JOBNO
           MOVE 'N' TO W-RUN-WITH-TOKEN
           PERFORM R600-NEW-RUN

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL COMMIT END-EXEC

              INITIALIZE W-LLWDM920
              MOVE W-RUN-ID TO RUNID OF W-LLWDM920
              SET MODE-BATCH OF W-LLWDM920 TO TRUE
              CALL 'LWDM920' USING W-LLWDM920

              IF RETURNCODE OF W-LLWDM920 = N'00'
                 PERFORM R330-WRITE-INTRDR
              ELSE
                 MOVE FUNCTION DISPLAY-OF(INFOMESSAGE OF W-LLWDM920)
                   TO W-MSG
              END-IF

              IF W-MSG = SPACES
                 EXEC SQL
                    UPDATE TBLWD014
                       SET RUNSTATUS     = :C-S,
                           SUBMITTEDDATE = CURRENT TIMESTAMP,
                           UPDATEDBY     = :W-USERID,
                           UPDATEDDATE   = CURRENT TIMESTAMP
                     WHERE RUNID = :W-RUN-ID
                       AND RUNSTATUS = :C-N
                 END-EXEC
                 IF SQLCODE NOT = 0
                    MOVE N'UPDATE next run' TO W-SQL-WHAT
                    MOVE N'32' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-IF
                 IF RETURNCODE OF W-IO = N'00'
                    EXEC SQL
                       UPDATE TBLWD012
                          SET JOBSTATUS   = :C-S,
                              UPDATEDBY   = :W-USERID,
                              UPDATEDDATE = CURRENT TIMESTAMP
                        WHERE DEPLID = :W-DEPLID
                          AND JOBNO  = :W-NEXTNO
                    END-EXEC
                    IF SQLCODE NOT = 0
                       MOVE N'UPDATE next job' TO W-SQL-WHAT
                       MOVE N'32' TO W-SQL-REASON
                       PERFORM R890-SQL-ERROR
                    END-IF
                 END-IF
              ELSE
                 DISPLAY 'LWDM915 RUN ' W-RUN-ID ' NOT SUBMITTED: '
                         W-MSG
                 MOVE C-F TO W-FAIL-RUNSTATUS
                 MOVE C-X TO W-FAIL-RESULT
                 MOVE FUNCTION NATIONAL-OF(W-MSG) TO W-FAIL-MSG-TEXT
                 MOVE 72 TO W-FAIL-MSG-LEN
                 PERFORM R660-RUN-FAILED
              END-IF
           END-IF
           .
       R320-SUBMIT-NEXT-END.
           EXIT.

      *===============================================================*
      * R330-WRITE-INTRDR: The records of LWDM920; the job is         *
      * submitted when the file is closed. W-MSG says what failed     *
      *===============================================================*
       R330-WRITE-INTRDR SECTION.
           MOVE SPACES TO W-MSG
           OPEN OUTPUT INTRDR
           IF W-FS2 NOT = '00'
              STRING 'OPEN INTRDR FILE STATUS ' W-FS2
                     DELIMITED BY SIZE INTO W-MSG
           ELSE
              PERFORM VARYING W-I FROM 1 BY 1
                        UNTIL W-I > REC-COUNT OF W-LLWDM920
                           OR W-MSG NOT = SPACES
                 WRITE INTRDR-REC FROM REC OF W-LLWDM920(W-I)
                 IF W-FS2 NOT = '00'
                    STRING 'WRITE INTRDR FILE STATUS ' W-FS2
                           DELIMITED BY SIZE INTO W-MSG
                 END-IF
              END-PERFORM
              CLOSE INTRDR
              IF W-FS2 NOT = '00' AND W-MSG = SPACES
                 STRING 'CLOSE INTRDR FILE STATUS ' W-FS2
                        DELIMITED BY SIZE INTO W-MSG
              END-IF
           END-IF
           .
       R330-WRITE-INTRDR-END.
           EXIT.

      *===============================================================*
      * R400-JOB-FAILED: H or A: run ended badly, job and deployment F*
      *===============================================================*
       R400-JOB-FAILED SECTION.
           MOVE W-RUNID TO W-RUN-ID
           MOVE C-E TO W-FAIL-RUNSTATUS
           MOVE W-RESULT TO W-FAIL-RESULT
           MOVE SPACES TO W-FAIL-MSG-TEXT
           IF W-RESULT = C-A
              MOVE N'A step abended' TO W-FAIL-MSG-TEXT
              MOVE 14 TO W-FAIL-MSG-LEN
           ELSE
              MOVE N'A step ended above the highest RC' TO
                   W-FAIL-MSG-TEXT
              MOVE 33 TO W-FAIL-MSG-LEN
           END-IF
           PERFORM R660-RUN-FAILED
           .
       R400-JOB-FAILED-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==W-IO==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==W-IO==.

           COPY LWDMALP REPLACING ==:IO:== BY ==W-IO==.

       END PROGRAM LWDM915.
