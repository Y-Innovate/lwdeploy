       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM514.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /admin/stuckRuns/{runID} (A4): an administrator marks a  *
      * submitted run stuck, when its job ended in JES but its result *
      * step never reported. Only a run that is S: it then fails as   *
      * LWDM930 fails it after JOBMINS (R660-RUN-FAILED of LWDDEPP):  *
      * run F with result T and the message "Marked stuck by <user>", *
      * its job F, the deployment F, event F with the same comment.   *
      * The run row is locked first, so a result step that reports at *
      * the same moment either comes first (08 53) or waits.          *
      * The output collector still collects the run's output: LWDM940 *
      * lists E and F runs.                                           *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 21/32 = Error: SQL error                                   *
      * 08 31 = Error: run not found                                  *
      * 08 50 = Error: not an administrator                           *
      * 08 53 = Error: the run isn't submitted (any more)             *
      * And the codes of LWDCTXP and LWDDEPP                          *
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

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.

       01 WORK.
          05 W-RUNID       PIC S9(9) COMP-5.
          05 W-RUNID-ED    PIC Z(8)9.

       LINKAGE SECTION.
       01 P-LLWDM514.
           COPY LLWDM514.

       PROCEDURE DIVISION USING P-LLWDM514.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R098-REQUIRE-ADMIN

           PERFORM R200-LOCK-RUN
           PERFORM R300-FAIL-RUN
           PERFORM R800-SELECT
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM514
           MOVE N'00' TO REASONCODE OF P-LLWDM514
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM514

           MOVE RUNID OF P-LLWDM514 TO W-RUNID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LOCK-RUN: Lock the run while it is S; otherwise 08 31    *
      * (no such run) or 08 53 (not submitted)                        *
      *===============================================================*
       R200-LOCK-RUN SECTION.
           IF RETURNCODE OF P-LLWDM514 = N'00'
              EXEC SQL
                 UPDATE TBLWD014
                    SET UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUNID
                    AND RUNSTATUS = :C-S
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 PERFORM R210-WHY-NOT
              WHEN OTHER
                 MOVE N'UPDATE run' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-LOCK-RUN-END.
           EXIT.

      *===============================================================*
      * R210-WHY-NOT: The run doesn't exist, or isn't S               *
      *===============================================================*
       R210-WHY-NOT SECTION.
           EXEC SQL
              SELECT RUNSTATUS
                INTO :DCLTBLWD014.RUNSTATUS
                FROM TBLWD014
               WHERE RUNID = :W-RUNID
           END-EXEC

           MOVE W-RUNID TO W-RUNID-ED
           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM514
              MOVE N'53' TO REASONCODE OF P-LLWDM514
              STRING N'Run ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-RUNID-ED))
                        DELIMITED BY SIZE
                     N' isn''t submitted any more: nothing changed'
                        DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM514
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LLWDM514
              MOVE N'31' TO REASONCODE OF P-LLWDM514
              MOVE N'Run not found' TO INFOMESSAGE OF P-LLWDM514
           WHEN OTHER
              MOVE N'SELECT run' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R210-WHY-NOT-END.
           EXIT.

      *===============================================================*
      * R300-FAIL-RUN: As the scheduler's stuck branch, with the      *
      * administrator in the message                                  *
      *===============================================================*
       R300-FAIL-RUN SECTION.
           IF RETURNCODE OF P-LLWDM514 = N'00'
              MOVE W-RUNID TO W-RUN-ID
              MOVE C-F TO W-FAIL-RUNSTATUS
              MOVE C-T TO W-FAIL-RESULT
              MOVE SPACES TO W-FAIL-MSG-TEXT
              MOVE 1 TO W-FAIL-MSG-LEN
              STRING N'Marked stuck by ' DELIMITED BY SIZE
                     W-USERID DELIMITED BY N' '
                INTO W-FAIL-MSG-TEXT
                WITH POINTER W-FAIL-MSG-LEN
              SUBTRACT 1 FROM W-FAIL-MSG-LEN
              PERFORM R660-RUN-FAILED
           END-IF
           .
       R300-FAIL-RUN-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The run and its deployment as the response       *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM514 = N'00'
              EXEC SQL
                 SELECT R.RUNID,
                        R.RUNSTATUS,
                        R.JOBRESULT,
                        D.DEPLID,
                        D.DEPLSTATUS
                   INTO :DCLTBLWD014.RUNID,
                        :DCLTBLWD014.RUNSTATUS,
                        :DCLTBLWD014.JOBRESULT
                           :DCLTBLWD014.JOBRESULT-IND,
                        :DCLTBLWD011.DEPLID,
                        :DCLTBLWD011.DEPLSTATUS
                   FROM TBLWD014 R
                   JOIN TBLWD011 D
                     ON D.DEPLID = R.DEPLID
                  WHERE R.RUNID = :W-RUNID
              END-EXEC

              IF SQLCODE = 0
                 MOVE RUNID OF DCLTBLWD014 TO RUNID OF P-LLWDM514
                 MOVE RUNSTATUS OF DCLTBLWD014 TO
                      RUNSTATUS OF P-LLWDM514
                 MOVE JOBRESULT OF DCLTBLWD014 TO
                      JOBRESULT OF P-LLWDM514
                 MOVE DEPLID OF DCLTBLWD011 TO DEPLID OF P-LLWDM514
                 MOVE DEPLSTATUS OF DCLTBLWD011 TO
                      DEPLSTATUS OF P-LLWDM514
              ELSE
                 MOVE N'SELECT run' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R800-SELECT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM514==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM514==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM514==.

       END PROGRAM LWDM514.
