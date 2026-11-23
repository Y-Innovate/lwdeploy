       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM916.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /jobResults: the result of a run (S2), sent by the       *
      * result step at the end of every deployment job (REXX LWDR916, *
      * with an Entra access token of the deploy userid), through     *
      * its own transaction. LWDM920 puts the step there three times, *
      * under JCL IF tests, so the result is:                         *
      *   O = within the job's highest RC                             *
      *   H = above it                                                *
      *   A = a step abended                                          *
      * Only the deploy userid of the deployment may send it, only    *
      * for the job name of the run, and only once (the run must be   *
      * S). Then:                                                     *
      *   O: job D. If another job waits, it gets a run with a token, *
      *      handed to the wrapper, which starts the submit task      *
      *      after the commit, as for the first job (S1). Otherwise   *
      *      the deployment is S, the inventory is updated, the       *
      *      environment is free, and its oldest due Q deployment     *
      *      starts (LWDSTRP R730).                                   *
      *   H, A: run ended, job and deployment F, environment H; the   *
      *      deployment keeps the environment (R660).                 *
      * A late result: the scheduler (LWDM930) set the run F with     *
      * result T because it took longer than JOBMINS. Its outcome is  *
      * still recorded on the run, but nothing else changes: the      *
      * deployment may have been retried, continued or cancelled.     *
      * The JES job ID is recorded too, as the result step sees it:   *
      * on another node it is that node's.                            *
      * Replaces LWDM915, the batch result step, which wrote to DB2   *
      * under the deploy userid and submitted the next job itself.    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Recorded                                              *
      * 00 01 = A late result, recorded on the run only               *
      * 04 01 = Run not found                                         *
      * 08 01 = Error: jobResult is not O, H or A                     *
      * 08 50 = Error: not the deploy userid of the deployment, or    *
      *         not the job name of the run                           *
      * 08 53 = Error: the run was recorded already, or is not        *
      *         submitted                                             *
      * And the codes of LWDCTXP, LWDDEPP and LWDSTRP                 *
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

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.
           COPY LWDSTRW.

       01 WORK.
          05 W-RUNID         PIC S9(9) COMP-5.
          05 W-RESULT        PIC N.
          05 W-JOBNAME       PIC N(8).
          05 W-JOBID         PIC N(8).
          05 W-JOBID-IND     PIC S9(4) COMP-5.
          05 W-RUN-JOBNAME-DB PIC N(8).
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
          05 W-DEPLOYUSER    PIC N(8).

       LINKAGE SECTION.
       01 P-LLWDM916.
           COPY LLWDM916.
       01 P-LLWDC910.
           COPY LLWDC910.

       PROCEDURE DIVISION USING P-LLWDM916 P-LLWDC910.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID
           PERFORM R050-CHECK-INPUT
           PERFORM R100-READ-RUN

           IF RETURNCODE OF P-LLWDM916 = N'00'
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

           PERFORM R900-RESULT
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM916
           MOVE N'00' TO REASONCODE OF P-LLWDM916
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM916

           INITIALIZE P-LLWDC910
           MOVE '00' TO C910-RC OF P-LLWDC910
           MOVE 0 TO RUNID OF P-LLWDC910

           MOVE SPACES TO RUNSTATUS OF P-LLWDM916
           MOVE SPACES TO DEPLSTATUS OF P-LLWDM916
           MOVE 0 TO NEXTRUNID OF P-LLWDM916
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R050-CHECK-INPUT: The result, the job name and JES job ID     *
      *===============================================================*
       R050-CHECK-INPUT SECTION.
           IF RETURNCODE OF P-LLWDM916 = N'00'
              MOVE RUNID OF P-LLWDM916 TO W-RUNID
              MOVE JOBRESULT OF P-LLWDM916 TO W-RESULT
              MOVE JOBNAME OF P-LLWDM916 TO W-JOBNAME
              MOVE JESJOBID OF P-LLWDM916 TO W-JOBID
      *       LWW leaves the rest of a short or missing field X'00'
              INSPECT W-JOBNAME REPLACING ALL NX'0000' BY N' '
              INSPECT W-JOBID REPLACING ALL NX'0000' BY N' '

      *       Not sent: the run keeps the JES job ID it has
              IF W-JOBID = SPACES
                 MOVE -1 TO W-JOBID-IND
              ELSE
                 MOVE 0 TO W-JOBID-IND
              END-IF

              IF  W-RESULT NOT = C-O
              AND W-RESULT NOT = C-H
              AND W-RESULT NOT = C-A
                 MOVE N'08' TO RETURNCODE OF P-LLWDM916
                 MOVE N'01' TO REASONCODE OF P-LLWDM916
                 MOVE N'jobResult must be O, H or A' TO
                      INFOMESSAGE OF P-LLWDM916
              END-IF
           END-IF
           .
       R050-CHECK-INPUT-END.
           EXIT.

      *===============================================================*
      * R100-READ-RUN: The run must be of this job, under the deploy  *
      * userid of its deployment, and submitted                       *
      *===============================================================*
       R100-READ-RUN SECTION.
           IF RETURNCODE OF P-LLWDM916 = N'00'
              EXEC SQL
                 SELECT R.DEPLID,
                        R.JOBNO,
                        R.JOBNAME,
                        R.RUNSTATUS,
                        R.JOBRESULT,
                        D.DEPLOYUSER,
                        D.DEPLSTATUS,
                        D.ENVID,
                        D.VERSIONID
                   INTO :W-DEPLID,
                        :W-JOBNO,
                        :W-RUN-JOBNAME-DB,
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
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 EVALUATE TRUE
                 WHEN W-DEPLOYUSER NOT = W-USERID
                    MOVE N'08' TO RETURNCODE OF P-LLWDM916
                    MOVE N'50' TO REASONCODE OF P-LLWDM916
                    MOVE N'Not the deploy userid of this deployment'
                      TO INFOMESSAGE OF P-LLWDM916
                 WHEN W-RUN-JOBNAME-DB NOT = W-JOBNAME
                    MOVE N'08' TO RETURNCODE OF P-LLWDM916
                    MOVE N'50' TO REASONCODE OF P-LLWDM916
                    MOVE N'Not the job name of this run' TO
                         INFOMESSAGE OF P-LLWDM916
                 WHEN W-RUNSTATUS = C-F
                  AND W-OLDRESULT-IND >= 0
                  AND W-OLDRESULT = C-T
                    MOVE 'Y' TO W-LATE
                 WHEN W-RUNSTATUS NOT = C-S
                    MOVE N'08' TO RETURNCODE OF P-LLWDM916
                    MOVE N'53' TO REASONCODE OF P-LLWDM916
                    MOVE N'Run recorded already, or not submitted'
                      TO INFOMESSAGE OF P-LLWDM916
                 END-EVALUATE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM916
                 MOVE N'01' TO REASONCODE OF P-LLWDM916
                 MOVE N'Run not found' TO INFOMESSAGE OF P-LLWDM916
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
                 SET JESJOBID    = COALESCE(:W-JOBID :W-JOBID-IND,
                                            JESJOBID),
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

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
      *       Recorded meanwhile, by a second call
              MOVE N'08' TO RETURNCODE OF P-LLWDM916
              MOVE N'53' TO REASONCODE OF P-LLWDM916
              MOVE N'The run was recorded meanwhile' TO
                   INFOMESSAGE OF P-LLWDM916
           WHEN OTHER
              MOVE N'UPDATE run' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R200-RECORD-END.
           EXIT.

      *===============================================================*
      * R250-LATE-RESULT: The run was set F/T by the scheduler; only  *
      * the run gets the real outcome. 00 01                          *
      *===============================================================*
       R250-LATE-RESULT SECTION.
           EXEC SQL
              UPDATE TBLWD014
                 SET JESJOBID    = COALESCE(:W-JOBID :W-JOBID-IND,
                                            JESJOBID),
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
              MOVE N'01' TO REASONCODE OF P-LLWDM916
              MOVE N'Late result: recorded on the run only' TO
                   INFOMESSAGE OF P-LLWDM916
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LLWDM916
              MOVE N'53' TO REASONCODE OF P-LLWDM916
              MOVE N'The run was recorded meanwhile' TO
                   INFOMESSAGE OF P-LLWDM916
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
           IF RETURNCODE OF P-LLWDM916 = N'00'
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
           IF  RETURNCODE OF P-LLWDM916 = N'00'
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
      * R310-SUCCEEDED: Deployment S, inventory, environment free;    *
      * then the oldest due Q deployment of the environment starts    *
      *===============================================================*
       R310-SUCCEEDED SECTION.
           MOVE W-DEPLID TO W-OK-DEPLID
           MOVE W-ENVID TO W-OK-ENVID
           MOVE W-VERSIONID TO W-OK-VERSIONID
           PERFORM R670-DEPL-SUCCEEDED

           MOVE W-ENVID TO W-ST-ENVID
           PERFORM R730-START-NEXT-QUEUED
           .
       R310-SUCCEEDED-END.
           EXIT.

      *===============================================================*
      * R320-SUBMIT-NEXT: A run of job W-NEXTNO with a token, for the *
      * submit task that the wrapper starts after the commit          *
      *===============================================================*
       R320-SUBMIT-NEXT SECTION.
           MOVE W-DEPLID TO W-ST-DEPLID
           MOVE W-ENVID TO W-ST-ENVID
           MOVE W-NEXTNO TO W-ST-JOBNO
           PERFORM R710-SUBMIT-JOB
           MOVE RUNID OF P-LLWDC910 TO NEXTRUNID OF P-LLWDM916
           .
       R320-SUBMIT-NEXT-END.
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

      *===============================================================*
      * R900-RESULT: The run and the deployment, as they are now      *
      *===============================================================*
       R900-RESULT SECTION.
           IF RETURNCODE OF P-LLWDM916 = N'00'
              EXEC SQL
                 SELECT R.RUNSTATUS,
                        D.DEPLSTATUS
                   INTO :W-RUNSTATUS,
                        :W-DEPLSTATUS
                   FROM TBLWD014 R
                   JOIN TBLWD011 D
                     ON D.DEPLID = R.DEPLID
                  WHERE R.RUNID = :W-RUNID
              END-EXEC

              IF SQLCODE = 0
                 MOVE W-RUNSTATUS TO RUNSTATUS OF P-LLWDM916
                 MOVE W-DEPLSTATUS TO DEPLSTATUS OF P-LLWDM916
              ELSE
                 MOVE N'SELECT result' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

      *    Nothing for the submit task after an error: it is rolled
      *    back
           IF RETURNCODE OF P-LLWDM916 NOT = N'00'
              MOVE 0 TO RUNID OF P-LLWDC910
              MOVE 0 TO NEXTRUNID OF P-LLWDM916
           END-IF
           .
       R900-RESULT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM916==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM916==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM916==.

           COPY LWDSTRP REPLACING ==:IO:== BY ==P-LLWDM916==.

       END PROGRAM LWDM916.
