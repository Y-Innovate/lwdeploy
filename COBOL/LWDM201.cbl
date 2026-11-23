       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM201.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /admin/refTables?tableID= (A3, A5): one reference table,  *
      * by key: RACFGRP (allowed RACF groups), DEPLUSER (allowed      *
      * deploy userids) or SETTINGS. Administrators only.             *
      * TABKEY-SINCE: paging, entries after this key (blank = start). *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when the table is empty                 *
      * 08 02 = Error: tableID is not RACFGRP, DEPLUSER or SETTINGS   *
      * 08 21 = Error: SQL error on OPEN/FETCH                        *
      * 08 50 = Error: not an administrator                           *
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

           COPY LWDCTXW.

       01 WORK.
          05 W-TABLEID     PIC N(8).
          05 W-SINCE       PIC N(8).
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM201.
           COPY LLWDM201.

       PROCEDURE DIVISION USING P-LLWDM201.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R098-REQUIRE-ADMIN

           IF RETURNCODE OF P-LLWDM201 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations and the table              *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM201
           MOVE N'00' TO REASONCODE OF P-LLWDM201
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM201

           MOVE 0 TO REF-COUNT OF P-LLWDM201
           MOVE FUNCTION UPPER-CASE(TABLEID OF P-LLWDM201) TO W-TABLEID
           MOVE TABKEY-SINCE OF P-LLWDM201 TO W-SINCE

      *    A missing optional field arrives as binary zeros
           IF W-SINCE(1:1) = NX'0000'
              MOVE SPACES TO W-SINCE
           END-IF
           MOVE FUNCTION UPPER-CASE(W-SINCE) TO W-SINCE

           IF  W-TABLEID NOT = C-RACFGRP
           AND W-TABLEID NOT = C-DEPLUSER
           AND W-TABLEID NOT = C-SETTINGS
              MOVE N'08' TO RETURNCODE OF P-LLWDM201
              MOVE N'02' TO REASONCODE OF P-LLWDM201
              MOVE N'tableID: RACFGRP, DEPLUSER or SETTINGS' TO
                   INFOMESSAGE OF P-LLWDM201
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: Up to 20 entries by key                            *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT TABLEID,
                     TABKEY,
                     TABVALUE,
                     CREATEDBY,
                     CHAR(CREATEDDATE),
                     UPDATEDBY,
                     CHAR(UPDATEDDATE)
                FROM TBLWD001
               WHERE TABLEID = :W-TABLEID
                 AND TABKEY > :W-SINCE
               ORDER BY TABKEY
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
                         OR RETURNCODE OF P-LLWDM201 NOT = N'00'
                         OR REF-COUNT OF P-LLWDM201 >= 20
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
      * R210-FETCH: One entry                                         *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD001.TABLEID,
                    :DCLTBLWD001.TABKEY,
                    :DCLTBLWD001.TABVALUE
                       :DCLTBLWD001.TABVALUE-IND,
                    :DCLTBLWD001.CREATEDBY,
                    :W-CREATED,
                    :DCLTBLWD001.UPDATEDBY,
                    :W-UPDATED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO REF-COUNT OF P-LLWDM201
              MOVE REF-COUNT OF P-LLWDM201 TO W-N
              MOVE TABLEID OF DCLTBLWD001 TO
                   REF-TABLEID OF P-LLWDM201(W-N)
              MOVE TABKEY OF DCLTBLWD001 TO
                   TABKEY OF P-LLWDM201(W-N)
              IF TABVALUE-IND OF DCLTBLWD001 >= 0
                 MOVE TABVALUE OF DCLTBLWD001 TO
                      TABVALUE OF P-LLWDM201(W-N)
              ELSE
                 MOVE 0 TO TABVALUE-LEN OF P-LLWDM201(W-N)
              END-IF
              MOVE CREATEDBY OF DCLTBLWD001 TO
                   CREATEDBY OF P-LLWDM201(W-N)
              MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                   CREATEDDATE OF P-LLWDM201(W-N)
              MOVE UPDATEDBY OF DCLTBLWD001 TO
                   UPDATEDBY OF P-LLWDM201(W-N)
              MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                   UPDATEDDATE OF P-LLWDM201(W-N)
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

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM201==.

       END PROGRAM LWDM201.
