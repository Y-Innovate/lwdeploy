       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM313.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /deploymentJcl/{deplID}?jobNo=: the frozen JCL of a job   *
      * of a deployment (M3, AP2): the steps as they will be or were  *
      * submitted, without the JOB statement and the result step that *
      * LWDM920 adds. Who may see it is decided by LWDM311.           *
      * JCL is UTF-8 text, lines separated by LF, base64 encoded by   *
      * LWDU981 (docs/04-api.md).                                     *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Deployment or job not found                           *
      * 08 21 = Error: SQL error in SELECT, OPEN or FETCH             *
      * 08 90 = Error: the JCL doesn't fit, or LWDU981 failed         *
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

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD013 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-DEPLID      PIC S9(9) COMP-5.
          05 W-JOBNO       PIC S9(4) COMP-5.
          05 W-EOF         PIC X.
          05 W-LT.
             49 W-LT-LEN   PIC S9(4) COMP-5.
             49 W-LT-TEXT  PIC N(80).
          05 W-ULEN        PIC S9(9) COMP-5.
          05 W-UPOS        PIC S9(9) COMP-5.
          05 W-LF          PIC X VALUE X'0A'.
       01 W-UTF8           PIC X(24300).

       01 W-LLWDM311.
           COPY LLWDM311.
       01 W-LLWDU981.
           COPY LLWDU981.

       LINKAGE SECTION.
       01 P-LLWDM313.
           COPY LLWDM313.

       PROCEDURE DIVISION USING P-LLWDM313.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R100-MAY-SEE
           PERFORM R200-READ-JOB
           PERFORM R300-BUILD-TEXT
           PERFORM R400-ENCODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM313
           MOVE N'00' TO REASONCODE OF P-LLWDM313
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM313

           MOVE DEPLID OF P-LLWDM313 TO W-DEPLID
           MOVE JOBNO OF P-LLWDM313 TO W-JOBNO
           MOVE 0 TO LINECOUNT OF P-LLWDM313
           MOVE SPACES TO JCL OF P-LLWDM313
           MOVE 0 TO W-UPOS
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

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM313
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM313
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM313
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-READ-JOB: The job exists, and its number of lines        *
      *===============================================================*
       R200-READ-JOB SECTION.
           IF RETURNCODE OF P-LLWDM313 = N'00'
              EXEC SQL
                 SELECT LINECOUNT
                   INTO :DCLTBLWD012.LINECOUNT
                   FROM TBLWD012
                  WHERE DEPLID = :W-DEPLID
                    AND JOBNO = :W-JOBNO
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE LINECOUNT OF DCLTBLWD012 TO
                      LINECOUNT OF P-LLWDM313
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM313
                 MOVE N'01' TO REASONCODE OF P-LLWDM313
                 MOVE N'Job not found' TO INFOMESSAGE OF P-LLWDM313
              WHEN OTHER
                 MOVE N'SELECT job' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-READ-JOB-END.
           EXIT.

      *===============================================================*
      * R300-BUILD-TEXT: The lines as UTF-8, each ended by LF         *
      *===============================================================*
       R300-BUILD-TEXT SECTION.
           IF RETURNCODE OF P-LLWDM313 = N'00'
              EXEC SQL
                 DECLARE C1 CURSOR FOR
                 SELECT LINETEXT
                   FROM TBLWD013
                  WHERE DEPLID = :W-DEPLID
                    AND JOBNO = :W-JOBNO
                  ORDER BY LINENUM
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
                            OR RETURNCODE OF P-LLWDM313 NOT = N'00'
                    EXEC SQL
                       FETCH C1 INTO :W-LT
                    END-EXEC
                    EVALUATE SQLCODE
                    WHEN 0
                       PERFORM R310-ADD-LINE
                    WHEN 100
                       MOVE 'Y' TO W-EOF
                    WHEN OTHER
                       MOVE N'FETCH CURSOR' TO W-SQL-WHAT
                       MOVE N'21' TO W-SQL-REASON
                       PERFORM R890-SQL-ERROR
                    END-EVALUATE
                 END-PERFORM

                 EXEC SQL
                    CLOSE C1
                 END-EXEC
              END-IF
           END-IF
           .
       R300-BUILD-TEXT-END.
           EXIT.

      *===============================================================*
      * R310-ADD-LINE: One line in UTF-8 (CCSID 1208), then LF        *
      *===============================================================*
       R310-ADD-LINE SECTION.
           IF W-LT-LEN > 0
              COMPUTE W-ULEN = FUNCTION LENGTH(FUNCTION DISPLAY-OF
                               (W-LT-TEXT(1:W-LT-LEN), 1208))
           ELSE
              MOVE 0 TO W-ULEN
           END-IF

           IF W-UPOS + W-ULEN + 1 > LENGTH OF W-UTF8
              MOVE N'08' TO RETURNCODE OF P-LLWDM313
              MOVE N'90' TO REASONCODE OF P-LLWDM313
              MOVE N'The JCL is too large to return' TO
                   INFOMESSAGE OF P-LLWDM313
           ELSE
              IF W-ULEN > 0
                 MOVE FUNCTION DISPLAY-OF(W-LT-TEXT(1:W-LT-LEN), 1208)
                   TO W-UTF8(W-UPOS + 1:W-ULEN)
                 ADD W-ULEN TO W-UPOS
              END-IF
              ADD 1 TO W-UPOS
              MOVE W-LF TO W-UTF8(W-UPOS:1)
           END-IF
           .
       R310-ADD-LINE-END.
           EXIT.

      *===============================================================*
      * R400-ENCODE: Base64 into JCL                                  *
      *===============================================================*
       R400-ENCODE SECTION.
           IF RETURNCODE OF P-LLWDM313 = N'00'
              SET U981-ENCODE TO TRUE
              MOVE W-UPOS TO U981-INPUT-LEN
              MOVE LENGTH OF JCL OF P-LLWDM313 TO U981-OUTPUT-MAX
              MOVE 'LWDU981' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDU981 W-UTF8 JCL OF P-LLWDM313

              IF NOT U981-OK
                 MOVE N'08' TO RETURNCODE OF P-LLWDM313
                 MOVE N'90' TO REASONCODE OF P-LLWDM313
                 MOVE N'LWDU981 failed to encode the JCL' TO
                      INFOMESSAGE OF P-LLWDM313
              END-IF
           END-IF
           .
       R400-ENCODE-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM313==.

       END PROGRAM LWDM313.
