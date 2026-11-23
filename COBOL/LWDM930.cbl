       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM930.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /schedulerTicks: one tick of the scheduler (S4). Called  *
      * by the scheduled job (JCL/LWDTICK, python/tick.py) under the  *
      * scheduler's userid, through its own transaction; the userid   *
      * must also be setting SCHEDUSR. Per tick:                      *
      * 1. W deployments older than APPRHRS hours become E (expired), *
      *    their jobs K, event E.                                     *
      * 2. Runs submitted more than JOBMINS minutes ago without a     *
      *    result fail with result T; runs still N (never submitted)  *
      *    after JOBMINS fail with result X. Job and deployment F     *
      *    (R660). A late result of a T run is still recorded on the  *
      *    run by the result step.                                    *
      * 3. The oldest due Q deployment whose environment is free      *
      *    starts (LWDSTRP): one per tick, as the wrapper starts one  *
      *    submit task. MOREDUE = Y when another one could start: the *
      *    caller calls again.                                        *
      * 4. Setting LASTTICK gets the time, so a stopped scheduler can *
      *    be noticed.                                                *
      * Steps 1 and 2 handle at most 50 rows per tick each.           *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 50 = Error: the userid is not setting SCHEDUSR             *
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

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.
           COPY LWDSTRW.

       01 WORK.
          05 C-MAX           PIC S9(4) COMP-5 VALUE 50.
          05 C-SCHEDUSR      PIC N(8) VALUE N'SCHEDUSR'.
          05 C-APPRHRS       PIC N(8) VALUE N'APPRHRS'.
          05 C-JOBMINS       PIC N(8) VALUE N'JOBMINS'.
          05 C-LASTTICK      PIC N(8) VALUE N'LASTTICK'.
          05 W-HOURS         PIC S9(9) COMP-5.
          05 W-MINUTES       PIC S9(9) COMP-5.
          05 W-DEPLID        PIC S9(9) COMP-5.
          05 W-RUNSTATUS     PIC N.
          05 W-COUNT         PIC S9(4) COMP-5.
          05 W-DONE          PIC X.
          05 W-MORE          PIC X.
          05 W-NOW           PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM930.
           COPY LLWDM930.
       01 P-LLWDC910.
           COPY LLWDC910.

       PROCEDURE DIVISION USING P-LLWDM930 P-LLWDC910.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R200-CHECK-SCHEDULER

           PERFORM R300-EXPIRE
           PERFORM R400-STUCK
           PERFORM R500-START-DUE
           PERFORM R600-LAST-TICK
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM930
           MOVE N'00' TO REASONCODE OF P-LLWDM930
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM930

           INITIALIZE P-LLWDC910
           MOVE '00' TO C910-RC OF P-LLWDC910
           MOVE 0 TO RUNID OF P-LLWDC910

           MOVE 0 TO EXPIREDCOUNT OF P-LLWDM930
           MOVE 0 TO STUCKCOUNT OF P-LLWDM930
           MOVE 0 TO STARTEDDEPLID OF P-LLWDM930
           MOVE C-N TO MOREDUE OF P-LLWDM930
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-CHECK-SCHEDULER: Only the userid of setting SCHEDUSR     *
      *===============================================================*
       R200-CHECK-SCHEDULER SECTION.
           MOVE SPACES TO W-SETVALUE-TEXT
           MOVE C-SCHEDUSR TO W-SETKEY
           PERFORM R091-GET-SETTING

           IF  RETURNCODE OF P-LLWDM930 = N'00'
           AND W-SETVALUE-TEXT(1:8) NOT = W-USERID
              MOVE N'08' TO RETURNCODE OF P-LLWDM930
              MOVE N'50' TO REASONCODE OF P-LLWDM930
              MOVE N'Only the scheduler''s userid may tick' TO
                   INFOMESSAGE OF P-LLWDM930
           END-IF
           .
       R200-CHECK-SCHEDULER-END.
           EXIT.

      *===============================================================*
      * R300-EXPIRE: W deployments older than APPRHRS hours become E  *
      *===============================================================*
       R300-EXPIRE SECTION.
           MOVE C-APPRHRS TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF P-LLWDM930 = N'00'
              COMPUTE W-HOURS = FUNCTION NUMVAL(FUNCTION
                 DISPLAY-OF(W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
           END-IF

           MOVE 'N' TO W-DONE
           MOVE 0 TO W-COUNT
           PERFORM UNTIL W-DONE = 'Y'
                      OR W-COUNT >= C-MAX
                      OR RETURNCODE OF P-LLWDM930 NOT = N'00'
              ADD 1 TO W-COUNT
              EXEC SQL
                 SELECT DEPLID
                   INTO :W-DEPLID
                   FROM TBLWD011
                  WHERE DEPLSTATUS = :C-W
                    AND CREATEDDATE <
                        CURRENT TIMESTAMP - :W-HOURS HOURS
                  ORDER BY DEPLID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R310-EXPIRE-ONE
              WHEN 100
                 MOVE 'Y' TO W-DONE
              WHEN OTHER
                 MOVE N'SELECT waiting' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-PERFORM
           .
       R300-EXPIRE-END.
           EXIT.

      *===============================================================*
      * R310-EXPIRE-ONE: Deployment W-DEPLID E, its jobs K, event E   *
      *===============================================================*
       R310-EXPIRE-ONE SECTION.
           EXEC SQL
              UPDATE TBLWD011
                 SET DEPLSTATUS  = :C-E,
                     ENDEDDATE   = CURRENT TIMESTAMP,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE DEPLID = :W-DEPLID
                 AND DEPLSTATUS = :C-W
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO EXPIREDCOUNT OF P-LLWDM930

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

              MOVE W-DEPLID TO W-EV-DEPLID
              MOVE C-E TO W-EV-TYPE
              MOVE SPACES TO W-EV-COMMENT-TEXT
              MOVE N'No decision within APPRHRS hours' TO
                   W-EV-COMMENT-TEXT
              MOVE 32 TO W-EV-COMMENT-LEN
              MOVE 0 TO W-EV-COMMENT-IND
              PERFORM R650-ADD-EVENT
           WHEN 100
      *       Decided meanwhile
              CONTINUE
           WHEN OTHER
              MOVE N'UPDATE deployment' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R310-EXPIRE-ONE-END.
           EXIT.

      *===============================================================*
      * R400-STUCK: Runs without a result after JOBMINS minutes fail: *
      * S with result T, N (never submitted) with result X            *
      *===============================================================*
       R400-STUCK SECTION.
           MOVE C-JOBMINS TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF P-LLWDM930 = N'00'
              COMPUTE W-MINUTES = FUNCTION NUMVAL(FUNCTION
                 DISPLAY-OF(W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
           END-IF

           MOVE 'N' TO W-DONE
           MOVE 0 TO W-COUNT
           PERFORM UNTIL W-DONE = 'Y'
                      OR W-COUNT >= C-MAX
                      OR RETURNCODE OF P-LLWDM930 NOT = N'00'
              ADD 1 TO W-COUNT
              EXEC SQL
                 SELECT RUNID,
                        RUNSTATUS
                   INTO :W-RUN-ID,
                        :W-RUNSTATUS
                   FROM TBLWD014
                  WHERE (RUNSTATUS = :C-S
                    AND  SUBMITTEDDATE <
                         CURRENT TIMESTAMP - :W-MINUTES MINUTES)
                     OR (RUNSTATUS = :C-N
                    AND  CREATEDDATE <
                         CURRENT TIMESTAMP - :W-MINUTES MINUTES)
                  ORDER BY RUNID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R410-STUCK-ONE
              WHEN 100
                 MOVE 'Y' TO W-DONE
              WHEN OTHER
                 MOVE N'SELECT stuck runs' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-PERFORM
           .
       R400-STUCK-END.
           EXIT.

      *===============================================================*
      * R410-STUCK-ONE: Run W-RUN-ID fails (R660)                     *
      *===============================================================*
       R410-STUCK-ONE SECTION.
           MOVE C-F TO W-FAIL-RUNSTATUS
           MOVE SPACES TO W-FAIL-MSG-TEXT
           IF W-RUNSTATUS = C-S
              MOVE C-T TO W-FAIL-RESULT
              MOVE N'No result within JOBMINS minutes' TO
                   W-FAIL-MSG-TEXT
              MOVE 32 TO W-FAIL-MSG-LEN
           ELSE
              MOVE C-X TO W-FAIL-RESULT
              MOVE N'Not submitted within JOBMINS minutes' TO
                   W-FAIL-MSG-TEXT
              MOVE 36 TO W-FAIL-MSG-LEN
           END-IF

           PERFORM R660-RUN-FAILED

           IF RETURNCODE OF P-LLWDM930 = N'00'
              ADD 1 TO STUCKCOUNT OF P-LLWDM930
           END-IF
           .
       R410-STUCK-ONE-END.
           EXIT.

      *===============================================================*
      * R500-START-DUE: The oldest due Q deployment with a free       *
      * environment starts; MOREDUE tells whether another could       *
      *===============================================================*
       R500-START-DUE SECTION.
           IF RETURNCODE OF P-LLWDM930 = N'00'
              EXEC SQL
                 SELECT D.DEPLID,
                        D.ENVID
                   INTO :W-ST-DEPLID,
                        :W-ST-ENVID
                   FROM TBLWD011 D
                   JOIN TBLWD006 E
                     ON E.ENVID = D.ENVID
                  WHERE D.DEPLSTATUS = :C-Q
                    AND D.STARTAFTER <= CURRENT TIMESTAMP
                    AND E.ACTIVEDEPLID IS NULL
                  ORDER BY D.STARTAFTER, D.DEPLID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R700-START-DEPLOYMENT
                 IF  RETURNCODE OF P-LLWDM930 = N'00'
                 AND W-ST-STARTED = 'Y'
                    MOVE W-ST-DEPLID TO STARTEDDEPLID OF P-LLWDM930
                 END-IF
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'SELECT due' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LLWDM930 = N'00'
              EXEC SQL
                 SELECT CASE WHEN EXISTS
                             (SELECT 1
                                FROM TBLWD011 D
                                JOIN TBLWD006 E
                                  ON E.ENVID = D.ENVID
                               WHERE D.DEPLSTATUS = :C-Q
                                 AND D.STARTAFTER <= CURRENT TIMESTAMP
                                 AND E.ACTIVEDEPLID IS NULL)
                             THEN 'Y' ELSE 'N' END
                   INTO :W-MORE
                   FROM SYSIBM.SYSDUMMY1
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT more due' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE FUNCTION NATIONAL-OF(W-MORE) TO
                      MOREDUE OF P-LLWDM930
              END-IF
           END-IF
           .
       R500-START-DUE-END.
           EXIT.

      *===============================================================*
      * R600-LAST-TICK: Setting LASTTICK = now; inserted the first    *
      * time, and after DDL/SETTINGS.sql ran again                    *
      *===============================================================*
       R600-LAST-TICK SECTION.
           IF RETURNCODE OF P-LLWDM930 = N'00'
              EXEC SQL
                 SELECT CHAR(CURRENT TIMESTAMP)
                   INTO :W-NOW
                   FROM SYSIBM.SYSDUMMY1
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT now' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM930 = N'00'
              MOVE SPACES TO W-SETVALUE-TEXT
              MOVE FUNCTION NATIONAL-OF(W-NOW) TO
                   W-SETVALUE-TEXT(1:26)
              MOVE 26 TO W-SETVALUE-LEN

              EXEC SQL
                 UPDATE TBLWD001
                    SET TABVALUE    = :W-SETVALUE,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE TABLEID = :C-SETTINGS
                    AND TABKEY = :C-LASTTICK
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 EXEC SQL
                    INSERT INTO TBLWD001
                         ( TABLEID, TABKEY, TABVALUE,
                           CREATEDBY, CREATEDDATE,
                           UPDATEDBY, UPDATEDDATE )
                    VALUES ( :C-SETTINGS, :C-LASTTICK, :W-SETVALUE,
                             :W-USERID, CURRENT TIMESTAMP,
                             :W-USERID, CURRENT TIMESTAMP )
                 END-EXEC
                 IF SQLCODE NOT = 0
                    MOVE N'INSERT LASTTICK' TO W-SQL-WHAT
                    MOVE N'12' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-IF
              WHEN OTHER
                 MOVE N'UPDATE LASTTICK' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R600-LAST-TICK-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM930==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM930==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM930==.

           COPY LWDSTRP REPLACING ==:IO:== BY ==P-LLWDM930==.

       END PROGRAM LWDM930.
