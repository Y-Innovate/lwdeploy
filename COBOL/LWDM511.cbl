       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM511.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * Actions on a deployment; LWW sets DEPLACTION per path:        *
      * C POST /cancellations/{deplID}: cancel (D3).                  *
      *   Who: the requester, or a deployer of the environment.       *
      *   When: W, Q or F, or U while no job is submitted or running. *
      *   A run not claimed by the submit task yet fails (X), so its  *
      *   token can't submit it after the cancel.                     *
      *   The app never cancels a job in JES. Effect: the deployment  *
      *   is C, jobs not run yet are K, the environment is free       *
      *   again, and after U it is marked possibly half deployed (H); *
      *   F did that already. The reason goes into the C event. When  *
      *   this frees the environment, its oldest due Q deployment     *
      *   starts (LWDSTRP).                                           *
      * T POST /retries/{deplID}: retry the failed job (D4).          *
      *   Who: a deployer. When: F. The failed job is W again and gets*
      *   a new run with the frozen JCL; the deployment is U. Event T *
      *   with the comment.                                           *
      * K POST /continuations/{deplID}: skip the failed job (D4).     *
      *   Who: a deployer. When: F. commentText, the reason, is       *
      *   required. The job is K with that reason, event K; then the  *
      *   next job is submitted, or, if none is left, the deployment  *
      *   succeeds (R670) and the environment's next Q deployment     *
      *   starts.                                                     *
      * Retry and continue use the frozen JCL, so no new approval.    *
      * At most one run goes to the wrapper (P-LLWDC910), which       *
      * starts the submit task after its commit.                      *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Deployment not found, or no role in its application   *
      * 08 01 = Error: DEPLACTION is not C, T or K                    *
      * 08 05 = Error: continue without a reason                      *
      * 08 50 = Error: not allowed: requester or deployer for C,      *
      *         deployer for T and K                                  *
      * 08 53 = Error: not possible in this status, a job is busy, or *
      *         the deployment changed meanwhile                      *
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

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.
           COPY LWDSTRW.

       01 WORK.
          05 W-DEPLID        PIC S9(9) COMP-5.
          05 W-ENVID         PIC S9(9) COMP-5.
          05 W-VERSIONID     PIC S9(9) COMP-5.
          05 W-ACTION        PIC N.
          05 W-OLD           PIC N.
          05 W-NEW           PIC N.
          05 W-BUSY          PIC X.
          05 W-ALLOWED       PIC X.
          05 W-FREED         PIC X.
          05 W-JOBNO         PIC S9(4) COMP-5.
          05 W-NEXTNO        PIC S9(4) COMP-5.
          05 W-NEXT-IND      PIC S9(4) COMP-5.
          05 W-DEPLOYERGROUP PIC N(8).
          05 W-DEPLOYERGROUP-IND PIC S9(4) COMP-5.
          05 W-NUM-ED        PIC Z(8)9.

       LINKAGE SECTION.
       01 P-LLWDM511.
           COPY LLWDM511.
       01 P-LLWDC910.
           COPY LLWDC910.

       PROCEDURE DIVISION USING P-LLWDM511 P-LLWDC910.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R200-READ

           IF RETURNCODE OF P-LLWDM511 = N'00'
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
           END-IF

           PERFORM R210-CHECK-WHO
           PERFORM R220-CHECK-STATE

           IF RETURNCODE OF P-LLWDM511 = N'00'
              EVALUATE W-ACTION
              WHEN C-C
                 PERFORM R300-CANCEL
              WHEN C-T
                 PERFORM R400-RETRY
              WHEN C-K
                 PERFORM R500-CONTINUE
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
              MOVE W-NEW TO DEPLSTATUS OF P-LLWDM511
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations and the action             *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM511
           MOVE N'00' TO REASONCODE OF P-LLWDM511
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM511

           INITIALIZE P-LLWDC910
           MOVE '00' TO C910-RC OF P-LLWDC910
           MOVE 0 TO RUNID OF P-LLWDC910

           MOVE DEPLID OF P-LLWDM511 TO W-DEPLID
           MOVE DEPLACTION OF P-LLWDM511 TO W-ACTION
           MOVE 'N' TO W-FREED

           IF  W-ACTION NOT = C-C
           AND W-ACTION NOT = C-T
           AND W-ACTION NOT = C-K
              MOVE N'08' TO RETURNCODE OF P-LLWDM511
              MOVE N'01' TO REASONCODE OF P-LLWDM511
              MOVE N'Unknown action' TO INFOMESSAGE OF P-LLWDM511
           END-IF

           IF  RETURNCODE OF P-LLWDM511 = N'00'
           AND W-ACTION = C-K
           AND COMMENTTEXT-LEN OF P-LLWDM511 < 1
              MOVE N'08' TO RETURNCODE OF P-LLWDM511
              MOVE N'05' TO REASONCODE OF P-LLWDM511
              MOVE N'commentText: a reason to skip the job is needed' TO
                   INFOMESSAGE OF P-LLWDM511
           END-IF

           IF COMMENTTEXT-LEN OF P-LLWDM511 > 0
              MOVE COMMENTTEXT OF P-LLWDM511 TO W-EV-COMMENT
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-READ: The deployment and its environment's deployer      *
      * group                                                         *
      *===============================================================*
       R200-READ SECTION.
           IF RETURNCODE OF P-LLWDM511 = N'00'
              EXEC SQL
                 SELECT D.APPID,
                        D.ENVID,
                        D.VERSIONID,
                        D.DEPLSTATUS,
                        D.CREATEDBY,
                        E.DEPLOYERGROUP
                   INTO :W-APPID,
                        :W-ENVID,
                        :W-VERSIONID,
                        :W-OLD,
                        :DCLTBLWD011.CREATEDBY,
                        :W-DEPLOYERGROUP :W-DEPLOYERGROUP-IND
                   FROM TBLWD011 D
                   JOIN TBLWD006 E
                     ON E.ENVID = D.ENVID
                  WHERE D.DEPLID = :W-DEPLID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM511
                 MOVE N'01' TO REASONCODE OF P-LLWDM511
                 MOVE N'Deployment not found' TO
                      INFOMESSAGE OF P-LLWDM511
              WHEN OTHER
                 MOVE N'SELECT deployment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-READ-END.
           EXIT.

      *===============================================================*
      * R210-CHECK-WHO: A deployer: member, and in the deployer group *
      * if the environment has one. For a cancel the requester too    *
      *===============================================================*
       R210-CHECK-WHO SECTION.
           IF RETURNCODE OF P-LLWDM511 = N'00'
              MOVE 'N' TO W-ALLOWED
              EVALUATE TRUE
              WHEN W-ACTION = C-C
               AND CREATEDBY OF DCLTBLWD011 = W-USERID
                 MOVE 'Y' TO W-ALLOWED
              WHEN W-IS-MEMBER = 'Y'
               AND W-DEPLOYERGROUP-IND < 0
                 MOVE 'Y' TO W-ALLOWED
              WHEN W-IS-MEMBER = 'Y'
                 MOVE W-DEPLOYERGROUP TO W-GROUP
                 PERFORM R096-CHECK-GROUP
                 MOVE W-IN-GROUP TO W-ALLOWED
              END-EVALUATE

              IF  RETURNCODE OF P-LLWDM511 = N'00'
              AND W-ALLOWED NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM511
                 MOVE N'50' TO REASONCODE OF P-LLWDM511
                 IF W-ACTION = C-C
                    MOVE N'Only the requester or a deployer can cancel'
                      TO INFOMESSAGE OF P-LLWDM511
                 ELSE
                    MOVE N'Only a deployer can retry or continue' TO
                         INFOMESSAGE OF P-LLWDM511
                 END-IF
              END-IF
           END-IF
           .
       R210-CHECK-WHO-END.
           EXIT.

      *===============================================================*
      * R220-CHECK-STATE: Cancel: W, Q, F, or U without a submitted   *
      * job. Retry and continue: F, and W-JOBNO is the failed job     *
      *===============================================================*
       R220-CHECK-STATE SECTION.
           IF  RETURNCODE OF P-LLWDM511 = N'00'
           AND W-ACTION = C-C
              EVALUATE W-OLD
              WHEN C-W
              WHEN C-Q
              WHEN C-F
                 CONTINUE
              WHEN C-U
                 EXEC SQL
                    SELECT CASE WHEN EXISTS
                                (SELECT 1 FROM TBLWD012 J
                                  WHERE J.DEPLID = :W-DEPLID
                                    AND J.JOBSTATUS = :C-S)
                                THEN 'Y' ELSE 'N' END
                      INTO :W-BUSY
                      FROM SYSIBM.SYSDUMMY1
                 END-EXEC
                 EVALUATE TRUE
                 WHEN SQLCODE NOT = 0
                    MOVE N'SELECT jobs' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 WHEN W-BUSY = 'Y'
                    MOVE N'08' TO RETURNCODE OF P-LLWDM511
                    MOVE N'53' TO REASONCODE OF P-LLWDM511
                    MOVE N'A job is running: wait until it ends' TO
                         INFOMESSAGE OF P-LLWDM511
                 END-EVALUATE
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM511
                 MOVE N'53' TO REASONCODE OF P-LLWDM511
                 MOVE N'The deployment has ended already' TO
                      INFOMESSAGE OF P-LLWDM511
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF P-LLWDM511 = N'00'
           AND W-ACTION NOT = C-C
              IF W-OLD NOT = C-F
                 MOVE N'08' TO RETURNCODE OF P-LLWDM511
                 MOVE N'53' TO REASONCODE OF P-LLWDM511
                 MOVE N'Only a failed deployment can go on' TO
                      INFOMESSAGE OF P-LLWDM511
              ELSE
                 EXEC SQL
                    SELECT JOBNO
                      INTO :W-JOBNO
                      FROM TBLWD012
                     WHERE DEPLID = :W-DEPLID
                       AND JOBSTATUS = :C-F
                     ORDER BY JOBNO
                     FETCH FIRST 1 ROW ONLY
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    CONTINUE
                 WHEN 100
                    MOVE N'08' TO RETURNCODE OF P-LLWDM511
                    MOVE N'53' TO REASONCODE OF P-LLWDM511
                    MOVE N'The deployment has no failed job' TO
                         INFOMESSAGE OF P-LLWDM511
                 WHEN OTHER
                    MOVE N'SELECT failed job' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-EVALUATE
              END-IF
           END-IF
           .
       R220-CHECK-STATE-END.
           EXIT.

      *===============================================================*
      * R300-CANCEL: Deployment C, waiting jobs K, environment free,  *
      * and the C event. The old status is in the WHERE, so a job     *
      * that ends at the same moment can't be overwritten unseen.     *
      * Then the environment's next due Q deployment starts.          *
      *===============================================================*
       R300-CANCEL SECTION.
           EXEC SQL
              UPDATE TBLWD011
                 SET DEPLSTATUS  = :C-C,
                     ENDEDDATE   = CURRENT TIMESTAMP,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE DEPLID = :W-DEPLID
                 AND DEPLSTATUS = :W-OLD
           END-EXEC
           PERFORM R390-CHANGED

           IF RETURNCODE OF P-LLWDM511 = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-K,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-DEPLID
                    AND JOBSTATUS = :C-W
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE jobs' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

      *    A run not claimed by the submit task yet can't be submitted
      *    any more: its token stops working
           IF  RETURNCODE OF P-LLWDM511 = N'00'
           AND W-OLD = C-U
              EXEC SQL
                 UPDATE TBLWD014
                    SET RUNSTATUS   = :C-F,
                        JOBRESULT   = :C-X,
                        JOBMESSAGE  = 'Cancelled before submission',
                        ENDEDDATE   = CURRENT TIMESTAMP,
                        JOBHASH     = NULL,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-DEPLID
                    AND RUNSTATUS = :C-N
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE new runs' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
              EXEC SQL
                 UPDATE TBLWD006
                    SET ACTIVEDEPLID = NULL,
                        ENVSTATE     = CASE WHEN :W-OLD = :C-U
                                            THEN :C-H
                                            ELSE ENVSTATE END,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE ENVID = :W-ENVID
                    AND ACTIVEDEPLID = :W-DEPLID
              END-EXEC
              EVALUATE SQLCODE
              WHEN 0
                 MOVE 'Y' TO W-FREED
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'UPDATE environment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
              MOVE W-DEPLID TO W-EV-DEPLID
              MOVE C-C TO W-EV-TYPE
              IF COMMENTTEXT-LEN OF P-LLWDM511 > 0
                 MOVE 0 TO W-EV-COMMENT-IND
              END-IF
              PERFORM R650-ADD-EVENT
              MOVE C-C TO W-NEW
           END-IF

           IF  RETURNCODE OF P-LLWDM511 = N'00'
           AND W-FREED = 'Y'
              MOVE W-ENVID TO W-ST-ENVID
              PERFORM R730-START-NEXT-QUEUED
              PERFORM R380-STARTED-MESSAGE
           END-IF
           .
       R300-CANCEL-END.
           EXIT.

      *===============================================================*
      * R380-STARTED-MESSAGE: Say which deployment was started        *
      *===============================================================*
       R380-STARTED-MESSAGE SECTION.
           IF  RETURNCODE OF P-LLWDM511 = N'00'
           AND W-ST-STARTED = 'Y'
              MOVE W-ST-DEPLID TO W-NUM-ED
              MOVE SPACES TO INFOMESSAGE OF P-LLWDM511
              STRING N'Deployment ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-NUM-ED))
                        DELIMITED BY SIZE
                     N' of this environment was started'
                        DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM511
           END-IF
           .
       R380-STARTED-MESSAGE-END.
           EXIT.

      *===============================================================*
      * R390-CHANGED: After the UPDATE of the deployment's status:    *
      * 100 means another request changed it first                    *
      *===============================================================*
       R390-CHANGED SECTION.
           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LLWDM511
              MOVE N'53' TO REASONCODE OF P-LLWDM511
              MOVE N'The deployment changed meanwhile; try again' TO
                   INFOMESSAGE OF P-LLWDM511
           WHEN OTHER
              MOVE N'UPDATE deployment' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R390-CHANGED-END.
           EXIT.

      *===============================================================*
      * R400-RETRY: Deployment U, the failed job W, event T, and a    *
      * new run of the job for the submit task                        *
      *===============================================================*
       R400-RETRY SECTION.
           PERFORM R410-BACK-TO-RUNNING

           IF RETURNCODE OF P-LLWDM511 = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-W,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-DEPLID
                    AND JOBNO  = :W-JOBNO
                    AND JOBSTATUS = :C-F
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE failed job' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
              MOVE W-DEPLID TO W-EV-DEPLID
              MOVE C-T TO W-EV-TYPE
              MOVE W-JOBNO TO W-EV-JOBNO
              MOVE 0 TO W-EV-JOBNO-IND
              IF COMMENTTEXT-LEN OF P-LLWDM511 > 0
                 MOVE 0 TO W-EV-COMMENT-IND
              END-IF
              PERFORM R650-ADD-EVENT
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
              MOVE W-DEPLID TO W-ST-DEPLID
              MOVE W-JOBNO TO W-ST-JOBNO
              PERFORM R710-SUBMIT-JOB
              MOVE C-U TO W-NEW
           END-IF
           .
       R400-RETRY-END.
           EXIT.

      *===============================================================*
      * R410-BACK-TO-RUNNING: F to U. A failed deployment keeps its   *
      * environment; check that it still does                         *
      *===============================================================*
       R410-BACK-TO-RUNNING SECTION.
           EXEC SQL
              UPDATE TBLWD011
                 SET DEPLSTATUS  = :C-U,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE DEPLID = :W-DEPLID
                 AND DEPLSTATUS = :C-F
           END-EXEC
           PERFORM R390-CHANGED

           IF RETURNCODE OF P-LLWDM511 = N'00'
              EXEC SQL
                 UPDATE TBLWD006
                    SET UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE ENVID = :W-ENVID
                    AND ACTIVEDEPLID = :W-DEPLID
              END-EXEC
              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LLWDM511
                 MOVE N'53' TO REASONCODE OF P-LLWDM511
                 MOVE N'The environment is not held by this deployment'
                   TO INFOMESSAGE OF P-LLWDM511
              WHEN OTHER
                 MOVE N'UPDATE environment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R410-BACK-TO-RUNNING-END.
           EXIT.

      *===============================================================*
      * R500-CONTINUE: The failed job K with the reason, event K;     *
      * then the next job, or the deployment succeeds                 *
      *===============================================================*
       R500-CONTINUE SECTION.
           PERFORM R410-BACK-TO-RUNNING

           IF RETURNCODE OF P-LLWDM511 = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-K,
                        SKIPREASON  = :P-LLWDM511.COMMENTTEXT,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-DEPLID
                    AND JOBNO  = :W-JOBNO
                    AND JOBSTATUS = :C-F
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE skipped job' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
              MOVE W-DEPLID TO W-EV-DEPLID
              MOVE C-K TO W-EV-TYPE
              MOVE W-JOBNO TO W-EV-JOBNO
              MOVE 0 TO W-EV-JOBNO-IND
              MOVE 0 TO W-EV-COMMENT-IND
              PERFORM R650-ADD-EVENT
           END-IF

           IF RETURNCODE OF P-LLWDM511 = N'00'
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
      *          Nothing left: the deployment succeeded
                 MOVE W-DEPLID TO W-OK-DEPLID
                 MOVE W-ENVID TO W-OK-ENVID
                 MOVE W-VERSIONID TO W-OK-VERSIONID
                 PERFORM R670-DEPL-SUCCEEDED
                 MOVE C-S TO W-NEW
                 MOVE W-ENVID TO W-ST-ENVID
                 PERFORM R730-START-NEXT-QUEUED
                 PERFORM R380-STARTED-MESSAGE
              WHEN OTHER
                 MOVE W-DEPLID TO W-ST-DEPLID
                 MOVE W-NEXTNO TO W-ST-JOBNO
                 PERFORM R710-SUBMIT-JOB
                 MOVE C-U TO W-NEW
              END-EVALUATE
           END-IF
           .
       R500-CONTINUE-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM511==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM511==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM511==.

           COPY LWDSTRP REPLACING ==:IO:== BY ==P-LLWDM511==.

       END PROGRAM LWDM511.
