       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM204.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /applications: the applications the user is a member,     *
      * owner or approver of (M1), by APPID, from the cached groups   *
      * (USERGROUPS), refreshed first when older than GRPMINS.        *
      * Applications without a role are left out, not even named.     *
      * ADMINVIEW = Y (an LWW constant of GET /admin/applications,    *
      * A1, A4): every application with its groups, for              *
      * administrators only; the roles are not filled in.             *
      * APPID-SINCE: paging, entries after this ID (0 = start).       *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no applications          *
      * 08 21 = Error: SQL error on OPEN/FETCH                        *
      * 08 50 = Error: ADMINVIEW, and not an administrator            *
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

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-APPID-SINCE PIC S9(9) COMP-5.
          05 W-MEMBER      PIC X.
          05 W-OWNER       PIC X.
          05 W-APPROVER    PIC X.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM204.
           COPY LLWDM204.

       PROCEDURE DIVISION USING P-LLWDM204.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID

           IF ADMINVIEW OF P-LLWDM204 = C-Y
              PERFORM R098-REQUIRE-ADMIN
              IF RETURNCODE OF P-LLWDM204 = N'00'
                 PERFORM R300-ADMIN-LIST
              END-IF
           ELSE
              PERFORM R120-REFRESH-GROUPS
              IF RETURNCODE OF P-LLWDM204 = N'00'
                 PERFORM R200-LIST
              END-IF
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM204
           MOVE N'00' TO REASONCODE OF P-LLWDM204
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM204

           MOVE 0 TO APP-COUNT OF P-LLWDM204
           MOVE APPID-SINCE OF P-LLWDM204 TO W-APPID-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: Up to 20 applications with a role                  *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT X.APPID, X.APPCODE, X.APPNAME,
                     X.ISMEMBER, X.ISOWNER, X.ISAPPROVER
                FROM (SELECT A.APPID, A.APPCODE, A.APPNAME,
                             CASE WHEN EXISTS
                                  (SELECT 1 FROM TBLWD003 G
                                    WHERE G.USERID = :W-USERID
                                      AND G.RACFGROUP = A.ACCESSGROUP)
                                  THEN 'Y' ELSE 'N' END AS ISMEMBER,
                             CASE WHEN EXISTS
                                  (SELECT 1 FROM TBLWD003 G
                                    WHERE G.USERID = :W-USERID
                                      AND G.RACFGROUP = A.OWNERGROUP)
                                  THEN 'Y' ELSE 'N' END AS ISOWNER,
                             CASE WHEN EXISTS
                                  (SELECT 1 FROM TBLWD006 E,
                                                 TBLWD003 G
                                    WHERE E.APPID = A.APPID
                                      AND G.USERID = :W-USERID
                                      AND G.RACFGROUP = E.APPROVERGROUP)
                                  THEN 'Y' ELSE 'N' END AS ISAPPROVER
                        FROM TBLWD004 A
                       WHERE A.APPID > :W-APPID-SINCE) X
               WHERE X.ISMEMBER = 'Y'
                  OR X.ISOWNER = 'Y'
                  OR X.ISAPPROVER = 'Y'
               ORDER BY X.APPID
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
                         OR RETURNCODE OF P-LLWDM204 NOT = N'00'
                         OR APP-COUNT OF P-LLWDM204 >= 20
                 EXEC SQL
                    FETCH C1
                     INTO :DCLTBLWD004.APPID,
                          :DCLTBLWD004.APPCODE,
                          :DCLTBLWD004.APPNAME,
                          :W-MEMBER,
                          :W-OWNER,
                          :W-APPROVER
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    ADD 1 TO APP-COUNT OF P-LLWDM204
                    MOVE APP-COUNT OF P-LLWDM204 TO W-N
                    MOVE APPID OF DCLTBLWD004 TO
                         APPID OF P-LLWDM204(W-N)
                    MOVE APPCODE OF DCLTBLWD004 TO
                         APPCODE OF P-LLWDM204(W-N)
                    MOVE APPNAME OF DCLTBLWD004 TO
                         APPNAME OF P-LLWDM204(W-N)
                    MOVE FUNCTION NATIONAL-OF(W-MEMBER) TO
                         ISMEMBER OF P-LLWDM204(W-N)
                    MOVE FUNCTION NATIONAL-OF(W-OWNER) TO
                         ISOWNER OF P-LLWDM204(W-N)
                    MOVE FUNCTION NATIONAL-OF(W-APPROVER) TO
                         ISAPPROVER OF P-LLWDM204(W-N)
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

      *===============================================================*
      * R300-ADMIN-LIST: Up to 20 applications with their groups      *
      *===============================================================*
       R300-ADMIN-LIST SECTION.
           EXEC SQL
              DECLARE C2 CURSOR FOR
              SELECT APPID, APPCODE, APPNAME, ACCESSGROUP, OWNERGROUP
                FROM TBLWD004
               WHERE APPID > :W-APPID-SINCE
               ORDER BY APPID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C2
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'OPEN CURSOR C2' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           ELSE
              MOVE 'N' TO W-EOF
              PERFORM UNTIL W-EOF = 'Y'
                         OR RETURNCODE OF P-LLWDM204 NOT = N'00'
                         OR APP-COUNT OF P-LLWDM204 >= 20
                 EXEC SQL
                    FETCH C2
                     INTO :DCLTBLWD004.APPID,
                          :DCLTBLWD004.APPCODE,
                          :DCLTBLWD004.APPNAME,
                          :DCLTBLWD004.ACCESSGROUP,
                          :DCLTBLWD004.OWNERGROUP
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    ADD 1 TO APP-COUNT OF P-LLWDM204
                    MOVE APP-COUNT OF P-LLWDM204 TO W-N
                    MOVE APPID OF DCLTBLWD004 TO
                         APPID OF P-LLWDM204(W-N)
                    MOVE APPCODE OF DCLTBLWD004 TO
                         APPCODE OF P-LLWDM204(W-N)
                    MOVE APPNAME OF DCLTBLWD004 TO
                         APPNAME OF P-LLWDM204(W-N)
                    MOVE ACCESSGROUP OF DCLTBLWD004 TO
                         ACCESSGROUP OF P-LLWDM204(W-N)
                    MOVE OWNERGROUP OF DCLTBLWD004 TO
                         OWNERGROUP OF P-LLWDM204(W-N)
                 WHEN 100
                    MOVE 'Y' TO W-EOF
                 WHEN OTHER
                    MOVE N'FETCH CURSOR C2' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE C2
              END-EXEC
           END-IF
           .
       R300-ADMIN-LIST-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM204==.

       END PROGRAM LWDM204.
