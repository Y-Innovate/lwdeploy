       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM209.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /templateRevisions?templateID= (O2): the revisions of a   *
      * job template, newest first, for whoever may see the           *
      * application; of a deleted template too.                       *
      * REVISION-SINCE: paging, revisions before this one (0 = start).*
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no revisions             *
      * 04 01 = Template not found, or no role in its application     *
      * 08 21 = Error: SQL error                                      *
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

           EXEC SQL INCLUDE TBLWD009 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-TEMPLATEID  PIC S9(9) COMP-5.
          05 W-SINCE       PIC S9(4) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM209.
           COPY LLWDM209.

       PROCEDURE DIVISION USING P-LLWDM209.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R150-TEMPLATE-APP
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           IF RETURNCODE OF P-LLWDM209 = N'00'
              PERFORM R200-LIST
           END-IF

           IF RETURNCODE OF P-LLWDM209 = N'04'
              MOVE N'Template not found' TO INFOMESSAGE OF P-LLWDM209
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM209
           MOVE N'00' TO REASONCODE OF P-LLWDM209
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM209

           MOVE 0 TO REV-COUNT OF P-LLWDM209
           MOVE TEMPLATEID OF P-LLWDM209 TO W-TEMPLATEID
           MOVE REVISION-SINCE OF P-LLWDM209 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-TEMPLATE-APP: W-APPID of the template, 04 01 without one *
      *===============================================================*
       R150-TEMPLATE-APP SECTION.
           IF RETURNCODE OF P-LLWDM209 = N'00'
              EXEC SQL
                 SELECT APPID
                   INTO :W-APPID
                   FROM TBLWD008
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM209
                 MOVE N'01' TO REASONCODE OF P-LLWDM209
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
      * R200-LIST: Up to 20 revisions, newest first                   *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT REVISION,
                     CHANGENOTE,
                     LINECOUNT,
                     CREATEDBY,
                     CHAR(CREATEDDATE)
                FROM TBLWD009
               WHERE TEMPLATEID = :W-TEMPLATEID
                 AND (:W-SINCE = 0 OR REVISION < :W-SINCE)
               ORDER BY REVISION DESC
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
                         OR RETURNCODE OF P-LLWDM209 NOT = N'00'
                         OR REV-COUNT OF P-LLWDM209 >= 20
                 EXEC SQL
                    FETCH C1
                     INTO :DCLTBLWD009.REVISION,
                          :DCLTBLWD009.CHANGENOTE
                             :DCLTBLWD009.CHANGENOTE-IND,
                          :DCLTBLWD009.LINECOUNT,
                          :DCLTBLWD009.CREATEDBY,
                          :W-CREATED
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    ADD 1 TO REV-COUNT OF P-LLWDM209
                    MOVE REV-COUNT OF P-LLWDM209 TO W-N
                    MOVE REVISION OF DCLTBLWD009 TO
                         REVISION OF P-LLWDM209(W-N)
                    IF CHANGENOTE-IND OF DCLTBLWD009 >= 0
                       MOVE CHANGENOTE OF DCLTBLWD009 TO
                            CHANGENOTE OF P-LLWDM209(W-N)
                    ELSE
                       MOVE 0 TO CHANGENOTE-LEN OF P-LLWDM209(W-N)
                    END-IF
                    MOVE LINECOUNT OF DCLTBLWD009 TO
                         LINECOUNT OF P-LLWDM209(W-N)
                    MOVE CREATEDBY OF DCLTBLWD009 TO
                         CREATEDBY OF P-LLWDM209(W-N)
                    MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                         CREATEDDATE OF P-LLWDM209(W-N)
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
           .
       R200-LIST-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM209==.

       END PROGRAM LWDM209.
