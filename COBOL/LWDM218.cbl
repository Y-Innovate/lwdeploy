       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM218.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /approvals?deplID=: the decisions on a deployment, oldest *
      * first (M3, AP2). A deployment has at most a few, so no paging.*
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

           EXEC SQL INCLUDE TBLWD018 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-DEPLID      PIC S9(9) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).

       01 W-LLWDM311.
           COPY LLWDM311.

       LINKAGE SECTION.
       01 P-LLWDM218.
           COPY LLWDM218.

       PROCEDURE DIVISION USING P-LLWDM218.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R100-MAY-SEE

           IF RETURNCODE OF P-LLWDM218 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM218
           MOVE N'00' TO REASONCODE OF P-LLWDM218
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM218

           MOVE 0 TO APR-COUNT OF P-LLWDM218
           MOVE DEPLID OF P-LLWDM218 TO W-DEPLID
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

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM218
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM218
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM218
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The decisions                                      *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT USERID,
                     DECISION,
                     COMMENTTEXT,
                     CHAR(CREATEDDATE)
                FROM TBLWD018
               WHERE DEPLID = :W-DEPLID
               ORDER BY CREATEDDATE, USERID
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
                         OR RETURNCODE OF P-LLWDM218 NOT = N'00'
                         OR APR-COUNT OF P-LLWDM218 >= 20
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
      * R210-FETCH: One decision                                      *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD018.USERID,
                    :DCLTBLWD018.DECISION,
                    :DCLTBLWD018.COMMENTTEXT
                       :DCLTBLWD018.COMMENTTEXT-IND,
                    :W-CREATED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO APR-COUNT OF P-LLWDM218
              MOVE APR-COUNT OF P-LLWDM218 TO W-N
              MOVE USERID OF DCLTBLWD018 TO USERID OF P-LLWDM218(W-N)
              MOVE DECISION OF DCLTBLWD018 TO
                   DECISION OF P-LLWDM218(W-N)
              IF COMMENTTEXT-IND OF DCLTBLWD018 >= 0
                 MOVE COMMENTTEXT OF DCLTBLWD018 TO
                      COMMENTTEXT OF P-LLWDM218(W-N)
              ELSE
                 MOVE 0 TO COMMENTTEXT-LEN OF P-LLWDM218(W-N)
              END-IF
              MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                   CREATEDDATE OF P-LLWDM218(W-N)
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

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM218==.

       END PROGRAM LWDM218.
