       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM215.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /jobSteps?runID=: the steps of a run (M3), in order, as   *
      * the output collector (LWDM945) found them in JESYSMSG. Pages  *
      * of 20: pass the last stepNo as stepNo_since. Empty until the  *
      * output is collected (outputStatus C on the run).              *
      * Who may see it is decided by LWDM311, as for the deployment.  *
      * STEPRC -1: not known or not executed. Empty fields: not known.*
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Run not found, or no role in its application          *
      * 08 21 = Error: SQL error on SELECT/OPEN/FETCH                 *
      * And the codes of LWDM311 and LWDCTXP                          *
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

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD015 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-RUNID       PIC S9(9) COMP-5.
          05 W-DEPLID      PIC S9(9) COMP-5.
          05 W-SINCE       PIC S9(4) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.

       01 W-LLWDM311.
           COPY LLWDM311.

       LINKAGE SECTION.
       01 P-LLWDM215.
           COPY LLWDM215.

       PROCEDURE DIVISION USING P-LLWDM215.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R050-READ-RUN

           IF RETURNCODE OF P-LLWDM215 = N'00'
              PERFORM R100-MAY-SEE
           END-IF

           IF RETURNCODE OF P-LLWDM215 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM215
           MOVE N'00' TO REASONCODE OF P-LLWDM215
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM215

           MOVE 0 TO STP-COUNT OF P-LLWDM215
           MOVE RUNID OF P-LLWDM215 TO W-RUNID
           MOVE STEPNO-SINCE OF P-LLWDM215 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R050-READ-RUN: The deployment of the run                      *
      *===============================================================*
       R050-READ-RUN SECTION.
           EXEC SQL
              SELECT DEPLID
                INTO :W-DEPLID
                FROM TBLWD014
               WHERE RUNID = :W-RUNID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LLWDM215
              MOVE N'01' TO REASONCODE OF P-LLWDM215
              MOVE N'Run not found' TO INFOMESSAGE OF P-LLWDM215
           WHEN OTHER
              MOVE N'SELECT run' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R050-READ-RUN-END.
           EXIT.

      *===============================================================*
      * R100-MAY-SEE: LWDM311 decides, as for the deployment itself   *
      *===============================================================*
       R100-MAY-SEE SECTION.
           INITIALIZE W-LLWDM311
           MOVE W-DEPLID TO DEPLID OF W-LLWDM311
           MOVE 'LWDM311' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM311

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM215
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM215
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM215
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The steps after W-SINCE                            *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT STEPNO,
                     STEPNAME,
                     PROCSTEP,
                     PGMNAME,
                     COALESCE(STEPRC, -1),
                     ABENDCODE,
                     FLUSHED
                FROM TBLWD015
               WHERE RUNID = :W-RUNID
                 AND STEPNO > :W-SINCE
               ORDER BY STEPNO
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
                         OR RETURNCODE OF P-LLWDM215 NOT = N'00'
                         OR STP-COUNT OF P-LLWDM215 >= 20
                 PERFORM R210-FETCH
              END-PERFORM

              EXEC SQL
                 CLOSE C1
              END-EXEC
           END-IF
           .
       R200-LIST-END.
           EXIT.

      *===============================================================*
      * R210-FETCH: One step                                          *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD015.STEPNO,
                    :DCLTBLWD015.STEPNAME,
                    :DCLTBLWD015.PROCSTEP
                       :DCLTBLWD015.PROCSTEP-IND,
                    :DCLTBLWD015.PGMNAME
                       :DCLTBLWD015.PGMNAME-IND,
                    :DCLTBLWD015.STEPRC,
                    :DCLTBLWD015.ABENDCODE
                       :DCLTBLWD015.ABENDCODE-IND,
                    :DCLTBLWD015.FLUSHED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO STP-COUNT OF P-LLWDM215
              MOVE STP-COUNT OF P-LLWDM215 TO W-N
              PERFORM R220-COPY
           WHEN 100
              MOVE 'Y' TO W-EOF
           WHEN OTHER
              MOVE N'FETCH CURSOR' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R210-FETCH-END.
           EXIT.

      *===============================================================*
      * R220-COPY: Copy the fetched step                              *
      *===============================================================*
       R220-COPY SECTION.
           MOVE STEPNO OF DCLTBLWD015 TO STEPNO OF P-LLWDM215(W-N)
           MOVE STEPNAME OF DCLTBLWD015 TO STEPNAME OF P-LLWDM215(W-N)

           IF PROCSTEP-IND OF DCLTBLWD015 >= 0
              MOVE PROCSTEP OF DCLTBLWD015 TO
                   PROCSTEP OF P-LLWDM215(W-N)
           ELSE
              MOVE SPACES TO PROCSTEP OF P-LLWDM215(W-N)
           END-IF

           IF PGMNAME-IND OF DCLTBLWD015 >= 0
              MOVE PGMNAME OF DCLTBLWD015 TO PGMNAME OF P-LLWDM215(W-N)
           ELSE
              MOVE SPACES TO PGMNAME OF P-LLWDM215(W-N)
           END-IF

           MOVE STEPRC OF DCLTBLWD015 TO STEPRC OF P-LLWDM215(W-N)

           IF ABENDCODE-IND OF DCLTBLWD015 >= 0
              MOVE ABENDCODE OF DCLTBLWD015 TO
                   ABENDCODE OF P-LLWDM215(W-N)
           ELSE
              MOVE SPACES TO ABENDCODE OF P-LLWDM215(W-N)
           END-IF

           MOVE FLUSHED OF DCLTBLWD015 TO FLUSHED OF P-LLWDM215(W-N)
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM215==.

       END PROGRAM LWDM215.
