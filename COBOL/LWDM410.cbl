       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM410.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /templateJcl/{templateID} (O2): save JCL as the next     *
      * revision of a job template, which becomes the current one.    *
      * Owners of the application only (administrators too), not for *
      * a deleted template. The body is multipart: the wrapper        *
      * LWDC410 reads the form fields jcl (base64 of UTF-8, JCLLENGTH *
      * characters; 0 = missing) and changeNote into the IO area,     *
      * because this module has no CICS translator.                   *
      * 1. Decodes jcl with LWDU981, converts it from UTF-8, drops CR *
      *    and splits it at LF; a last LF makes no empty line.        *
      * 2. Refuses (08 56, naming the first line): empty JCL, more    *
      *    than 300 lines, a line over 80 characters, a JOB           *
      *    statement, USER= or PASSWORD= on a statement, a JES2       *
      *    statement (/*JOBPARM, /*ROUTE, /*XEQ, /*OUTPUT, /*PRIORITY,*
      *    /*NETACCT, /*NOTIFY, /*SETUP, /*SIGNON, /*XMIT) or a JES3   *
      *    statement (//* followed by a JES3 keyword, such as MAIN).  *
      * 3. Counts warnings, the first in INFOMESSAGE: a ${NAME} that  *
      *    is defined at no level of the application and isn't a      *
      *    built-in, a statement that passes column 71.               *
      * 4. Inserts TEMPLATEREVS and TEMPLATELINES and sets CURRENTREV,*
      *    in one unit of work; the template row is locked first, so  *
      *    two saves don't get the same revision.                     *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, with WARNINGCOUNT and the first warning      *
      * 04 01 = Template not found, or no role in its application     *
      * 08 12/21/32 = Error: SQL error                                *
      * 08 50 = Error: not an owner of the application                *
      * 08 53 = Error: the template is deleted                        *
      * 08 56 = Error: JCL refused, see above                         *
      * 08 58 = Error: jcl missing, too large, not base64 or UTF-8    *
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

           EXEC SQL INCLUDE TBLWD007 END-EXEC.

           EXEC SQL INCLUDE TBLWD008 END-EXEC.

           EXEC SQL INCLUDE TBLWD009 END-EXEC.

           EXEC SQL INCLUDE TBLWD010 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-TEMPLATEID  PIC S9(9) COMP-5.
          05 W-REVISION    PIC S9(4) COMP-5.
          05 W-ULEN        PIC S9(9) COMP-5.
          05 W-NLEN        PIC S9(9) COMP-5.
          05 W-P           PIC S9(9) COMP-5.
          05 W-START       PIC S9(9) COMP-5.
          05 W-LEN         PIC S9(9) COMP-5.
          05 W-I           PIC S9(4) COMP-5.
          05 W-J           PIC S9(4) COMP-5.
          05 W-K           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-KWLEN       PIC S9(4) COMP-5.
          05 W-HIT         PIC X.
          05 W-BLANK       PIC X.
          05 W-COUNT       PIC S9(9) COMP-5.
          05 W-LINE-ED     PIC ZZ9.
          05 W-NOTE-IND    PIC S9(4) COMP-5.
          05 W-REFUSAL     PIC N(60).
          05 W-WARNING     PIC N(72).
          05 W-NAME.
             49 W-NAME-LEN  PIC S9(4) COMP-5.
             49 W-NAME-TEXT PIC N(16).
          05 C-MAXLINES    PIC S9(4) COMP-5 VALUE 300.
          05 C-LF          PIC N VALUE NX'000A'.
          05 C-CR          PIC N VALUE NX'000D'.
          05 C-BAD         PIC N VALUE NX'FFFD'.

      *   JES2 control statements after /*, JES3 after //*
       01 C-JES2-TAB.
          05 FILLER        PIC N(8) VALUE N'JOBPARM'.
          05 FILLER        PIC N(8) VALUE N'ROUTE'.
          05 FILLER        PIC N(8) VALUE N'XEQ'.
          05 FILLER        PIC N(8) VALUE N'OUTPUT'.
          05 FILLER        PIC N(8) VALUE N'PRIORITY'.
          05 FILLER        PIC N(8) VALUE N'NETACCT'.
          05 FILLER        PIC N(8) VALUE N'NOTIFY'.
          05 FILLER        PIC N(8) VALUE N'SETUP'.
          05 FILLER        PIC N(8) VALUE N'SIGNON'.
          05 FILLER        PIC N(8) VALUE N'XMIT'.
       01 C-JES2 REDEFINES C-JES2-TAB.
          05 C-JES2-KW     PIC N(8) OCCURS 10.
       01 C-JES3-TAB.
          05 FILLER        PIC N(10) VALUE N'MAIN'.
          05 FILLER        PIC N(10) VALUE N'NET'.
          05 FILLER        PIC N(10) VALUE N'NETACCT'.
          05 FILLER        PIC N(10) VALUE N'ROUTE'.
          05 FILLER        PIC N(10) VALUE N'FORMAT'.
          05 FILLER        PIC N(10) VALUE N'PROCESS'.
          05 FILLER        PIC N(10) VALUE N'ENDPROCESS'.
          05 FILLER        PIC N(10) VALUE N'DATASET'.
          05 FILLER        PIC N(10) VALUE N'ENDDATASET'.
          05 FILLER        PIC N(10) VALUE N'PAUSE'.
          05 FILLER        PIC N(10) VALUE N'OPERATOR'.
       01 C-JES3 REDEFINES C-JES3-TAB.
          05 C-JES3-KW     PIC N(10) OCCURS 11.

       01 W-KW             PIC N(10).

       01 W-UTF8           PIC X(24300).
       01 W-NAT            PIC N(24300).

       01 W-LINES.
          05 W-LINE-COUNT  PIC S9(4) COMP-5.
          05 W-LINE OCCURS 300.
             10 W-LINE-LEN  PIC S9(4) COMP-5.
             10 W-LINE-TEXT PIC N(80).
       01 W-L.
          05 W-L-LEN       PIC S9(4) COMP-5.
          05 W-L-TEXT      PIC N(80).
       01 W-LT.
          49 W-LT-LEN      PIC S9(4) COMP-5.
          49 W-LT-TEXT     PIC N(80).

       01 W-LLWDU981.
           COPY LLWDU981.

       LINKAGE SECTION.
       01 P-LLWDM410.
           COPY LLWDM410.

       PROCEDURE DIVISION USING P-LLWDM410.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R150-TEMPLATE-APP
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE
           PERFORM R106-REQUIRE-OWNER
           PERFORM R160-REQUIRE-ACTIVE

           PERFORM R200-DECODE
           PERFORM R300-SPLIT
           PERFORM R400-CHECK-LINES
           PERFORM R500-WARNINGS
           PERFORM R600-SAVE

           IF  RETURNCODE OF P-LLWDM410 = N'04'
              MOVE N'Template not found' TO INFOMESSAGE OF P-LLWDM410
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM410
           MOVE N'00' TO REASONCODE OF P-LLWDM410
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM410

           MOVE TEMPLATEID OF P-LLWDM410 TO W-TEMPLATEID
           MOVE 0 TO REVISION OF P-LLWDM410
           MOVE 0 TO LINECOUNT OF P-LLWDM410
           MOVE 0 TO WARNINGCOUNT OF P-LLWDM410
           MOVE 0 TO W-LINE-COUNT
           MOVE SPACES TO W-WARNING

           IF  CHANGENOTE-LEN OF P-LLWDM410 > 0
           AND CHANGENOTE-LEN OF P-LLWDM410 <= 255
              MOVE 0 TO W-NOTE-IND
           ELSE
              MOVE -1 TO W-NOTE-IND
              MOVE 0 TO CHANGENOTE-LEN OF P-LLWDM410
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-TEMPLATE-APP: W-APPID and status of the template         *
      *===============================================================*
       R150-TEMPLATE-APP SECTION.
           IF RETURNCODE OF P-LLWDM410 = N'00'
              EXEC SQL
                 SELECT APPID,
                        TEMPLATENAME,
                        TEMPLATESTATUS
                   INTO :W-APPID,
                        :DCLTBLWD008.TEMPLATENAME,
                        :DCLTBLWD008.TEMPLATESTATUS
                   FROM TBLWD008
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM410
                 MOVE N'01' TO REASONCODE OF P-LLWDM410
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
      * R160-REQUIRE-ACTIVE: No JCL for a deleted template (08 53)    *
      *===============================================================*
       R160-REQUIRE-ACTIVE SECTION.
           IF  RETURNCODE OF P-LLWDM410 = N'00'
           AND TEMPLATESTATUS OF DCLTBLWD008 NOT = C-A
              MOVE N'08' TO RETURNCODE OF P-LLWDM410
              MOVE N'53' TO REASONCODE OF P-LLWDM410
              STRING TEMPLATENAME-TEXT OF DCLTBLWD008(1:
                        TEMPLATENAME-LEN OF DCLTBLWD008)
                        DELIMITED BY SIZE
                     N' is deleted' DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM410
           END-IF
           .
       R160-REQUIRE-ACTIVE-END.
           EXIT.

      *===============================================================*
      * R200-DECODE: Base64 to UTF-8 bytes, then to national text     *
      *===============================================================*
       R200-DECODE SECTION.
           IF RETURNCODE OF P-LLWDM410 = N'00'
              EVALUATE TRUE
              WHEN JCLLENGTH OF P-LLWDM410 <= 0
                 MOVE N'Form field jcl is missing' TO
                      INFOMESSAGE OF P-LLWDM410
              WHEN JCLLENGTH OF P-LLWDM410 > LENGTH OF JCL OF
                   P-LLWDM410
                 MOVE N'jcl is too large: at most 300 lines of 80' TO
                      INFOMESSAGE OF P-LLWDM410
              END-EVALUATE
              IF INFOMESSAGE OF P-LLWDM410 NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'58' TO REASONCODE OF P-LLWDM410
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM410 = N'00'
              SET U981-DECODE TO TRUE
              MOVE JCLLENGTH OF P-LLWDM410 TO U981-INPUT-LEN
              MOVE LENGTH OF W-UTF8 TO U981-OUTPUT-MAX
              MOVE 'LWDU981' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDU981 JCL OF P-LLWDM410 W-UTF8

              EVALUATE U981-RC
              WHEN '00'
                 MOVE U981-OUTPUT-LEN TO W-ULEN
              WHEN '04'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'58' TO REASONCODE OF P-LLWDM410
                 MOVE N'jcl is too large: at most 300 lines of 80' TO
                      INFOMESSAGE OF P-LLWDM410
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'58' TO REASONCODE OF P-LLWDM410
                 MOVE N'jcl is not valid base64' TO
                      INFOMESSAGE OF P-LLWDM410
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF P-LLWDM410 = N'00'
           AND W-ULEN = 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM410
              MOVE N'56' TO REASONCODE OF P-LLWDM410
              MOVE N'The JCL is empty' TO INFOMESSAGE OF P-LLWDM410
           END-IF

      *    Invalid UTF-8 becomes the replacement character U+FFFD
           IF RETURNCODE OF P-LLWDM410 = N'00'
              COMPUTE W-NLEN = FUNCTION LENGTH(FUNCTION NATIONAL-OF(
                      W-UTF8(1:W-ULEN), 1208))
              MOVE FUNCTION NATIONAL-OF(W-UTF8(1:W-ULEN), 1208) TO
                   W-NAT
              MOVE 0 TO W-COUNT
              INSPECT W-NAT(1:W-NLEN) TALLYING W-COUNT FOR ALL C-BAD
              IF W-COUNT > 0
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'58' TO REASONCODE OF P-LLWDM410
                 MOVE N'jcl is not valid UTF-8' TO
                      INFOMESSAGE OF P-LLWDM410
              END-IF
           END-IF
           .
       R200-DECODE-END.
           EXIT.

      *===============================================================*
      * R300-SPLIT: Lines at LF, without CR; a last LF makes no empty *
      * line. More than 300 lines or a line over 80: 08 56            *
      *===============================================================*
       R300-SPLIT SECTION.
           IF RETURNCODE OF P-LLWDM410 = N'00'
              MOVE 1 TO W-START
              PERFORM VARYING W-P FROM 1 BY 1
                        UNTIL W-P > W-NLEN + 1
                           OR RETURNCODE OF P-LLWDM410 NOT = N'00'
                 IF W-P > W-NLEN
                    IF W-START <= W-NLEN
                       PERFORM R310-ADD-LINE
                    END-IF
                 ELSE
                    IF W-NAT(W-P:1) = C-LF
                       PERFORM R310-ADD-LINE
                       COMPUTE W-START = W-P + 1
                    END-IF
                 END-IF
              END-PERFORM
           END-IF
           .
       R300-SPLIT-END.
           EXIT.

      *===============================================================*
      * R310-ADD-LINE: W-NAT(W-START) up to W-P - 1, without CR       *
      *===============================================================*
       R310-ADD-LINE SECTION.
           COMPUTE W-LEN = W-P - W-START
           IF W-LEN > 0
              IF W-NAT(W-START + W-LEN - 1:1) = C-CR
                 SUBTRACT 1 FROM W-LEN
              END-IF
           END-IF

           IF W-LINE-COUNT >= C-MAXLINES
              MOVE N'08' TO RETURNCODE OF P-LLWDM410
              MOVE N'56' TO REASONCODE OF P-LLWDM410
              MOVE N'More than 300 lines' TO INFOMESSAGE OF P-LLWDM410
           ELSE
              ADD 1 TO W-LINE-COUNT
              IF W-LEN > 80
                 MOVE W-LINE-COUNT TO W-LINE-ED
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'56' TO REASONCODE OF P-LLWDM410
                 STRING N'Line ' DELIMITED BY SIZE
                        FUNCTION NATIONAL-OF(FUNCTION TRIM(W-LINE-ED))
                           DELIMITED BY SIZE
                        N': longer than 80 characters'
                           DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM410
              ELSE
                 MOVE SPACES TO W-LINE-TEXT(W-LINE-COUNT)
                 MOVE W-LEN TO W-LINE-LEN(W-LINE-COUNT)
                 IF W-LEN > 0
                    MOVE W-NAT(W-START:W-LEN) TO
                         W-LINE-TEXT(W-LINE-COUNT)
                 END-IF
              END-IF
           END-IF
           .
       R310-ADD-LINE-END.
           EXIT.

      *===============================================================*
      * R400-CHECK-LINES: Empty JCL, and per line the statements LWD  *
      * doesn't allow, the first one refused                          *
      *===============================================================*
       R400-CHECK-LINES SECTION.
           IF RETURNCODE OF P-LLWDM410 = N'00'
              MOVE 'Y' TO W-BLANK
              PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > W-LINE-COUNT
                 IF W-LINE-TEXT(W-I) NOT = SPACES
                    MOVE 'N' TO W-BLANK
                 END-IF
              END-PERFORM
              IF W-BLANK = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'56' TO REASONCODE OF P-LLWDM410
                 MOVE N'The JCL is empty' TO INFOMESSAGE OF P-LLWDM410
              END-IF
           END-IF

           PERFORM VARYING W-I FROM 1 BY 1
                     UNTIL W-I > W-LINE-COUNT
                        OR RETURNCODE OF P-LLWDM410 NOT = N'00'
              MOVE W-LINE-LEN(W-I) TO W-L-LEN
              MOVE W-LINE-TEXT(W-I) TO W-L-TEXT
              MOVE SPACES TO W-REFUSAL
              PERFORM R410-JOB-STATEMENT
              IF W-REFUSAL = SPACES
                 PERFORM R420-JES2
              END-IF
              IF W-REFUSAL = SPACES
                 PERFORM R430-JES3
              END-IF
              IF W-REFUSAL = SPACES
                 PERFORM R440-USER-PASSWORD
              END-IF
              IF W-REFUSAL NOT = SPACES
                 MOVE W-I TO W-LINE-ED
                 MOVE N'08' TO RETURNCODE OF P-LLWDM410
                 MOVE N'56' TO REASONCODE OF P-LLWDM410
                 STRING N'Line ' DELIMITED BY SIZE
                        FUNCTION NATIONAL-OF(FUNCTION TRIM(W-LINE-ED))
                           DELIMITED BY SIZE
                        N': ' DELIMITED BY SIZE
                        W-REFUSAL DELIMITED BY N'  '
                   INTO INFOMESSAGE OF P-LLWDM410
              END-IF
           END-PERFORM
           .
       R400-CHECK-LINES-END.
           EXIT.

      *===============================================================*
      * R410-JOB-STATEMENT: //name JOB ..., or // JOB                 *
      *===============================================================*
       R410-JOB-STATEMENT SECTION.
           IF  W-L-TEXT(1:2) = N'//'
           AND W-L-TEXT(3:1) NOT = N'*'
      *       Past the name field, then past the blanks
              MOVE 3 TO W-J
              MOVE 'N' TO W-HIT
              PERFORM UNTIL W-J > 80 OR W-HIT = 'Y'
                 IF W-L-TEXT(W-J:1) = SPACE
                    MOVE 'Y' TO W-HIT
                 ELSE
                    ADD 1 TO W-J
                 END-IF
              END-PERFORM
              MOVE 'N' TO W-HIT
              PERFORM UNTIL W-J > 80 OR W-HIT = 'Y'
                 IF W-L-TEXT(W-J:1) NOT = SPACE
                    MOVE 'Y' TO W-HIT
                 ELSE
                    ADD 1 TO W-J
                 END-IF
              END-PERFORM
              MOVE N'JOB' TO W-KW
              PERFORM R450-KEYWORD
              IF W-HIT = 'Y'
                 MOVE N'a JOB statement; LWD writes it' TO W-REFUSAL
              END-IF
           END-IF
           .
       R410-JOB-STATEMENT-END.
           EXIT.

      *===============================================================*
      * R420-JES2: /* followed by a JES2 keyword and a blank          *
      *===============================================================*
       R420-JES2 SECTION.
           IF W-L-TEXT(1:2) = N'/*'
              PERFORM VARYING W-K FROM 1 BY 1 UNTIL W-K > 10
                 MOVE C-JES2-KW(W-K) TO W-KW
                 MOVE 3 TO W-J
                 PERFORM R450-KEYWORD
                 IF W-HIT = 'Y'
                    MOVE N'a JES2 statement' TO W-REFUSAL
                 END-IF
              END-PERFORM
           END-IF
           .
       R420-JES2-END.
           EXIT.

      *===============================================================*
      * R430-JES3: //* followed by a JES3 keyword and a blank         *
      *===============================================================*
       R430-JES3 SECTION.
           IF W-L-TEXT(1:3) = N'//*'
              PERFORM VARYING W-K FROM 1 BY 1 UNTIL W-K > 11
                 MOVE C-JES3-KW(W-K) TO W-KW
                 MOVE 4 TO W-J
                 PERFORM R450-KEYWORD
                 IF W-HIT = 'Y'
                    MOVE N'a JES3 statement' TO W-REFUSAL
                 END-IF
              END-PERFORM
           END-IF
           .
       R430-JES3-END.
           EXIT.

      *===============================================================*
      * R440-USER-PASSWORD: USER= or PASSWORD= on a statement (// not *
      * followed by *), at the start of a parameter                   *
      *===============================================================*
       R440-USER-PASSWORD SECTION.
           IF  W-L-TEXT(1:2) = N'//'
           AND W-L-TEXT(3:1) NOT = N'*'
              PERFORM VARYING W-J FROM 3 BY 1 UNTIL W-J > 76
                 IF  W-L-TEXT(W-J - 1:1) = SPACE
                  OR W-L-TEXT(W-J - 1:1) = N','
                    IF W-L-TEXT(W-J:5) = N'USER='
                       MOVE N'USER= or PASSWORD=' TO W-REFUSAL
                    END-IF
                    IF W-J <= 72
                       IF W-L-TEXT(W-J:9) = N'PASSWORD='
                          MOVE N'USER= or PASSWORD=' TO W-REFUSAL
                       END-IF
                    END-IF
                 END-IF
              END-PERFORM
           END-IF
           .
       R440-USER-PASSWORD-END.
           EXIT.

      *===============================================================*
      * R450-KEYWORD: W-HIT = Y when W-L-TEXT has W-KW at W-J,        *
      * followed by a blank or the end of the line                    *
      *===============================================================*
       R450-KEYWORD SECTION.
           MOVE 'N' TO W-HIT
           MOVE 0 TO W-KWLEN
           INSPECT W-KW TALLYING W-KWLEN FOR CHARACTERS
                   BEFORE INITIAL SPACE
           IF W-J < 1 OR W-J + W-KWLEN - 1 > 80
              MOVE 0 TO W-KWLEN
           END-IF
           IF W-KWLEN > 0
              IF W-L-TEXT(W-J:W-KWLEN) = W-KW(1:W-KWLEN)
                 IF W-J + W-KWLEN > 80
                    MOVE 'Y' TO W-HIT
                 ELSE
                    IF W-L-TEXT(W-J + W-KWLEN:1) = SPACE
                       MOVE 'Y' TO W-HIT
                    END-IF
                 END-IF
              END-IF
           END-IF
           .
       R450-KEYWORD-END.
           EXIT.

      *===============================================================*
      * R500-WARNINGS: Undefined ${NAME}, statements past column 71   *
      *===============================================================*
       R500-WARNINGS SECTION.
           PERFORM VARYING W-I FROM 1 BY 1
                     UNTIL W-I > W-LINE-COUNT
                        OR RETURNCODE OF P-LLWDM410 NOT = N'00'
              MOVE W-LINE-LEN(W-I) TO W-L-LEN
              MOVE W-LINE-TEXT(W-I) TO W-L-TEXT
              PERFORM R510-VARIABLES
              IF  W-L-TEXT(1:2) = N'//'
              AND W-L-TEXT(3:1) NOT = N'*'
              AND W-L-LEN > 71
                 MOVE SPACES TO W-REFUSAL
                 MOVE N'the statement passes column 71' TO W-REFUSAL
                 PERFORM R530-WARN
              END-IF
           END-PERFORM

           IF RETURNCODE OF P-LLWDM410 = N'00'
              MOVE W-WARNING TO INFOMESSAGE OF P-LLWDM410
           END-IF
           .
       R500-WARNINGS-END.
           EXIT.

      *===============================================================*
      * R510-VARIABLES: Every ${NAME} of the line                     *
      *===============================================================*
       R510-VARIABLES SECTION.
           MOVE 1 TO W-J
           PERFORM UNTIL W-J >= W-L-LEN
                      OR RETURNCODE OF P-LLWDM410 NOT = N'00'
              IF W-L-TEXT(W-J:2) = N'${'
                 COMPUTE W-K = W-J + 2
                 MOVE 'N' TO W-HIT
                 PERFORM UNTIL W-K > W-L-LEN OR W-HIT = 'Y'
                    IF W-L-TEXT(W-K:1) = N'}'
                       MOVE 'Y' TO W-HIT
                    ELSE
                       ADD 1 TO W-K
                    END-IF
                 END-PERFORM
                 IF W-K <= W-L-LEN AND W-K - W-J - 2 > 0
                                   AND W-K - W-J - 2 <= 16
                    COMPUTE W-NAME-LEN = W-K - W-J - 2
                    MOVE SPACES TO W-NAME-TEXT
                    MOVE W-L-TEXT(W-J + 2:W-NAME-LEN) TO W-NAME-TEXT
                    PERFORM R520-DEFINED
                 END-IF
                 COMPUTE W-J = W-K + 1
              ELSE
                 ADD 1 TO W-J
              END-IF
           END-PERFORM
           .
       R510-VARIABLES-END.
           EXIT.

      *===============================================================*
      * R520-DEFINED: A warning when W-NAME is no built-in and is     *
      * defined at no level of the application                        *
      *===============================================================*
       R520-DEFINED SECTION.
           IF  W-NAME-TEXT NOT = N'LWDAPP'
           AND W-NAME-TEXT NOT = N'LWDENV'
           AND W-NAME-TEXT NOT = N'LWDVER'
           AND W-NAME-TEXT NOT = N'LWDLOC'
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD007
                  WHERE APPID = :W-APPID
                    AND VARNAME = :W-NAME
              END-EXEC

              EVALUATE TRUE
              WHEN SQLCODE NOT = 0
                 MOVE N'SELECT variables' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              WHEN W-COUNT = 0
                 MOVE SPACES TO W-REFUSAL
                 STRING N'${' DELIMITED BY SIZE
                        W-NAME-TEXT(1:W-NAME-LEN) DELIMITED BY SIZE
                        N'} is defined at no level yet'
                           DELIMITED BY SIZE
                   INTO W-REFUSAL
                 PERFORM R530-WARN
              END-EVALUATE
           END-IF
           .
       R520-DEFINED-END.
           EXIT.

      *===============================================================*
      * R530-WARN: Count the warning in W-REFUSAL of line W-I; keep   *
      * the first                                                     *
      *===============================================================*
       R530-WARN SECTION.
           ADD 1 TO WARNINGCOUNT OF P-LLWDM410
           IF W-WARNING = SPACES
              MOVE W-I TO W-LINE-ED
              STRING N'Line ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-LINE-ED))
                        DELIMITED BY SIZE
                     N': ' DELIMITED BY SIZE
                     W-REFUSAL DELIMITED BY N'  '
                INTO W-WARNING
           END-IF
           .
       R530-WARN-END.
           EXIT.

      *===============================================================*
      * R600-SAVE: Lock the template, the next revision, its lines,   *
      * and CURRENTREV                                                *
      *===============================================================*
       R600-SAVE SECTION.
           IF RETURNCODE OF P-LLWDM410 = N'00'
              EXEC SQL
                 UPDATE TBLWD008
                    SET UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE template' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM410 = N'00'
              EXEC SQL
                 SELECT COALESCE(MAX(REVISION), 0) + 1
                   INTO :W-REVISION
                   FROM TBLWD009
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT revisions' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM410 = N'00'
              MOVE W-LINE-COUNT TO LINECOUNT OF DCLTBLWD009
              EXEC SQL
                 INSERT INTO TBLWD009
                      ( TEMPLATEID, REVISION, CHANGENOTE, LINECOUNT,
                        CREATEDBY, CREATEDDATE,
                        UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-TEMPLATEID,
                          :W-REVISION,
                          :P-LLWDM410.CHANGENOTE :W-NOTE-IND,
                          :DCLTBLWD009.LINECOUNT,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT revision' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           PERFORM VARYING W-I FROM 1 BY 1
                     UNTIL W-I > W-LINE-COUNT
                        OR RETURNCODE OF P-LLWDM410 NOT = N'00'
              MOVE W-LINE-LEN(W-I) TO W-LT-LEN
              MOVE W-LINE-TEXT(W-I) TO W-LT-TEXT
      *       Trailing blanks aren't kept
              MOVE 'N' TO W-HIT
              PERFORM UNTIL W-LT-LEN = 0 OR W-HIT = 'Y'
                 IF W-LT-TEXT(W-LT-LEN:1) = SPACE
                    SUBTRACT 1 FROM W-LT-LEN
                 ELSE
                    MOVE 'Y' TO W-HIT
                 END-IF
              END-PERFORM
              EXEC SQL
                 INSERT INTO TBLWD010
                      ( TEMPLATEID, REVISION, LINENUM, LINETEXT,
                        CREATEDBY, CREATEDDATE,
                        UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-TEMPLATEID,
                          :W-REVISION,
                          :W-I,
                          :W-LT,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT template line' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-PERFORM

           IF RETURNCODE OF P-LLWDM410 = N'00'
              EXEC SQL
                 UPDATE TBLWD008
                    SET CURRENTREV  = :W-REVISION,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE template' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE W-REVISION TO REVISION OF P-LLWDM410
                 MOVE W-LINE-COUNT TO LINECOUNT OF P-LLWDM410
              END-IF
           END-IF
           .
       R600-SAVE-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM410==.

       END PROGRAM LWDM410.
