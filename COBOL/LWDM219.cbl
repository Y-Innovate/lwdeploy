       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM219.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /deploymentEvents?deplID=: the history of a deployment,   *
      * oldest first (M3): requested, approved, started, retried,     *
      * cancelled, ... with who and why. Pages of 20: pass the last   *
      * eventNo as eventNo_since. JOBNO 0: not about one job.         *
      * Who may see it is decided by LWDM311, as for the deployment.  *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Deployment not found, or no role in its application   *
      * 08 21 = Error: SQL error on OPEN/FETCH                        *
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

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-DEPLID      PIC S9(9) COMP-5.
          05 W-SINCE       PIC S9(4) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).

       01 W-LLWDM311.
           COPY LLWDM311.

       LINKAGE SECTION.
       01 P-LLWDM219.
           COPY LLWDM219.

       PROCEDURE DIVISION USING P-LLWDM219.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R100-MAY-SEE

           IF RETURNCODE OF P-LLWDM219 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM219
           MOVE N'00' TO REASONCODE OF P-LLWDM219
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM219

           MOVE 0 TO EVT-COUNT OF P-LLWDM219
           MOVE DEPLID OF P-LLWDM219 TO W-DEPLID
           MOVE EVENTNO-SINCE OF P-LLWDM219 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R100-MAY-SEE: LWDM311 decides, as for the deployment itself   *
      *===============================================================*
       R100-MAY-SEE SECTION.
           INITIALIZE W-LLWDM311
           MOVE W-DEPLID TO DEPLID OF W-LLWDM311
           MOVE 'LWDM311' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM311

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM219
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM219
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM219
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The events after W-SINCE                           *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT EVENTNO,
                     EVENTTYPE,
                     COALESCE(JOBNO, 0),
                     COMMENTTEXT,
                     CREATEDBY,
                     CHAR(CREATEDDATE)
                FROM TBLWD019
               WHERE DEPLID = :W-DEPLID
                 AND EVENTNO > :W-SINCE
               ORDER BY EVENTNO
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
                         OR RETURNCODE OF P-LLWDM219 NOT = N'00'
                         OR EVT-COUNT OF P-LLWDM219 >= 20
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
      * R210-FETCH: One event                                         *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD019.EVENTNO,
                    :DCLTBLWD019.EVENTTYPE,
                    :DCLTBLWD019.JOBNO,
                    :DCLTBLWD019.COMMENTTEXT
                       :DCLTBLWD019.COMMENTTEXT-IND,
                    :DCLTBLWD019.CREATEDBY,
                    :W-CREATED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO EVT-COUNT OF P-LLWDM219
              MOVE EVT-COUNT OF P-LLWDM219 TO W-N
              MOVE EVENTNO OF DCLTBLWD019 TO EVENTNO OF P-LLWDM219(W-N)
              MOVE EVENTTYPE OF DCLTBLWD019 TO
                   EVENTTYPE OF P-LLWDM219(W-N)
              MOVE JOBNO OF DCLTBLWD019 TO JOBNO OF P-LLWDM219(W-N)
              IF COMMENTTEXT-IND OF DCLTBLWD019 >= 0
                 MOVE COMMENTTEXT OF DCLTBLWD019 TO
                      COMMENTTEXT OF P-LLWDM219(W-N)
              ELSE
                 MOVE 0 TO COMMENTTEXT-LEN OF P-LLWDM219(W-N)
              END-IF
              MOVE CREATEDBY OF DCLTBLWD019 TO
                   CREATEDBY OF P-LLWDM219(W-N)
              MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                   CREATEDDATE OF P-LLWDM219(W-N)
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

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM219==.

       END PROGRAM LWDM219.
