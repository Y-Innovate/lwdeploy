       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM317.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /spoolText/{runID}?fileNo=&lineNum_since=: a part of a    *
      * collected spool file (M4): the lines after lineNum_since, as  *
      * many whole lines as fit, at most 300 and at most 24000 bytes  *
      * of UTF-8, so at most 32000 characters of base64. MORELINES Y: *
      * call again with lineNum_since = FIRSTLINENUM + LINECOUNT - 1. *
      * Lines are separated by LF; trailing blanks were stripped when *
      * the output was collected. Who may see it is decided by        *
      * LWDM311, as for the deployment (docs/04-api.md).              *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Run or spool file not found, or no role in its        *
      *         application                                           *
      * 08 21 = Error: SQL error in SELECT, OPEN or FETCH             *
      * 08 90 = Error: LWDU981 failed                                 *
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

           EXEC SQL INCLUDE TBLWD017 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-MAXLINES    PIC S9(4) COMP-5 VALUE 300.
          05 W-PGMNAME     PIC X(8).
          05 W-RUNID       PIC S9(9) COMP-5.
          05 W-DEPLID      PIC S9(9) COMP-5.
          05 W-FILENO      PIC S9(4) COMP-5.
          05 W-SINCE       PIC S9(9) COMP-5.
          05 W-EOF         PIC X.
          05 W-FULL        PIC X.
          05 W-LINENUM     PIC S9(9) COMP-5.
          05 W-LT.
             49 W-LT-LEN   PIC S9(4) COMP-5.
             49 W-LT-TEXT  PIC N(255).
          05 W-ULEN        PIC S9(9) COMP-5.
          05 W-UPOS        PIC S9(9) COMP-5.
          05 W-LF          PIC X VALUE X'0A'.
       01 W-UTF8           PIC X(24000).

       01 W-LLWDM311.
           COPY LLWDM311.
       01 W-LLWDU981.
           COPY LLWDU981.

       LINKAGE SECTION.
       01 P-LLWDM317.
           COPY LLWDM317.

       PROCEDURE DIVISION USING P-LLWDM317.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R050-READ-RUN

           IF RETURNCODE OF P-LLWDM317 = N'00'
              PERFORM R100-MAY-SEE
           END-IF

           PERFORM R200-READ-FILE
           PERFORM R300-BUILD-TEXT
           PERFORM R400-ENCODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM317
           MOVE N'00' TO REASONCODE OF P-LLWDM317
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM317

           MOVE RUNID OF P-LLWDM317 TO W-RUNID
           MOVE FILENO OF P-LLWDM317 TO W-FILENO
           MOVE LINENUM-SINCE OF P-LLWDM317 TO W-SINCE
           MOVE 0 TO FIRSTLINENUM OF P-LLWDM317
           MOVE 0 TO LINECOUNT OF P-LLWDM317
           MOVE N'N' TO MORELINES OF P-LLWDM317
           MOVE SPACES TO SPOOLTEXT OF P-LLWDM317
           MOVE 0 TO W-UPOS
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
              MOVE N'04' TO RETURNCODE OF P-LLWDM317
              MOVE N'01' TO REASONCODE OF P-LLWDM317
              MOVE N'Run not found' TO INFOMESSAGE OF P-LLWDM317
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

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM317
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM317
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM317
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-READ-FILE: The spool file exists                         *
      *===============================================================*
       R200-READ-FILE SECTION.
           IF RETURNCODE OF P-LLWDM317 = N'00'
              EXEC SQL
                 SELECT LINECOUNT
                   INTO :DCLTBLWD016.LINECOUNT
                   FROM TBLWD016
                  WHERE RUNID = :W-RUNID
                    AND FILENO = :W-FILENO
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM317
                 MOVE N'01' TO REASONCODE OF P-LLWDM317
                 MOVE N'Spool file not found' TO
                      INFOMESSAGE OF P-LLWDM317
              WHEN OTHER
                 MOVE N'SELECT spool file' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-READ-FILE-END.
           EXIT.

      *===============================================================*
      * R300-BUILD-TEXT: The lines after W-SINCE as UTF-8, each ended *
      * by LF, until 300 lines or W-UTF8 is full                      *
      *===============================================================*
       R300-BUILD-TEXT SECTION.
           IF RETURNCODE OF P-LLWDM317 = N'00'
              EXEC SQL
                 DECLARE C1 CURSOR FOR
                 SELECT LINENUM,
                        LINETEXT
                   FROM TBLWD017
                  WHERE RUNID = :W-RUNID
                    AND FILENO = :W-FILENO
                    AND LINENUM > :W-SINCE
                  ORDER BY LINENUM
                  FETCH FIRST 301 ROWS ONLY
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
                 MOVE 'N' TO W-FULL
                 PERFORM UNTIL W-EOF = 'Y'
                            OR W-FULL = 'Y'
                            OR RETURNCODE OF P-LLWDM317 NOT = N'00'
                    EXEC SQL
                       FETCH C1 INTO :W-LINENUM, :W-LT
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
      * R310-ADD-LINE: One line in UTF-8 (CCSID 1208), then LF. A     *
      * line that doesn't fit, or the 301st, means MORELINES Y        *
      *===============================================================*
       R310-ADD-LINE SECTION.
           IF W-LT-LEN > 0
              COMPUTE W-ULEN = FUNCTION LENGTH(FUNCTION DISPLAY-OF
                               (W-LT-TEXT(1:W-LT-LEN), 1208))
           ELSE
              MOVE 0 TO W-ULEN
           END-IF

           IF LINECOUNT OF P-LLWDM317 >= C-MAXLINES
           OR W-UPOS + W-ULEN + 1 > LENGTH OF W-UTF8
              MOVE N'Y' TO MORELINES OF P-LLWDM317
              MOVE 'Y' TO W-FULL
           ELSE
              IF LINECOUNT OF P-LLWDM317 = 0
                 MOVE W-LINENUM TO FIRSTLINENUM OF P-LLWDM317
              END-IF
              ADD 1 TO LINECOUNT OF P-LLWDM317

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
      * R400-ENCODE: Base64 into SPOOLTEXT                            *
      *===============================================================*
       R400-ENCODE SECTION.
           IF RETURNCODE OF P-LLWDM317 = N'00' AND W-UPOS > 0
              SET U981-ENCODE TO TRUE
              MOVE W-UPOS TO U981-INPUT-LEN
              MOVE LENGTH OF SPOOLTEXT OF P-LLWDM317 TO U981-OUTPUT-MAX
              MOVE 'LWDU981' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDU981 W-UTF8
                                   SPOOLTEXT OF P-LLWDM317

              IF NOT U981-OK
                 MOVE N'08' TO RETURNCODE OF P-LLWDM317
                 MOVE N'90' TO REASONCODE OF P-LLWDM317
                 MOVE N'LWDU981 failed to encode the output' TO
                      INFOMESSAGE OF P-LLWDM317
              END-IF
           END-IF
           .
       R400-ENCODE-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM317==.

       END PROGRAM LWDM317.
