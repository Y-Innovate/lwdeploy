       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM310.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /templateJcl/{templateID}?revision= (O2): the JCL of one  *
      * revision of a job template, for whoever may see the           *
      * application; of a deleted template too. REVISION 0 is the     *
      * current one. A template without JCL answers revision 0 and no *
      * lines. JCL is UTF-8 text, lines separated by LF (none after   *
      * the last), base64 encoded by LWDU981, as LWDM313 does for     *
      * frozen JCL.                                                   *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Template or revision not found, or no role in the     *
      *         application                                           *
      * 08 21 = Error: SQL error                                      *
      * 08 90 = Error: the JCL doesn't fit, or LWDU981 failed         *
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

           EXEC SQL INCLUDE TBLWD008 END-EXEC.

           EXEC SQL INCLUDE TBLWD009 END-EXEC.

           EXEC SQL INCLUDE TBLWD010 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-TEMPLATEID  PIC S9(9) COMP-5.
          05 W-REVISION    PIC S9(4) COMP-5.
          05 W-REVISION-ED PIC Z(4)9.
          05 W-EOF         PIC X.
          05 W-LT.
             49 W-LT-LEN   PIC S9(4) COMP-5.
             49 W-LT-TEXT  PIC N(80).
          05 W-ULEN        PIC S9(9) COMP-5.
          05 W-UPOS        PIC S9(9) COMP-5.
          05 W-LF          PIC X VALUE X'0A'.
       01 W-UTF8           PIC X(24300).

       01 W-LLWDU981.
           COPY LLWDU981.

       LINKAGE SECTION.
       01 P-LLWDM310.
           COPY LLWDM310.

       PROCEDURE DIVISION USING P-LLWDM310.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R150-TEMPLATE-APP
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           IF  RETURNCODE OF P-LLWDM310 = N'00'
           AND W-REVISION > 0
              PERFORM R200-READ-REVISION
              PERFORM R300-BUILD-TEXT
              PERFORM R400-ENCODE
           END-IF

           IF  RETURNCODE OF P-LLWDM310 = N'04'
           AND INFOMESSAGE OF P-LLWDM310(1:3) = N'App'
              MOVE N'Template not found' TO INFOMESSAGE OF P-LLWDM310
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM310
           MOVE N'00' TO REASONCODE OF P-LLWDM310
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM310

           MOVE TEMPLATEID OF P-LLWDM310 TO W-TEMPLATEID
           MOVE REVISION OF P-LLWDM310 TO W-REVISION
           MOVE 0 TO LINECOUNT OF P-LLWDM310
           MOVE 0 TO W-UPOS
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-TEMPLATE-APP: W-APPID of the template, and the current   *
      * revision for REVISION 0                                       *
      *===============================================================*
       R150-TEMPLATE-APP SECTION.
           IF RETURNCODE OF P-LLWDM310 = N'00'
              EXEC SQL
                 SELECT APPID,
                        CURRENTREV
                   INTO :W-APPID,
                        :DCLTBLWD008.CURRENTREV
                   FROM TBLWD008
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 IF W-REVISION <= 0
                    MOVE CURRENTREV OF DCLTBLWD008 TO W-REVISION
                 END-IF
                 MOVE W-REVISION TO REVISION OF P-LLWDM310
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM310
                 MOVE N'01' TO REASONCODE OF P-LLWDM310
                 MOVE N'Template not found' TO INFOMESSAGE OF P-LLWDM310
              WHEN OTHER
                 MOVE N'SELECT template' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R150-TEMPLATE-APP-END.
           EXIT.

      *===============================================================*
      * R200-READ-REVISION: The revision exists                       *
      *===============================================================*
       R200-READ-REVISION SECTION.
           EXEC SQL
              SELECT LINECOUNT
                INTO :DCLTBLWD009.LINECOUNT
                FROM TBLWD009
               WHERE TEMPLATEID = :W-TEMPLATEID
                 AND REVISION = :W-REVISION
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE LINECOUNT OF DCLTBLWD009 TO LINECOUNT OF P-LLWDM310
           WHEN 100
              MOVE W-REVISION TO W-REVISION-ED
              MOVE N'04' TO RETURNCODE OF P-LLWDM310
              MOVE N'01' TO REASONCODE OF P-LLWDM310
              STRING N'Revision ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-REVISION-ED))
                        DELIMITED BY SIZE
                     N' not found' DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM310
           WHEN OTHER
              MOVE N'SELECT revision' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R200-READ-REVISION-END.
           EXIT.

      *===============================================================*
      * R300-BUILD-TEXT: The lines in UTF-8, separated by LF          *
      *===============================================================*
       R300-BUILD-TEXT SECTION.
           IF RETURNCODE OF P-LLWDM310 = N'00'
              EXEC SQL
                 DECLARE C1 CURSOR FOR
                 SELECT LINETEXT
                   FROM TBLWD010
                  WHERE TEMPLATEID = :W-TEMPLATEID
                    AND REVISION = :W-REVISION
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
                            OR RETURNCODE OF P-LLWDM310 NOT = N'00'
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
      * R310-ADD-LINE: LF before every line but the first, then the   *
      * line in UTF-8 (CCSID 1208)                                    *
      *===============================================================*
       R310-ADD-LINE SECTION.
           IF W-LT-LEN > 0
              COMPUTE W-ULEN = FUNCTION LENGTH(FUNCTION DISPLAY-OF
                               (W-LT-TEXT(1:W-LT-LEN), 1208))
           ELSE
              MOVE 0 TO W-ULEN
           END-IF

           IF W-UPOS + W-ULEN + 1 > LENGTH OF W-UTF8
              MOVE N'08' TO RETURNCODE OF P-LLWDM310
              MOVE N'90' TO REASONCODE OF P-LLWDM310
              MOVE N'The JCL is too large to return' TO
                   INFOMESSAGE OF P-LLWDM310
           ELSE
              IF W-UPOS > 0
                 ADD 1 TO W-UPOS
                 MOVE W-LF TO W-UTF8(W-UPOS:1)
              END-IF
              IF W-ULEN > 0
                 MOVE FUNCTION DISPLAY-OF(W-LT-TEXT(1:W-LT-LEN), 1208)
                   TO W-UTF8(W-UPOS + 1:W-ULEN)
                 ADD W-ULEN TO W-UPOS
              END-IF
           END-IF
           .
       R310-ADD-LINE-END.
           EXIT.

      *===============================================================*
      * R400-ENCODE: Base64 into JCL                                  *
      *===============================================================*
       R400-ENCODE SECTION.
           IF  RETURNCODE OF P-LLWDM310 = N'00'
           AND W-UPOS > 0
              SET U981-ENCODE TO TRUE
              MOVE W-UPOS TO U981-INPUT-LEN
              MOVE LENGTH OF JCL OF P-LLWDM310 TO U981-OUTPUT-MAX
              MOVE 'LWDU981' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDU981 W-UTF8 JCL OF P-LLWDM310

              IF NOT U981-OK
                 MOVE N'08' TO RETURNCODE OF P-LLWDM310
                 MOVE N'90' TO REASONCODE OF P-LLWDM310
                 MOVE N'LWDU981 failed to encode the JCL' TO
                      INFOMESSAGE OF P-LLWDM310
              END-IF
           END-IF
           .
       R400-ENCODE-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM310==.

       END PROGRAM LWDM310.
