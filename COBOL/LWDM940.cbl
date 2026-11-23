       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM940.
      *===============================================================*
      * This program is a DB2 batch program of the LWD application:   *
      * step OUTLIST of JCL/LWDTICK, before the output collector      *
      * (S3: REXX LWDR941, then LWDM945). Under the scheduler's       *
      * userid. In order:                                             *
      * 1. Purge (S4): the spool files and lines of runs that ended   *
      *    more than OUTDAYS days ago are deleted, the run gets       *
      *    OUTPUTSTATUS P. The run and its steps stay. At most 50     *
      *    runs per call, a commit after each. Sent and failed mails  *
      *    older than OUTDAYS are deleted too (S5).                   *
      * 2. Runs that never reached JES (result X: the submit failed,  *
      *    or cancelled before submission) get OUTPUTSTATUS N.        *
      * 3. The runs whose output is still to be collected: ended or   *
      *    failed, OUTPUTSTATUS W. At most 20 per call, oldest first, *
      *    to DD OUTLIST, for LWDR941.                                *
      * Static SQL, so the userid only needs the plan. Linked with    *
      * DSNELI: run it with DSN RUN under IKJEFT1B.                   *
      * ------------------------------------------------------------- *
      * Output: DD OUTLIST, RECFM=FB,LRECL=80, one record per run:    *
      * Col  1-9  = RUNID, with leading zeros                         *
      * Col 11-18 = job name                                          *
      * Col 20-27 = JES job ID, blank when not known                  *
      * Col 29-37 = most lines to collect (setting OUTLINES)          *
      * RETURN-CODE:                                                  *
      *  0 = Done; OUTLIST may be empty                               *
      *  8 = Error, see SYSOUT; the current unit of work is rolled    *
      *      back                                                     *
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
           SELECT OUTLIST ASSIGN TO OUTLIST
                  FILE STATUS IS W-FS.

       DATA DIVISION.
       FILE SECTION.
       FD OUTLIST
           RECORDING MODE F.
       01 OUTLIST-REC     PIC X(80).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD016 END-EXEC.

           EXEC SQL INCLUDE TBLWD017 END-EXEC.

           COPY LWDCTXW.

       01 W-IO.
          05 RETURNCODE      PIC N(02).
          05 REASONCODE      PIC N(02).
          05 INFOMESSAGE     PIC N(72).

       01 WORK.
          05 C-MAXPURGE      PIC S9(4) COMP-5 VALUE 50.
          05 C-MAXLIST       PIC S9(4) COMP-5 VALUE 20.
          05 C-OUTDAYS       PIC N(8) VALUE N'OUTDAYS'.
          05 C-OUTLINES      PIC N(8) VALUE N'OUTLINES'.
          05 C-P             PIC N VALUE N'P'.
          05 W-FS            PIC XX.
          05 W-RC            PIC S9(4) COMP-5 VALUE 0.
          05 W-DAYS          PIC S9(9) COMP-5.
          05 W-MAXLINES      PIC S9(9) COMP-5.
          05 W-RUNID         PIC S9(9) COMP-5.
          05 W-JOBNAME       PIC N(8).
          05 W-JOBID         PIC N(8).
          05 W-JOBID-IND     PIC S9(4) COMP-5.
          05 W-COUNT         PIC S9(4) COMP-5.
          05 W-DONE          PIC X.
          05 W-EOF           PIC X.
          05 W-PURGED        PIC S9(4) COMP-5 VALUE 0.
          05 W-MAILS         PIC S9(9) COMP-5 VALUE 0.
          05 W-NONE          PIC S9(9) COMP-5 VALUE 0.
          05 W-LISTED        PIC S9(4) COMP-5 VALUE 0.
          05 W-CNT-ED        PIC ZZZZ9.
          05 W-OUT.
             10 W-OUT-RUNID  PIC 9(9).
             10 FILLER       PIC X VALUE SPACE.
             10 W-OUT-JOBNAME PIC X(8).
             10 FILLER       PIC X VALUE SPACE.
             10 W-OUT-JOBID  PIC X(8).
             10 FILLER       PIC X VALUE SPACE.
             10 W-OUT-MAX    PIC 9(9).
             10 FILLER       PIC X(43) VALUE SPACES.

       PROCEDURE DIVISION.
       MAIN SECTION.
           MOVE N'00' TO RETURNCODE OF W-IO
           MOVE N'00' TO REASONCODE OF W-IO
           MOVE SPACES TO INFOMESSAGE OF W-IO

           PERFORM R090-GET-USERID
           PERFORM R100-SETTINGS
           PERFORM R200-PURGE
           PERFORM R250-PURGE-MAIL
           PERFORM R300-NO-JOB
           PERFORM R400-LIST

           IF RETURNCODE OF W-IO NOT = N'00'
              DISPLAY 'LWDM940 '
                      FUNCTION DISPLAY-OF(RETURNCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(REASONCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(INFOMESSAGE OF W-IO)
              MOVE 8 TO W-RC
              EXEC SQL ROLLBACK END-EXEC
           ELSE
              EXEC SQL COMMIT END-EXEC
           END-IF

           MOVE W-PURGED TO W-CNT-ED
           DISPLAY 'LWDM940 RUNS PURGED:        ' W-CNT-ED
           MOVE W-MAILS TO W-CNT-ED
           DISPLAY 'LWDM940 MAILS PURGED:       ' W-CNT-ED
           MOVE W-NONE TO W-CNT-ED
           DISPLAY 'LWDM940 RUNS WITHOUT A JOB: ' W-CNT-ED
           MOVE W-LISTED TO W-CNT-ED
           DISPLAY 'LWDM940 RUNS TO COLLECT:    ' W-CNT-ED

           MOVE W-RC TO RETURN-CODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R100-SETTINGS: OUTDAYS and OUTLINES                           *
      *===============================================================*
       R100-SETTINGS SECTION.
           MOVE C-OUTDAYS TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF W-IO = N'00'
              COMPUTE W-DAYS = FUNCTION NUMVAL(FUNCTION
                 DISPLAY-OF(W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
           END-IF

           MOVE C-OUTLINES TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF W-IO = N'00'
              COMPUTE W-MAXLINES = FUNCTION NUMVAL(FUNCTION
                 DISPLAY-OF(W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
           END-IF
           .
       R100-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R200-PURGE: Output of runs ended more than W-DAYS days ago    *
      *===============================================================*
       R200-PURGE SECTION.
           MOVE 'N' TO W-DONE
           MOVE 0 TO W-COUNT
           PERFORM UNTIL W-DONE = 'Y'
                      OR W-COUNT >= C-MAXPURGE
                      OR RETURNCODE OF W-IO NOT = N'00'
              ADD 1 TO W-COUNT
              EXEC SQL
                 SELECT RUNID
                   INTO :W-RUNID
                   FROM TBLWD014
                  WHERE OUTPUTSTATUS = :C-C
                    AND ENDEDDATE <
                        CURRENT TIMESTAMP - :W-DAYS DAYS
                  ORDER BY ENDEDDATE
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R210-PURGE-ONE
              WHEN 100
                 MOVE 'Y' TO W-DONE
              WHEN OTHER
                 MOVE N'SELECT run to purge' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-PERFORM
           .
       R200-PURGE-END.
           EXIT.

      *===============================================================*
      * R210-PURGE-ONE: Lines and files of W-RUNID, then P; commit    *
      *===============================================================*
       R210-PURGE-ONE SECTION.
           EXEC SQL
              DELETE FROM TBLWD017
               WHERE RUNID = :W-RUNID
           END-EXEC
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE N'DELETE spool lines' TO W-SQL-WHAT
              MOVE N'42' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 DELETE FROM TBLWD016
                  WHERE RUNID = :W-RUNID
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'DELETE spool files' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 UPDATE TBLWD014
                    SET OUTPUTSTATUS = :C-P,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUNID
                    AND OUTPUTSTATUS = :C-C
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE run purged' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL COMMIT END-EXEC
              ADD 1 TO W-PURGED
           END-IF
           .
       R210-PURGE-ONE-END.
           EXIT.

      *===============================================================*
      * R250-PURGE-MAIL: Sent and failed mails older than W-DAYS days *
      * (docs/11-iteration-7.md); commit                              *
      *===============================================================*
       R250-PURGE-MAIL SECTION.
           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 DELETE FROM TBLWD020
                  WHERE MAILSTATUS IN (:C-S, :C-F)
                    AND CREATEDDATE <
                        CURRENT TIMESTAMP - :W-DAYS DAYS
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE SQLERRD(3) TO W-MAILS
                 EXEC SQL COMMIT END-EXEC
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'DELETE old mails' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R250-PURGE-MAIL-END.
           EXIT.

      *===============================================================*
      * R300-NO-JOB: Runs with result X never reached JES: N          *
      *===============================================================*
       R300-NO-JOB SECTION.
           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 UPDATE TBLWD014
                    SET OUTPUTSTATUS = :C-N,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE OUTPUTSTATUS = :C-W
                    AND RUNSTATUS = :C-F
                    AND JOBRESULT = :C-X
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE SQLERRD(3) TO W-NONE
                 EXEC SQL COMMIT END-EXEC
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'UPDATE runs without job' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R300-NO-JOB-END.
           EXIT.

      *===============================================================*
      * R400-LIST: The runs to collect, to OUTLIST                    *
      *===============================================================*
       R400-LIST SECTION.
           IF RETURNCODE OF W-IO = N'00'
              OPEN OUTPUT OUTLIST
              IF W-FS NOT = '00'
                 DISPLAY 'LWDM940 OPEN OUTLIST FILE STATUS ' W-FS
                 MOVE N'08' TO RETURNCODE OF W-IO
                 MOVE N'90' TO REASONCODE OF W-IO
                 MOVE N'OPEN OUTLIST failed' TO INFOMESSAGE OF W-IO
              END-IF
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 DECLARE C1 CURSOR FOR
                 SELECT RUNID,
                        JOBNAME,
                        JESJOBID
                   FROM TBLWD014
                  WHERE OUTPUTSTATUS = :C-W
                    AND RUNSTATUS IN (:C-E, :C-F)
                  ORDER BY RUNID
                  FETCH FIRST 20 ROWS ONLY
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
                            OR RETURNCODE OF W-IO NOT = N'00'
                            OR W-LISTED >= C-MAXLIST
                    PERFORM R410-FETCH
                 END-PERFORM

                 EXEC SQL
                    CLOSE C1
                 END-EXEC
              END-IF

              CLOSE OUTLIST
           END-IF
           .
       R400-LIST-END.
           EXIT.

      *===============================================================*
      * R410-FETCH: One run, one OUTLIST record                       *
      *===============================================================*
       R410-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :W-RUNID,
                    :W-JOBNAME,
                    :W-JOBID :W-JOBID-IND
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE W-RUNID TO W-OUT-RUNID
              MOVE FUNCTION DISPLAY-OF(W-JOBNAME) TO W-OUT-JOBNAME
              IF W-JOBID-IND >= 0
                 MOVE FUNCTION DISPLAY-OF(W-JOBID) TO W-OUT-JOBID
              ELSE
                 MOVE SPACES TO W-OUT-JOBID
              END-IF
              MOVE W-MAXLINES TO W-OUT-MAX
              WRITE OUTLIST-REC FROM W-OUT
              IF W-FS NOT = '00'
                 DISPLAY 'LWDM940 WRITE OUTLIST FILE STATUS ' W-FS
                 MOVE N'08' TO RETURNCODE OF W-IO
                 MOVE N'90' TO REASONCODE OF W-IO
                 MOVE N'WRITE OUTLIST failed' TO INFOMESSAGE OF W-IO
              ELSE
                 ADD 1 TO W-LISTED
              END-IF
           WHEN 100
              MOVE 'Y' TO W-EOF
           WHEN OTHER
              MOVE N'FETCH CURSOR' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R410-FETCH-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==W-IO==.

       END PROGRAM LWDM940.
