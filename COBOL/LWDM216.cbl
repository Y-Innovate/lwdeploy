       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM216.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /spoolFiles?runID=: the collected spool files of a run    *
      * (M4), in spool order: JESMSGLG, JESJCL, JESYSMSG, then the    *
      * SYSOUT data sets of the steps. Pages of 20: pass the last     *
      * fileNo as fileNo_since. Empty until the output is collected   *
      * (outputStatus C) and again once purged (P).                   *
      * Who may see it is decided by LWDM311, as for the deployment.  *
      * TRUNCATED Y: the run reached OUTLINES lines in this file.     *
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

           EXEC SQL INCLUDE TBLWD016 END-EXEC.

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
       01 P-LLWDM216.
           COPY LLWDM216.

       PROCEDURE DIVISION USING P-LLWDM216.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R050-READ-RUN

           IF RETURNCODE OF P-LLWDM216 = N'00'
              PERFORM R100-MAY-SEE
           END-IF

           IF RETURNCODE OF P-LLWDM216 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM216
           MOVE N'00' TO REASONCODE OF P-LLWDM216
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM216

           MOVE 0 TO SPF-COUNT OF P-LLWDM216
           MOVE RUNID OF P-LLWDM216 TO W-RUNID
           MOVE FILENO-SINCE OF P-LLWDM216 TO W-SINCE
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
              MOVE N'04' TO RETURNCODE OF P-LLWDM216
              MOVE N'01' TO REASONCODE OF P-LLWDM216
              MOVE N'Run not found' TO INFOMESSAGE OF P-LLWDM216
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

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM216
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM216
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM216
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The spool files after W-SINCE                      *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT FILENO,
                     DDNAME,
                     STEPNAME,
                     PROCSTEP,
                     LINECOUNT,
                     TRUNCATED
                FROM TBLWD016
               WHERE RUNID = :W-RUNID
                 AND FILENO > :W-SINCE
               ORDER BY FILENO
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
                         OR RETURNCODE OF P-LLWDM216 NOT = N'00'
                         OR SPF-COUNT OF P-LLWDM216 >= 20
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
      * R210-FETCH: One spool file                                    *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD016.FILENO,
                    :DCLTBLWD016.DDNAME,
                    :DCLTBLWD016.STEPNAME
                       :DCLTBLWD016.STEPNAME-IND,
                    :DCLTBLWD016.PROCSTEP
                       :DCLTBLWD016.PROCSTEP-IND,
                    :DCLTBLWD016.LINECOUNT,
                    :DCLTBLWD016.TRUNCATED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO SPF-COUNT OF P-LLWDM216
              MOVE SPF-COUNT OF P-LLWDM216 TO W-N
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
      * R220-COPY: Copy the fetched spool file                        *
      *===============================================================*
       R220-COPY SECTION.
           MOVE FILENO OF DCLTBLWD016 TO FILENO OF P-LLWDM216(W-N)
           MOVE DDNAME OF DCLTBLWD016 TO DDNAME OF P-LLWDM216(W-N)

           IF STEPNAME-IND OF DCLTBLWD016 >= 0
              MOVE STEPNAME OF DCLTBLWD016 TO
                   STEPNAME OF P-LLWDM216(W-N)
           ELSE
              MOVE SPACES TO STEPNAME OF P-LLWDM216(W-N)
           END-IF

           IF PROCSTEP-IND OF DCLTBLWD016 >= 0
              MOVE PROCSTEP OF DCLTBLWD016 TO
                   PROCSTEP OF P-LLWDM216(W-N)
           ELSE
              MOVE SPACES TO PROCSTEP OF P-LLWDM216(W-N)
           END-IF

           MOVE LINECOUNT OF DCLTBLWD016 TO LINECOUNT OF P-LLWDM216(W-N)
           MOVE TRUNCATED OF DCLTBLWD016 TO TRUNCATED OF P-LLWDM216(W-N)
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM216==.

       END PROGRAM LWDM216.
