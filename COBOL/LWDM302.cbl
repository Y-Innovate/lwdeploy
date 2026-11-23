       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM302.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /me: the signed-in user (U1). Creates the user row on the *
      * first call and refreshes the cached groups when they are      *
      * older than GRPMINS minutes, so the lists that follow are      *
      * right. APPROVALSWAITING counts deployments waiting for this   *
      * user's approval: in an approver group, not the requester, not *
      * approved by this user yet.                                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 21 = Error: SQL error in SELECT                            *
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

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD018 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-COUNT      PIC S9(9) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM302.
           COPY LLWDM302.

       PROCEDURE DIVISION USING P-LLWDM302.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R120-REFRESH-GROUPS
           PERFORM R095-CHECK-ADMIN

           PERFORM R200-GET-USER
           PERFORM R210-COUNT-WAITING
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM302
           MOVE N'00' TO REASONCODE OF P-LLWDM302
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM302
           MOVE SPACES TO USERID OF P-LLWDM302
           MOVE 0 TO EMAIL-LEN OF P-LLWDM302
           MOVE 0 TO APPROVALSWAITING OF P-LLWDM302
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-GET-USER: Email address and notification settings        *
      *===============================================================*
       R200-GET-USER SECTION.
           IF RETURNCODE OF P-LLWDM302 = N'00'
              EXEC SQL
                 SELECT EMAIL,
                        NOTIFYAPPROVE,
                        NOTIFYOWN,
                        NOTIFYAPP
                   INTO :DCLTBLWD002.EMAIL
                          :DCLTBLWD002.EMAIL-IND,
                        :DCLTBLWD002.NOTIFYAPPROVE,
                        :DCLTBLWD002.NOTIFYOWN,
                        :DCLTBLWD002.NOTIFYAPP
                   FROM TBLWD002
                  WHERE USERID = :W-USERID
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'SELECT user' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE W-USERID TO USERID OF P-LLWDM302
                 IF EMAIL-IND OF DCLTBLWD002 >= 0
                    MOVE EMAIL-LEN OF DCLTBLWD002 TO
                         EMAIL-LEN OF P-LLWDM302
                    MOVE EMAIL-TEXT OF DCLTBLWD002 TO
                         EMAIL-TEXT OF P-LLWDM302
                 END-IF
                 MOVE NOTIFYAPPROVE OF DCLTBLWD002 TO
                      NOTIFYAPPROVE OF P-LLWDM302
                 MOVE NOTIFYOWN OF DCLTBLWD002 TO
                      NOTIFYOWN OF P-LLWDM302
                 MOVE NOTIFYAPP OF DCLTBLWD002 TO
                      NOTIFYAPP OF P-LLWDM302
                 MOVE FUNCTION NATIONAL-OF(W-IS-ADMIN) TO
                      ISADMIN OF P-LLWDM302
              END-IF
           END-IF
           .
       R200-GET-USER-END.
           EXIT.

      *===============================================================*
      * R210-COUNT-WAITING: Deployments waiting for my approval       *
      *===============================================================*
       R210-COUNT-WAITING SECTION.
           IF RETURNCODE OF P-LLWDM302 = N'00'
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD011 D
                  WHERE D.DEPLSTATUS = :C-W
                    AND D.CREATEDBY <> :W-USERID
                    AND D.APPROVERGROUP IN
                        (SELECT G.RACFGROUP
                           FROM TBLWD003 G
                          WHERE G.USERID = :W-USERID)
                    AND NOT EXISTS
                        (SELECT 1
                           FROM TBLWD018 A
                          WHERE A.DEPLID = D.DEPLID
                            AND A.USERID = :W-USERID)
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'SELECT waiting' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE W-COUNT TO APPROVALSWAITING OF P-LLWDM302
              END-IF
           END-IF
           .
       R210-COUNT-WAITING-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM302==.

       END PROGRAM LWDM302.
