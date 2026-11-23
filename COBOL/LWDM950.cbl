       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM950.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * The queued notification mails (MAILQUEUE) for LWDC950, which  *
      * the tick's wrapper links to after its commit (S5,             *
      * docs/11-iteration-7.md). LWDC950 commits after every call.    *
      * MAIL-OPCODE:                                                  *
      *   P  The settings MAILWRTR, MAILCLS and MAILMAX (MAIL-MAX 0   *
      *      when MAILWRTR is empty: no mail). New mails older than   *
      *      APPRHRS hours get F: too old to be of use.               *
      *   N  The oldest new mail after MAILID, as SMTP lines for the  *
      *      CSSMTP writer: HELO, MAIL FROM, RCPT TO, DATA, headers,  *
      *      the body wrapped at 72 characters, ".", QUIT. In EBCDIC: *
      *      a character 037 hasn't got becomes "?". MAIL-FOUND N:    *
      *      none left.                                               *
      *   S  Mail MAILID was written: status S, SENTDATE.             *
      *   F  Writing it failed: one more attempt; after 3, status F.  *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 01 = Error: invalid MAIL-OPCODE                            *
      * 08 21/32 = Error: SQL error                                   *
      * 08 90 = Error: a setting is missing (LWDCTXP), or the mail    *
      *         has more lines than REC holds                         *
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

           EXEC SQL INCLUDE TBLWD020 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-MAILWRTR      PIC N(8) VALUE N'MAILWRTR'.
          05 C-MAILCLS       PIC N(8) VALUE N'MAILCLS'.
          05 C-MAILMAX       PIC N(8) VALUE N'MAILMAX'.
          05 C-MAILFROM      PIC N(8) VALUE N'MAILFROM'.
          05 C-APPRHRS       PIC N(8) VALUE N'APPRHRS'.
          05 C-MAXTRIES      PIC S9(4) COMP-5 VALUE 3.
          05 C-WRAP          PIC S9(4) COMP-5 VALUE 72.
          05 C-FOLD          PIC S9(4) COMP-5 VALUE 70.
          05 C-LF            PIC N VALUE NX'000A'.
          05 W-HOURS         PIC S9(9) COMP-5.
          05 W-FROM          PIC X(255).
          05 W-FROM-LEN      PIC S9(4) COMP-5.
          05 W-DOMAIN        PIC X(255).
          05 W-DOMAIN-LEN    PIC S9(4) COMP-5.
          05 W-TO            PIC X(254).
          05 W-TO-LEN        PIC S9(4) COMP-5.
          05 W-AT            PIC S9(4) COMP-5.
          05 W-I             PIC S9(4) COMP-5.
          05 W-P             PIC S9(4) COMP-5.
          05 W-START         PIC S9(4) COMP-5.
          05 W-LEN           PIC S9(4) COMP-5.
          05 W-CUT           PIC S9(4) COMP-5.
          05 W-FOUND         PIC X.
          05 W-NAT           PIC N(255).
          05 W-NAT-LEN       PIC S9(4) COMP-5.
          05 W-LINE          PIC X(255).
          05 W-LINE-LEN      PIC S9(4) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM950.
           COPY LLWDM950.

       PROCEDURE DIVISION USING P-LLWDM950.
       MAIN SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM950
           MOVE N'00' TO REASONCODE OF P-LLWDM950
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM950

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LLWDM950 = N'00'
              EVALUATE TRUE
              WHEN MAIL-PREPARE OF P-LLWDM950
                 PERFORM R100-PREPARE
              WHEN MAIL-NEXT OF P-LLWDM950
                 PERFORM R200-NEXT
              WHEN MAIL-SENT OF P-LLWDM950
                 PERFORM R300-SENT
              WHEN MAIL-FAILED OF P-LLWDM950
                 PERFORM R400-FAILED
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM950
                 MOVE N'01' TO REASONCODE OF P-LLWDM950
                 MOVE N'Invalid MAIL-OPCODE' TO
                      INFOMESSAGE OF P-LLWDM950
              END-EVALUATE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R100-PREPARE: Writer, class and the most mails per tick; old  *
      * new mails dropped                                             *
      *===============================================================*
       R100-PREPARE SECTION.
           MOVE 0 TO MAIL-MAX OF P-LLWDM950
           MOVE 0 TO MAIL-DROPPED OF P-LLWDM950
           MOVE SPACES TO MAIL-WRITER OF P-LLWDM950
           MOVE SPACE TO MAIL-CLASS OF P-LLWDM950

           EXEC SQL
              SELECT TABVALUE
                INTO :W-SETVALUE
                FROM TBLWD001
               WHERE TABLEID = :C-SETTINGS
                 AND TABKEY = :C-MAILWRTR
                 AND TABVALUE IS NOT NULL
           END-EXEC
           EVALUATE SQLCODE
           WHEN 0
              IF W-SETVALUE-LEN > 0
                 MOVE FUNCTION DISPLAY-OF(W-SETVALUE-TEXT(1:
                      W-SETVALUE-LEN)) TO MAIL-WRITER OF P-LLWDM950
              END-IF
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE N'SELECT setting MAILWRTR' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE

           IF  RETURNCODE OF P-LLWDM950 = N'00'
           AND MAIL-WRITER OF P-LLWDM950 NOT = SPACES
              MOVE C-MAILCLS TO W-SETKEY
              PERFORM R091-GET-SETTING
              IF RETURNCODE OF P-LLWDM950 = N'00'
                 MOVE FUNCTION DISPLAY-OF(W-SETVALUE-TEXT(1:1)) TO
                      MAIL-CLASS OF P-LLWDM950
              END-IF

              MOVE C-MAILMAX TO W-SETKEY
              PERFORM R091-GET-SETTING
              IF RETURNCODE OF P-LLWDM950 = N'00'
                 COMPUTE MAIL-MAX OF P-LLWDM950 = FUNCTION NUMVAL(
                    FUNCTION DISPLAY-OF(W-SETVALUE-TEXT(1:
                    W-SETVALUE-LEN)))
              END-IF

              MOVE C-APPRHRS TO W-SETKEY
              PERFORM R091-GET-SETTING
              IF RETURNCODE OF P-LLWDM950 = N'00'
                 COMPUTE W-HOURS = FUNCTION NUMVAL(FUNCTION DISPLAY-OF(
                         W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM950 = N'00'
           AND MAIL-WRITER OF P-LLWDM950 NOT = SPACES
              EXEC SQL
                 UPDATE TBLWD020
                    SET MAILSTATUS  = :C-F,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE MAILSTATUS = :C-N
                    AND CREATEDDATE <
                        CURRENT TIMESTAMP - :W-HOURS HOURS
              END-EXEC
              EVALUATE SQLCODE
              WHEN 0
                 MOVE SQLERRD(3) TO MAIL-DROPPED OF P-LLWDM950
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'UPDATE old mails' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R100-PREPARE-END.
           EXIT.

      *===============================================================*
      * R200-NEXT: The oldest new mail after MAILID, as SMTP lines    *
      *===============================================================*
       R200-NEXT SECTION.
           MOVE 'N' TO MAIL-FOUND OF P-LLWDM950
           MOVE 0 TO REC-COUNT OF P-LLWDM950

           EXEC SQL
              SELECT MAILID,
                     EMAIL,
                     SUBJECT,
                     BODY
                INTO :DCLTBLWD020.MAILID,
                     :DCLTBLWD020.EMAIL,
                     :DCLTBLWD020.SUBJECT,
                     :DCLTBLWD020.BODY
                FROM TBLWD020
               WHERE MAILSTATUS = :C-N
                 AND MAILID > :P-LLWDM950.MAILID
               ORDER BY MAILID
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE 'Y' TO MAIL-FOUND OF P-LLWDM950
              MOVE MAILID OF DCLTBLWD020 TO MAILID OF P-LLWDM950
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE N'SELECT mail' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE

           IF  RETURNCODE OF P-LLWDM950 = N'00'
           AND MAIL-FOUND OF P-LLWDM950 = 'Y'
              MOVE C-MAILFROM TO W-SETKEY
              PERFORM R091-GET-SETTING
           END-IF

           IF  RETURNCODE OF P-LLWDM950 = N'00'
           AND MAIL-FOUND OF P-LLWDM950 = 'Y'
              PERFORM R210-ADDRESSES
              PERFORM R220-ENVELOPE
              PERFORM R230-SUBJECT
              PERFORM R240-BODY
              MOVE '.' TO W-LINE
              MOVE 1 TO W-LINE-LEN
              PERFORM R800-ADD-LINE
              MOVE 'QUIT' TO W-LINE
              MOVE 4 TO W-LINE-LEN
              PERFORM R800-ADD-LINE
           END-IF
           .
       R200-NEXT-END.
           EXIT.

      *===============================================================*
      * R210-ADDRESSES: Sender, its domain for HELO, and recipient,   *
      * in EBCDIC                                                     *
      *===============================================================*
       R210-ADDRESSES SECTION.
           MOVE W-SETVALUE-TEXT(1:W-SETVALUE-LEN) TO W-NAT
           MOVE W-SETVALUE-LEN TO W-NAT-LEN
           PERFORM R810-TO-EBCDIC
           MOVE W-LINE TO W-FROM
           MOVE W-LINE-LEN TO W-FROM-LEN

           MOVE 0 TO W-AT
           PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > W-FROM-LEN
              IF W-FROM(W-I:1) = '@'
                 MOVE W-I TO W-AT
              END-IF
           END-PERFORM
           MOVE SPACES TO W-DOMAIN
           IF W-AT > 0 AND W-AT < W-FROM-LEN
              COMPUTE W-DOMAIN-LEN = W-FROM-LEN - W-AT
              MOVE W-FROM(W-AT + 1:W-DOMAIN-LEN) TO W-DOMAIN
           ELSE
              MOVE 'localhost' TO W-DOMAIN
              MOVE 9 TO W-DOMAIN-LEN
           END-IF

           MOVE EMAIL-TEXT OF DCLTBLWD020(1:EMAIL-LEN OF DCLTBLWD020)
             TO W-NAT
           MOVE EMAIL-LEN OF DCLTBLWD020 TO W-NAT-LEN
           PERFORM R810-TO-EBCDIC
           MOVE W-LINE TO W-TO
           MOVE W-LINE-LEN TO W-TO-LEN
           .
       R210-ADDRESSES-END.
           EXIT.

      *===============================================================*
      * R220-ENVELOPE: The SMTP commands and the From and To headers  *
      *===============================================================*
       R220-ENVELOPE SECTION.
           MOVE SPACES TO W-LINE
           STRING 'HELO ' W-DOMAIN(1:W-DOMAIN-LEN)
                  DELIMITED BY SIZE INTO W-LINE
           COMPUTE W-LINE-LEN = 5 + W-DOMAIN-LEN
           PERFORM R800-ADD-LINE

           MOVE SPACES TO W-LINE
           STRING 'MAIL FROM:<' W-FROM(1:W-FROM-LEN) '>'
                  DELIMITED BY SIZE INTO W-LINE
           COMPUTE W-LINE-LEN = 12 + W-FROM-LEN
           PERFORM R800-ADD-LINE

           MOVE SPACES TO W-LINE
           STRING 'RCPT TO:<' W-TO(1:W-TO-LEN) '>'
                  DELIMITED BY SIZE INTO W-LINE
           COMPUTE W-LINE-LEN = 10 + W-TO-LEN
           PERFORM R800-ADD-LINE

           MOVE 'DATA' TO W-LINE
           MOVE 4 TO W-LINE-LEN
           PERFORM R800-ADD-LINE

           MOVE SPACES TO W-LINE
           STRING 'From: LWD <' W-FROM(1:W-FROM-LEN) '>'
                  DELIMITED BY SIZE INTO W-LINE
           COMPUTE W-LINE-LEN = 12 + W-FROM-LEN
           PERFORM R800-ADD-LINE

           MOVE SPACES TO W-LINE
           STRING 'To: <' W-TO(1:W-TO-LEN) '>'
                  DELIMITED BY SIZE INTO W-LINE
           COMPUTE W-LINE-LEN = 6 + W-TO-LEN
           PERFORM R800-ADD-LINE
           .
       R220-ENVELOPE-END.
           EXIT.

      *===============================================================*
      * R230-SUBJECT: Folded every 70 characters, the continuations   *
      * starting with a blank; then the empty line before the body    *
      *===============================================================*
       R230-SUBJECT SECTION.
           MOVE 1 TO W-START
           PERFORM UNTIL W-START > SUBJECT-LEN OF DCLTBLWD020
              COMPUTE W-LEN = FUNCTION MIN(C-FOLD,
                      SUBJECT-LEN OF DCLTBLWD020 - W-START + 1)
              MOVE SUBJECT-TEXT OF DCLTBLWD020(W-START:W-LEN) TO W-NAT
              MOVE W-LEN TO W-NAT-LEN
              PERFORM R810-TO-EBCDIC
              MOVE W-LINE TO W-DOMAIN
              MOVE SPACES TO W-LINE
              IF W-START = 1
                 STRING 'Subject: ' W-DOMAIN(1:W-LINE-LEN)
                        DELIMITED BY SIZE INTO W-LINE
                 ADD 9 TO W-LINE-LEN
              ELSE
                 STRING ' ' W-DOMAIN(1:W-LINE-LEN)
                        DELIMITED BY SIZE INTO W-LINE
                 ADD 1 TO W-LINE-LEN
              END-IF
              PERFORM R800-ADD-LINE
              ADD W-LEN TO W-START
           END-PERFORM

           MOVE SPACES TO W-LINE
           MOVE 0 TO W-LINE-LEN
           PERFORM R800-ADD-LINE
           .
       R230-SUBJECT-END.
           EXIT.

      *===============================================================*
      * R240-BODY: Lines at LF, each wrapped at 72 characters at the  *
      * last blank (or cut when there is none)                        *
      *===============================================================*
       R240-BODY SECTION.
           MOVE 1 TO W-START
           PERFORM VARYING W-P FROM 1 BY 1
                     UNTIL W-P > BODY-LEN OF DCLTBLWD020 + 1
              IF W-P > BODY-LEN OF DCLTBLWD020
                 PERFORM R250-BODY-LINE
              ELSE
                 IF BODY-TEXT OF DCLTBLWD020(W-P:1) = C-LF
                    PERFORM R250-BODY-LINE
                    COMPUTE W-START = W-P + 1
                 END-IF
              END-IF
           END-PERFORM
           .
       R240-BODY-END.
           EXIT.

      *===============================================================*
      * R250-BODY-LINE: BODY from W-START up to W-P - 1, wrapped      *
      *===============================================================*
       R250-BODY-LINE SECTION.
           COMPUTE W-LEN = W-P - W-START
           IF W-LEN = 0
              MOVE SPACES TO W-LINE
              MOVE 0 TO W-LINE-LEN
              PERFORM R800-ADD-LINE
           END-IF
           PERFORM UNTIL W-LEN <= 0
              IF W-LEN <= C-WRAP
                 MOVE W-LEN TO W-CUT
              ELSE
      *          The last blank within 72, else a cut at 72
                 MOVE C-WRAP TO W-CUT
                 MOVE 'N' TO W-FOUND
                 PERFORM VARYING W-I FROM C-WRAP BY -1
                           UNTIL W-I < 2 OR W-FOUND = 'Y'
                    IF BODY-TEXT OF DCLTBLWD020(W-START + W-I - 1:1)
                       = SPACE
                       MOVE W-I TO W-CUT
                       MOVE 'Y' TO W-FOUND
                    END-IF
                 END-PERFORM
              END-IF
              MOVE BODY-TEXT OF DCLTBLWD020(W-START:W-CUT) TO W-NAT
              MOVE W-CUT TO W-NAT-LEN
              PERFORM R810-TO-EBCDIC
      *       A line starting with a dot gets one more (RFC 5321)
              IF W-LINE-LEN > 0 AND W-LINE(1:1) = '.'
                 MOVE W-LINE TO W-DOMAIN
                 MOVE SPACES TO W-LINE
                 STRING '.' W-DOMAIN(1:W-LINE-LEN)
                        DELIMITED BY SIZE INTO W-LINE
                 ADD 1 TO W-LINE-LEN
              END-IF
              PERFORM R800-ADD-LINE
              ADD W-CUT TO W-START
              SUBTRACT W-CUT FROM W-LEN
           END-PERFORM
           .
       R250-BODY-LINE-END.
           EXIT.

      *===============================================================*
      * R300-SENT: Mail MAILID went to the writer                     *
      *===============================================================*
       R300-SENT SECTION.
           EXEC SQL
              UPDATE TBLWD020
                 SET MAILSTATUS  = :C-S,
                     ATTEMPTS    = ATTEMPTS + 1,
                     SENTDATE    = CURRENT TIMESTAMP,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE MAILID = :P-LLWDM950.MAILID
           END-EXEC
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE N'UPDATE mail sent' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R300-SENT-END.
           EXIT.

      *===============================================================*
      * R400-FAILED: One more attempt; after the third, F             *
      *===============================================================*
       R400-FAILED SECTION.
           EXEC SQL
              UPDATE TBLWD020
                 SET ATTEMPTS    = ATTEMPTS + 1,
                     MAILSTATUS  = CASE WHEN ATTEMPTS + 1 >= :C-MAXTRIES
                                        THEN :C-F ELSE :C-N END,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE MAILID = :P-LLWDM950.MAILID
           END-EXEC
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE N'UPDATE mail failed' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R400-FAILED-END.
           EXIT.

      *===============================================================*
      * R800-ADD-LINE: W-LINE(1:W-LINE-LEN) as the next record        *
      *===============================================================*
       R800-ADD-LINE SECTION.
           IF REC-COUNT OF P-LLWDM950 >= 60
              IF RETURNCODE OF P-LLWDM950 = N'00'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM950
                 MOVE N'90' TO REASONCODE OF P-LLWDM950
                 MOVE N'The mail has more than 60 lines' TO
                      INFOMESSAGE OF P-LLWDM950
              END-IF
           ELSE
              IF W-LINE-LEN > LENGTH OF W-LINE
                 MOVE LENGTH OF W-LINE TO W-LINE-LEN
              END-IF
              ADD 1 TO REC-COUNT OF P-LLWDM950
              MOVE REC-COUNT OF P-LLWDM950 TO W-I
              MOVE W-LINE TO REC OF P-LLWDM950(W-I)
              MOVE W-LINE-LEN TO REC-LEN OF P-LLWDM950(W-I)
           END-IF
           .
       R800-ADD-LINE-END.
           EXIT.

      *===============================================================*
      * R810-TO-EBCDIC: W-NAT(1:W-NAT-LEN) into W-LINE, W-LINE-LEN;   *
      * what 037 hasn't got becomes ?                                 *
      *===============================================================*
       R810-TO-EBCDIC SECTION.
           MOVE SPACES TO W-LINE
           MOVE 0 TO W-LINE-LEN
           IF W-NAT-LEN > 0
              MOVE FUNCTION DISPLAY-OF(W-NAT(1:W-NAT-LEN)) TO W-LINE
              MOVE W-NAT-LEN TO W-LINE-LEN
              INSPECT W-LINE(1:W-LINE-LEN) REPLACING ALL X'3F' BY '?'
           END-IF
           .
       R810-TO-EBCDIC-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM950==.

       END PROGRAM LWDM950.
