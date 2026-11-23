       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM001.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST, PUT and DELETE /admin/refTables (A3, A5): an entry of   *
      * reference table TABLEID with key TABKEY, by OPCODE C, U or D  *
      * (an LWW constant per path). Administrators only.              *
      * RACFGRP, DEPLUSER: keys in RACF form (A-Z # $ @ first, then   *
      * also 0-9, at most 8), values are descriptions. An entry still *
      * used by an application or environment can't be deleted; the  *
      * message names one use.                                        *
      * SETTINGS: only updated, and only the keys below, each checked:*
      *   APPRHRS 1-720, JOBMINS 5-1440, OUTDAYS 1-3650,              *
      *   OUTLINES 1000-500000, GRPMINS 1-1440, JOBCLASS and MSGCLASS *
      *   one character A-Z 0-9, MAILFROM an email address, MAILURL   *
      *   http:// or https://. The others come from envs/<env>.yaml   *
      *   through DDL/SETTINGS, or (LASTTICK) from the scheduler.     *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 01 = Error: invalid OPCODE, or tabKey empty                *
      * 08 02 = Error: tableID, tabKey or a setting's value not valid *
      * 08 11 = Error: the key is in the table already                *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 31 = Error: update of a missing entry                      *
      * 08 41 = Error: delete of a missing entry                      *
      * 08 50 = Error: not an administrator, or a setting that can't  *
      *         be created, changed or deleted here                   *
      * 08 53 = Error: delete of an entry still in use                *
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

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-FIRST       PIC N(29) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$@'.
          05 C-NAME        PIC N(39) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$@0123456789'.
          05 C-CLASS       PIC N(36) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.
          05 C-DIGITS      PIC N(10) VALUE N'0123456789'.
          05 W-I           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-AT          PIC S9(4) COMP-5.
          05 W-LEN         PIC S9(4) COMP-5.
          05 W-END         PIC X.
          05 W-CH          PIC N.
          05 W-WRONG       PIC N(40).
          05 W-VALUE-IND   PIC S9(4) COMP-5.
          05 W-MIN         PIC S9(9) COMP-5.
          05 W-MAX         PIC S9(9) COMP-5.
          05 W-NUM         PIC S9(9) COMP-5.
          05 W-MIN-ED      PIC Z(8)9.
          05 W-MAX-ED      PIC Z(8)9.
          05 W-USE         PIC X(8).
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM001.
           COPY LLWDM001.

       PROCEDURE DIVISION USING P-LLWDM001.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R098-REQUIRE-ADMIN

           IF RETURNCODE OF P-LLWDM001 = N'00'
              EVALUATE OPCODE OF P-LLWDM001
              WHEN C-C
                 PERFORM R200-CHECK-NEW
                 PERFORM R300-INSERT
                 PERFORM R800-SELECT
              WHEN C-U
                 PERFORM R400-EXISTS
                 PERFORM R500-CHECK-SETTING
                 PERFORM R510-UPDATE
                 PERFORM R800-SELECT
              WHEN C-D
                 PERFORM R600-CHECK-DELETE
                 PERFORM R610-DELETE
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'01' TO REASONCODE OF P-LLWDM001
                 MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM001
              END-EVALUATE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations; table and key upper case, *
      * the value without trailing blanks                             *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM001
           MOVE N'00' TO REASONCODE OF P-LLWDM001
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM001

      *    A missing optional field arrives as binary zeros
           IF TABLEID OF P-LLWDM001(1:1) = NX'0000'
              MOVE SPACES TO TABLEID OF P-LLWDM001
           END-IF
           IF TABKEY OF P-LLWDM001(1:1) = NX'0000'
              MOVE SPACES TO TABKEY OF P-LLWDM001
           END-IF
           MOVE FUNCTION UPPER-CASE(TABLEID OF P-LLWDM001) TO
                TABLEID OF P-LLWDM001
           MOVE FUNCTION UPPER-CASE(TABKEY OF P-LLWDM001) TO
                TABKEY OF P-LLWDM001

           IF  TABVALUE-LEN OF P-LLWDM001 < 0
           OR  TABVALUE-LEN OF P-LLWDM001 > 255
              MOVE 0 TO TABVALUE-LEN OF P-LLWDM001
           END-IF
           MOVE TABVALUE-LEN OF P-LLWDM001 TO W-LEN
           MOVE 'N' TO W-END
           PERFORM UNTIL W-LEN = 0 OR W-END = 'Y'
              IF TABVALUE-TEXT OF P-LLWDM001(W-LEN:1) = SPACE
                 SUBTRACT 1 FROM W-LEN
              ELSE
                 MOVE 'Y' TO W-END
              END-IF
           END-PERFORM
           MOVE W-LEN TO TABVALUE-LEN OF P-LLWDM001
           IF W-LEN > 0
              MOVE 0 TO W-VALUE-IND
           ELSE
              MOVE -1 TO W-VALUE-IND
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-CHECK-NEW: Only allowlist entries are created, with a    *
      * key in RACF form                                              *
      *===============================================================*
       R200-CHECK-NEW SECTION.
           IF RETURNCODE OF P-LLWDM001 = N'00'
              EVALUATE TRUE
              WHEN TABLEID OF P-LLWDM001 = C-SETTINGS
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'50' TO REASONCODE OF P-LLWDM001
                 MOVE N'Settings are never created here' TO
                      INFOMESSAGE OF P-LLWDM001
              WHEN TABLEID OF P-LLWDM001 NOT = C-RACFGRP
               AND TABLEID OF P-LLWDM001 NOT = C-DEPLUSER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'02' TO REASONCODE OF P-LLWDM001
                 MOVE N'tableID: RACFGRP or DEPLUSER' TO
                      INFOMESSAGE OF P-LLWDM001
              WHEN TABKEY OF P-LLWDM001 = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'01' TO REASONCODE OF P-LLWDM001
                 MOVE N'tabKey is required' TO
                      INFOMESSAGE OF P-LLWDM001
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LLWDM001 = N'00'
              PERFORM R210-RACF-NAME
           END-IF
           .
       R200-CHECK-NEW-END.
           EXIT.

      *===============================================================*
      * R210-RACF-NAME: TABKEY is A-Z # $ @ first, then also 0-9, no  *
      * blank inside                                                  *
      *===============================================================*
       R210-RACF-NAME SECTION.
           MOVE 'N' TO W-END
           PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > 8
              MOVE TABKEY OF P-LLWDM001(W-I:1) TO W-CH
              IF W-CH = SPACE
                 MOVE 'Y' TO W-END
              ELSE
                 MOVE 0 TO W-T
                 IF W-I = 1
                    INSPECT C-FIRST TALLYING W-T FOR ALL W-CH
                 ELSE
                    INSPECT C-NAME TALLYING W-T FOR ALL W-CH
                 END-IF
                 IF  (W-T = 0 OR W-END = 'Y')
                 AND RETURNCODE OF P-LLWDM001 = N'00'
                    MOVE N'08' TO RETURNCODE OF P-LLWDM001
                    MOVE N'02' TO REASONCODE OF P-LLWDM001
                    STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                           N' is not a RACF name' DELIMITED BY SIZE
                      INTO INFOMESSAGE OF P-LLWDM001
                 END-IF
              END-IF
           END-PERFORM
           .
       R210-RACF-NAME-END.
           EXIT.

      *===============================================================*
      * R300-INSERT: The new entry                                    *
      *===============================================================*
       R300-INSERT SECTION.
           IF RETURNCODE OF P-LLWDM001 = N'00'
              EXEC SQL
                 INSERT INTO TBLWD001
                      ( TABLEID, TABKEY, TABVALUE,
                        CREATEDBY, CREATEDDATE,
                        UPDATEDBY, UPDATEDDATE )
                 VALUES ( :P-LLWDM001.TABLEID,
                          :P-LLWDM001.TABKEY,
                          :P-LLWDM001.TABVALUE :W-VALUE-IND,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'11' TO REASONCODE OF P-LLWDM001
                 STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                        N' is in the list already' DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM001
              WHEN OTHER
                 MOVE N'INSERT reference entry' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R300-INSERT-END.
           EXIT.

      *===============================================================*
      * R400-EXISTS: The entry of U exists (08 31)                    *
      *===============================================================*
       R400-EXISTS SECTION.
           IF RETURNCODE OF P-LLWDM001 = N'00'
              EXEC SQL
                 SELECT TABKEY
                   INTO :DCLTBLWD001.TABKEY
                   FROM TBLWD001
                  WHERE TABLEID = :P-LLWDM001.TABLEID
                    AND TABKEY  = :P-LLWDM001.TABKEY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 PERFORM R410-NOT-FOUND
                 MOVE N'31' TO REASONCODE OF P-LLWDM001
              WHEN OTHER
                 MOVE N'SELECT reference entry' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R400-EXISTS-END.
           EXIT.

      *===============================================================*
      * R410-NOT-FOUND: "<table> <key> not found"; the caller sets    *
      * the reason code                                               *
      *===============================================================*
       R410-NOT-FOUND SECTION.
           MOVE N'08' TO RETURNCODE OF P-LLWDM001
           STRING TABLEID OF P-LLWDM001 DELIMITED BY N' '
                  N' ' DELIMITED BY SIZE
                  TABKEY OF P-LLWDM001 DELIMITED BY N' '
                  N' not found' DELIMITED BY SIZE
             INTO INFOMESSAGE OF P-LLWDM001
           .
       R410-NOT-FOUND-END.
           EXIT.

      *===============================================================*
      * R500-CHECK-SETTING: A setting may be changed only when it is  *
      * one of the editable keys, and its value fits                  *
      *===============================================================*
       R500-CHECK-SETTING SECTION.
           IF  RETURNCODE OF P-LLWDM001 = N'00'
           AND TABLEID OF P-LLWDM001 = C-SETTINGS
              MOVE SPACES TO W-WRONG
              EVALUATE TABKEY OF P-LLWDM001
              WHEN N'APPRHRS'
                 MOVE 1 TO W-MIN
                 MOVE 720 TO W-MAX
                 PERFORM R520-RANGE
              WHEN N'JOBMINS'
                 MOVE 5 TO W-MIN
                 MOVE 1440 TO W-MAX
                 PERFORM R520-RANGE
              WHEN N'OUTDAYS'
                 MOVE 1 TO W-MIN
                 MOVE 3650 TO W-MAX
                 PERFORM R520-RANGE
              WHEN N'OUTLINES'
                 MOVE 1000 TO W-MIN
                 MOVE 500000 TO W-MAX
                 PERFORM R520-RANGE
              WHEN N'GRPMINS'
                 MOVE 1 TO W-MIN
                 MOVE 1440 TO W-MAX
                 PERFORM R520-RANGE
              WHEN N'JOBCLASS'
              WHEN N'MSGCLASS'
                 PERFORM R530-CLASS
              WHEN N'MAILFROM'
                 PERFORM R540-EMAIL
              WHEN N'MAILURL'
                 PERFORM R550-URL
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'50' TO REASONCODE OF P-LLWDM001
                 STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                        N' comes from envs/<env>.yaml' DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM001
              END-EVALUATE

              IF W-WRONG NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM001
                 MOVE N'02' TO REASONCODE OF P-LLWDM001
                 STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                        N': ' DELIMITED BY SIZE
                        W-WRONG DELIMITED BY N'  '
                   INTO INFOMESSAGE OF P-LLWDM001
              END-IF
           END-IF
           .
       R500-CHECK-SETTING-END.
           EXIT.

      *===============================================================*
      * R510-UPDATE: The value or description                         *
      *===============================================================*
       R510-UPDATE SECTION.
           IF RETURNCODE OF P-LLWDM001 = N'00'
              EXEC SQL
                 UPDATE TBLWD001
                    SET TABVALUE    = :P-LLWDM001.TABVALUE
                                         :W-VALUE-IND,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE TABLEID = :P-LLWDM001.TABLEID
                    AND TABKEY  = :P-LLWDM001.TABKEY
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'UPDATE reference entry' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R510-UPDATE-END.
           EXIT.

      *===============================================================*
      * R520-RANGE: A whole number from W-MIN to W-MAX                *
      *===============================================================*
       R520-RANGE SECTION.
           MOVE 'N' TO W-END
           IF W-LEN < 1 OR W-LEN > 6
              MOVE 'Y' TO W-END
           ELSE
              PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > W-LEN
                 MOVE TABVALUE-TEXT OF P-LLWDM001(W-I:1) TO W-CH
                 MOVE 0 TO W-T
                 INSPECT C-DIGITS TALLYING W-T FOR ALL W-CH
                 IF W-T = 0
                    MOVE 'Y' TO W-END
                 END-IF
              END-PERFORM
           END-IF

           IF W-END = 'N'
              COMPUTE W-NUM = FUNCTION NUMVAL(FUNCTION DISPLAY-OF(
                      TABVALUE-TEXT OF P-LLWDM001(1:W-LEN)))
              IF W-NUM < W-MIN OR W-NUM > W-MAX
                 MOVE 'Y' TO W-END
              END-IF
           END-IF

           IF W-END = 'Y'
              MOVE W-MIN TO W-MIN-ED
              MOVE W-MAX TO W-MAX-ED
              STRING N'a whole number from ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-MIN-ED))
                        DELIMITED BY SIZE
                     N' to ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-MAX-ED))
                        DELIMITED BY SIZE
                INTO W-WRONG
           END-IF
           .
       R520-RANGE-END.
           EXIT.

      *===============================================================*
      * R530-CLASS: One character, A-Z or 0-9, upper case             *
      *===============================================================*
       R530-CLASS SECTION.
           MOVE FUNCTION UPPER-CASE(TABVALUE-TEXT OF P-LLWDM001) TO
                TABVALUE-TEXT OF P-LLWDM001
           MOVE 0 TO W-T
           IF W-LEN = 1
              MOVE TABVALUE-TEXT OF P-LLWDM001(1:1) TO W-CH
              INSPECT C-CLASS TALLYING W-T FOR ALL W-CH
           END-IF
           IF W-T = 0
              MOVE N'one character, A-Z or 0-9' TO W-WRONG
           END-IF
           .
       R530-CLASS-END.
           EXIT.

      *===============================================================*
      * R540-EMAIL: No blank, one @ that is neither first nor last,   *
      * and a dot after it that isn't last                            *
      *===============================================================*
       R540-EMAIL SECTION.
           MOVE 'N' TO W-END
           MOVE 0 TO W-AT
           IF W-LEN < 5
              MOVE 'Y' TO W-END
           ELSE
              MOVE 0 TO W-T
              INSPECT TABVALUE-TEXT OF P-LLWDM001(1:W-LEN)
                 TALLYING W-T FOR ALL N' '
              IF W-T > 0
                 MOVE 'Y' TO W-END
              END-IF
              MOVE 0 TO W-T
              INSPECT TABVALUE-TEXT OF P-LLWDM001(1:W-LEN)
                 TALLYING W-T FOR ALL N'@'
              IF W-T NOT = 1
                 MOVE 'Y' TO W-END
              END-IF
           END-IF

           IF W-END = 'N'
              PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > W-LEN
                 IF TABVALUE-TEXT OF P-LLWDM001(W-I:1) = N'@'
                    MOVE W-I TO W-AT
                 END-IF
              END-PERFORM
              IF W-AT < 2 OR W-AT > W-LEN - 3
              OR TABVALUE-TEXT OF P-LLWDM001(W-LEN:1) = N'.'
                 MOVE 'Y' TO W-END
              ELSE
                 MOVE 0 TO W-T
                 INSPECT TABVALUE-TEXT OF P-LLWDM001(W-AT + 1:
                         W-LEN - W-AT) TALLYING W-T FOR ALL N'.'
                 IF W-T = 0
                    MOVE 'Y' TO W-END
                 END-IF
              END-IF
           END-IF

           IF W-END = 'Y'
              MOVE N'an email address' TO W-WRONG
           END-IF
           .
       R540-EMAIL-END.
           EXIT.

      *===============================================================*
      * R550-URL: http:// or https:// and more, no blank              *
      *===============================================================*
       R550-URL SECTION.
           MOVE 'Y' TO W-END
           IF  W-LEN > 8
           AND TABVALUE-TEXT OF P-LLWDM001(1:8) = N'https://'
              MOVE 'N' TO W-END
           END-IF
           IF  W-LEN > 7
           AND TABVALUE-TEXT OF P-LLWDM001(1:7) = N'http://'
              MOVE 'N' TO W-END
           END-IF
           IF W-END = 'N'
              MOVE 0 TO W-T
              INSPECT TABVALUE-TEXT OF P-LLWDM001(1:W-LEN)
                 TALLYING W-T FOR ALL N' '
              IF W-T > 0
                 MOVE 'Y' TO W-END
              END-IF
           END-IF

           IF W-END = 'Y'
              MOVE N'a URL starting with https://' TO W-WRONG
           END-IF
           .
       R550-URL-END.
           EXIT.

      *===============================================================*
      * R600-CHECK-DELETE: No settings; the entry exists (08 41) and  *
      * nothing uses it (08 53, naming one use)                       *
      *===============================================================*
       R600-CHECK-DELETE SECTION.
           IF  RETURNCODE OF P-LLWDM001 = N'00'
           AND TABLEID OF P-LLWDM001 = C-SETTINGS
              MOVE N'08' TO RETURNCODE OF P-LLWDM001
              MOVE N'50' TO REASONCODE OF P-LLWDM001
              MOVE N'Settings are never deleted' TO
                   INFOMESSAGE OF P-LLWDM001
           END-IF

           IF RETURNCODE OF P-LLWDM001 = N'00'
              EXEC SQL
                 SELECT TABKEY
                   INTO :DCLTBLWD001.TABKEY
                   FROM TBLWD001
                  WHERE TABLEID = :P-LLWDM001.TABLEID
                    AND TABKEY  = :P-LLWDM001.TABKEY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 PERFORM R410-NOT-FOUND
                 MOVE N'41' TO REASONCODE OF P-LLWDM001
              WHEN OTHER
                 MOVE N'SELECT reference entry' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF P-LLWDM001 = N'00'
           AND TABLEID OF P-LLWDM001 = C-RACFGRP
              PERFORM R620-GROUP-USED
           END-IF

           IF  RETURNCODE OF P-LLWDM001 = N'00'
           AND TABLEID OF P-LLWDM001 = C-DEPLUSER
              EXEC SQL
                 SELECT A.APPCODE,
                        E.ENVCODE
                   INTO :DCLTBLWD004.APPCODE,
                        :DCLTBLWD006.ENVCODE
                   FROM TBLWD006 E
                   JOIN TBLWD004 A
                     ON A.APPID = E.APPID
                  WHERE E.DEPLOYUSER = :P-LLWDM001.TABKEY
                  FETCH FIRST 1 ROW ONLY
              END-EXEC
              MOVE 'deploy  ' TO W-USE
              PERFORM R640-ENV-USE
           END-IF
           .
       R600-CHECK-DELETE-END.
           EXIT.

      *===============================================================*
      * R610-DELETE: The entry                                        *
      *===============================================================*
       R610-DELETE SECTION.
           IF RETURNCODE OF P-LLWDM001 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD001
                  WHERE TABLEID = :P-LLWDM001.TABLEID
                    AND TABKEY  = :P-LLWDM001.TABKEY
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'DELETE reference entry' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R610-DELETE-END.
           EXIT.

      *===============================================================*
      * R620-GROUP-USED: A group as access or owner group of an       *
      * application, or approver or deployer group of an environment  *
      *===============================================================*
       R620-GROUP-USED SECTION.
           EXEC SQL
              SELECT APPCODE,
                     CASE WHEN ACCESSGROUP = :P-LLWDM001.TABKEY
                          THEN 'access' ELSE 'owner' END
                INTO :DCLTBLWD004.APPCODE,
                     :W-USE
                FROM TBLWD004
               WHERE ACCESSGROUP = :P-LLWDM001.TABKEY
                  OR OWNERGROUP  = :P-LLWDM001.TABKEY
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM001
              MOVE N'53' TO REASONCODE OF P-LLWDM001
              STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                     N' is still used: ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(W-USE) DELIMITED BY N' '
                     N' group of ' DELIMITED BY SIZE
                     APPCODE OF DCLTBLWD004 DELIMITED BY N' '
                INTO INFOMESSAGE OF P-LLWDM001
           WHEN 100
              EXEC SQL
                 SELECT A.APPCODE,
                        E.ENVCODE,
                        CASE WHEN E.APPROVERGROUP = :P-LLWDM001.TABKEY
                             THEN 'approver' ELSE 'deployer' END
                   INTO :DCLTBLWD004.APPCODE,
                        :DCLTBLWD006.ENVCODE,
                        :W-USE
                   FROM TBLWD006 E
                   JOIN TBLWD004 A
                     ON A.APPID = E.APPID
                  WHERE E.APPROVERGROUP = :P-LLWDM001.TABKEY
                     OR E.DEPLOYERGROUP = :P-LLWDM001.TABKEY
                  FETCH FIRST 1 ROW ONLY
              END-EXEC
              PERFORM R640-ENV-USE
           WHEN OTHER
              MOVE N'SELECT applications' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R620-GROUP-USED-END.
           EXIT.

      *===============================================================*
      * R640-ENV-USE: After a SELECT of an environment that uses the  *
      * entry as W-USE: 08 53 when found                              *
      *===============================================================*
       R640-ENV-USE SECTION.
           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM001
              MOVE N'53' TO REASONCODE OF P-LLWDM001
              IF W-USE = 'deploy'
                 STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                        N' is still used: deploy userid of '
                           DELIMITED BY SIZE
                        APPCODE OF DCLTBLWD004 DELIMITED BY N' '
                        N' ' DELIMITED BY SIZE
                        ENVCODE OF DCLTBLWD006 DELIMITED BY N' '
                   INTO INFOMESSAGE OF P-LLWDM001
              ELSE
                 STRING TABKEY OF P-LLWDM001 DELIMITED BY N' '
                        N' is still used: ' DELIMITED BY SIZE
                        FUNCTION NATIONAL-OF(W-USE) DELIMITED BY N' '
                        N' group of ' DELIMITED BY SIZE
                        APPCODE OF DCLTBLWD004 DELIMITED BY N' '
                        N' ' DELIMITED BY SIZE
                        ENVCODE OF DCLTBLWD006 DELIMITED BY N' '
                   INTO INFOMESSAGE OF P-LLWDM001
              END-IF
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE N'SELECT environments' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R640-ENV-USE-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The entry as the response                        *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM001 = N'00'
              EXEC SQL
                 SELECT TABVALUE,
                        CREATEDBY,
                        CHAR(CREATEDDATE),
                        UPDATEDBY,
                        CHAR(UPDATEDDATE)
                   INTO :DCLTBLWD001.TABVALUE
                           :DCLTBLWD001.TABVALUE-IND,
                        :DCLTBLWD001.CREATEDBY,
                        :W-CREATED,
                        :DCLTBLWD001.UPDATEDBY,
                        :W-UPDATED
                   FROM TBLWD001
                  WHERE TABLEID = :P-LLWDM001.TABLEID
                    AND TABKEY  = :P-LLWDM001.TABKEY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 IF TABVALUE-IND OF DCLTBLWD001 >= 0
                    MOVE TABVALUE OF DCLTBLWD001 TO
                         TABVALUE OF P-LLWDM001
                 ELSE
                    MOVE 0 TO TABVALUE-LEN OF P-LLWDM001
                 END-IF
                 MOVE CREATEDBY OF DCLTBLWD001 TO
                      CREATEDBY OF P-LLWDM001
                 MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                      CREATEDDATE OF P-LLWDM001
                 MOVE UPDATEDBY OF DCLTBLWD001 TO
                      UPDATEDBY OF P-LLWDM001
                 MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                      UPDATEDDATE OF P-LLWDM001
              WHEN OTHER
                 MOVE N'SELECT reference entry' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R800-SELECT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM001==.

       END PROGRAM LWDM001.
