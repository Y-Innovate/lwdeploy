       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM290.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /approvalRequests: the deployments waiting for my         *
      * approval, oldest first (AP1). The same rows as the count in   *
      * GET /me (LWDM302): W, in one of my approver groups, not my    *
      * own request, not decided by me yet. Groups come from the      *
      * cache (USERGROUPS), refreshed after GRPMINS minutes; POST     *
      * /approvals checks the group live. Pages of 20: pass the last  *
      * deplID as deplID_since.                                       *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 21 = Error: SQL error on OPEN/FETCH                        *
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

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD018 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-SINCE       PIC S9(9) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-STARTAFTER  PIC X(26).
          05 W-REQUESTED   PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM290.
           COPY LLWDM290.

       PROCEDURE DIVISION USING P-LLWDM290.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R120-REFRESH-GROUPS

           IF RETURNCODE OF P-LLWDM290 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM290
           MOVE N'00' TO REASONCODE OF P-LLWDM290
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM290

           MOVE 0 TO APQ-COUNT OF P-LLWDM290
           MOVE DEPLID-SINCE OF P-LLWDM290 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The waiting deployments after W-SINCE              *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT D.DEPLID,
                     D.APPID,
                     A.APPCODE,
                     A.APPNAME,
                     D.ENVID,
                     E.ENVCODE,
                     E.ENVNAME,
                     V.VERSIONNAME,
                     D.APPROVEDCOUNT,
                     D.APPROVALCOUNT,
                     CHAR(D.STARTAFTER),
                     D.CREATEDBY,
                     CHAR(D.CREATEDDATE)
                FROM TBLWD011 D
                JOIN TBLWD004 A
                  ON A.APPID = D.APPID
                JOIN TBLWD006 E
                  ON E.ENVID = D.ENVID
                JOIN TBLWD005 V
                  ON V.VERSIONID = D.VERSIONID
               WHERE D.DEPLSTATUS = :C-W
                 AND D.DEPLID > :W-SINCE
                 AND D.CREATEDBY <> :W-USERID
                 AND D.APPROVERGROUP IN
                     (SELECT G.RACFGROUP
                        FROM TBLWD003 G
                       WHERE G.USERID = :W-USERID)
                 AND NOT EXISTS
                     (SELECT 1
                        FROM TBLWD018 X
                       WHERE X.DEPLID = D.DEPLID
                         AND X.USERID = :W-USERID)
               ORDER BY D.DEPLID
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
                         OR RETURNCODE OF P-LLWDM290 NOT = N'00'
                         OR APQ-COUNT OF P-LLWDM290 >= 20
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
      * R210-FETCH: One deployment                                    *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD011.DEPLID,
                    :DCLTBLWD011.APPID,
                    :DCLTBLWD004.APPCODE,
                    :DCLTBLWD004.APPNAME,
                    :DCLTBLWD011.ENVID,
                    :DCLTBLWD006.ENVCODE,
                    :DCLTBLWD006.ENVNAME,
                    :DCLTBLWD005.VERSIONNAME,
                    :DCLTBLWD011.APPROVEDCOUNT,
                    :DCLTBLWD011.APPROVALCOUNT,
                    :W-STARTAFTER,
                    :DCLTBLWD011.CREATEDBY,
                    :W-REQUESTED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO APQ-COUNT OF P-LLWDM290
              MOVE APQ-COUNT OF P-LLWDM290 TO W-N
              PERFORM R220-COPY
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

      *===============================================================*
      * R220-COPY: Copy the fetched deployment                        *
      *===============================================================*
       R220-COPY SECTION.
           MOVE DEPLID OF DCLTBLWD011 TO DEPLID OF P-LLWDM290(W-N)
           MOVE APPID OF DCLTBLWD011 TO APPID OF P-LLWDM290(W-N)
           MOVE APPCODE OF DCLTBLWD004 TO APPCODE OF P-LLWDM290(W-N)
           MOVE APPNAME OF DCLTBLWD004 TO APPNAME OF P-LLWDM290(W-N)
           MOVE ENVID OF DCLTBLWD011 TO ENVID OF P-LLWDM290(W-N)
           MOVE ENVCODE OF DCLTBLWD006 TO ENVCODE OF P-LLWDM290(W-N)
           MOVE ENVNAME OF DCLTBLWD006 TO ENVNAME OF P-LLWDM290(W-N)
           MOVE VERSIONNAME OF DCLTBLWD005 TO
                VERSIONNAME OF P-LLWDM290(W-N)
           MOVE APPROVEDCOUNT OF DCLTBLWD011 TO
                APPROVEDCOUNT OF P-LLWDM290(W-N)
           MOVE APPROVALCOUNT OF DCLTBLWD011 TO
                APPROVALCOUNT OF P-LLWDM290(W-N)
           MOVE FUNCTION NATIONAL-OF(W-STARTAFTER) TO
                STARTAFTER OF P-LLWDM290(W-N)
           MOVE CREATEDBY OF DCLTBLWD011 TO
                REQUESTEDBY OF P-LLWDM290(W-N)
           MOVE FUNCTION NATIONAL-OF(W-REQUESTED) TO
                REQUESTEDDATE OF P-LLWDM290(W-N)
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM290==.

       END PROGRAM LWDM290.
