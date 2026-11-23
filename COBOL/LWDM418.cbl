       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM418.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /approvals: approve or reject a deployment (AP2).        *
      * Who: someone in the approver group copied into the deployment *
      * (checked live, M7), not the requester, and only once: the     *
      * primary key of APPROVALS (DEPLID, USERID). When: W.           *
      * A: APPROVEDCOUNT + 1; at N the deployment is Q, in the same   *
      *    UPDATE (docs/03-data-model.md), and when its time has come *
      *    and the environment is free it starts at once (LWDSTRP).   *
      *    Otherwise the scheduler (LWDM930) starts it later.         *
      * R: one rejection is enough: J, its jobs K. A comment is       *
      *    required.                                                  *
      * Events A or J with the comment, and Q at the N-th approval.   *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Deployment not found, or no role in its application   *
      * 08 02 = Error: decision is not A or R                         *
      * 08 05 = Error: a rejection without a comment                  *
      * 08 50 = Error: not in the approver group of the deployment    *
      * 08 53 = Error: not waiting for approval (any more)            *
      * 08 55 = Error: own request, or decided by this user already   *
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

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD018 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.
           COPY LWDSTRW.

       01 WORK.
          05 W-DEPLID        PIC S9(9) COMP-5.
          05 W-ENVID         PIC S9(9) COMP-5.
          05 W-DECISION      PIC N.
          05 W-STATUS        PIC N.
          05 W-DUE           PIC X.
          05 W-COMMENT-IND   PIC S9(4) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM418.
           COPY LLWDM418.
       01 P-LLWDC910.
           COPY LLWDC910.

       PROCEDURE DIVISION USING P-LLWDM418 P-LLWDC910.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R110-ENSURE-USER
           PERFORM R200-READ

           IF RETURNCODE OF P-LLWDM418 = N'00'
              PERFORM R100-APP-ROLES
              PERFORM R210-CHECK-APPROVER
           END-IF

           PERFORM R300-INSERT-DECISION

           IF RETURNCODE OF P-LLWDM418 = N'00'
              IF W-DECISION = C-A
                 PERFORM R400-APPROVE
              ELSE
                 PERFORM R500-REJECT
              END-IF
           END-IF

           PERFORM R600-ANSWER
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations and the request            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM418
           MOVE N'00' TO REASONCODE OF P-LLWDM418
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM418

           INITIALIZE P-LLWDC910
           MOVE '00' TO C910-RC OF P-LLWDC910
           MOVE 0 TO RUNID OF P-LLWDC910

           MOVE DEPLID OF P-LLWDM418 TO W-DEPLID
           MOVE DECISION OF P-LLWDM418 TO W-DECISION
           MOVE 'N' TO W-DUE
           MOVE 'N' TO W-ST-STARTED

           IF COMMENTTEXT-LEN OF P-LLWDM418 > 0
              MOVE 0 TO W-COMMENT-IND
              MOVE COMMENTTEXT OF P-LLWDM418 TO W-EV-COMMENT
           ELSE
              MOVE -1 TO W-COMMENT-IND
              MOVE 0 TO COMMENTTEXT-LEN OF P-LLWDM418
           END-IF

           EVALUATE TRUE
           WHEN W-DECISION NOT = C-A AND W-DECISION NOT = C-R
              MOVE N'08' TO RETURNCODE OF P-LLWDM418
              MOVE N'02' TO REASONCODE OF P-LLWDM418
              MOVE N'decision: A approve or R reject' TO
                   INFOMESSAGE OF P-LLWDM418
           WHEN W-DECISION = C-R AND W-COMMENT-IND < 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM418
              MOVE N'05' TO REASONCODE OF P-LLWDM418
              MOVE N'commentText: a rejection needs a reason' TO
                   INFOMESSAGE OF P-LLWDM418
           END-EVALUATE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-READ: The deployment                                     *
      *===============================================================*
       R200-READ SECTION.
           IF RETURNCODE OF P-LLWDM418 = N'00'
              EXEC SQL
                 SELECT APPID,
                        ENVID,
                        DEPLSTATUS,
                        APPROVERGROUP,
                        CREATEDBY
                   INTO :W-APPID,
                        :W-ENVID,
                        :W-STATUS,
                        :DCLTBLWD011.APPROVERGROUP
                           :DCLTBLWD011.APPROVERGROUP-IND,
                        :DCLTBLWD011.CREATEDBY
                   FROM TBLWD011
                  WHERE DEPLID = :W-DEPLID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM418
                 MOVE N'01' TO REASONCODE OF P-LLWDM418
                 MOVE N'Deployment not found' TO
                      INFOMESSAGE OF P-LLWDM418
              WHEN OTHER
                 MOVE N'SELECT deployment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-READ-END.
           EXIT.

      *===============================================================*
      * R210-CHECK-APPROVER: In the deployment's approver group,      *
      * waiting, not the requester. Without any role: 04 01           *
      *===============================================================*
       R210-CHECK-APPROVER SECTION.
           MOVE 'N' TO W-IN-GROUP
           IF  RETURNCODE OF P-LLWDM418 = N'00'
           AND APPROVERGROUP-IND OF DCLTBLWD011 >= 0
              MOVE APPROVERGROUP OF DCLTBLWD011 TO W-GROUP
              PERFORM R096-CHECK-GROUP
           END-IF

           IF RETURNCODE OF P-LLWDM418 = N'00'
              EVALUATE TRUE
              WHEN W-CAN-SEE NOT = 'Y' AND W-IN-GROUP NOT = 'Y'
                 MOVE N'04' TO RETURNCODE OF P-LLWDM418
                 MOVE N'01' TO REASONCODE OF P-LLWDM418
                 MOVE N'Deployment not found' TO
                      INFOMESSAGE OF P-LLWDM418
              WHEN W-IN-GROUP NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM418
                 MOVE N'50' TO REASONCODE OF P-LLWDM418
                 MOVE N'You are not an approver of this deployment' TO
                      INFOMESSAGE OF P-LLWDM418
              WHEN W-STATUS NOT = C-W
                 MOVE N'08' TO RETURNCODE OF P-LLWDM418
                 MOVE N'53' TO REASONCODE OF P-LLWDM418
                 MOVE N'The deployment is not waiting for approval' TO
                      INFOMESSAGE OF P-LLWDM418
              WHEN CREATEDBY OF DCLTBLWD011 = W-USERID
                 MOVE N'08' TO RETURNCODE OF P-LLWDM418
                 MOVE N'55' TO REASONCODE OF P-LLWDM418
                 MOVE N'You can''t decide on your own request' TO
                      INFOMESSAGE OF P-LLWDM418
              END-EVALUATE
           END-IF
           .
       R210-CHECK-APPROVER-END.
           EXIT.

      *===============================================================*
      * R300-INSERT-DECISION: One row per approver: -803 means this   *
      * user decided already                                          *
      *===============================================================*
       R300-INSERT-DECISION SECTION.
           IF RETURNCODE OF P-LLWDM418 = N'00'
              EXEC SQL
                 INSERT INTO TBLWD018
                      ( DEPLID, USERID, DECISION, COMMENTTEXT,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-DEPLID, :W-USERID, :W-DECISION,
                          :P-LLWDM418.COMMENTTEXT :W-COMMENT-IND,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 MOVE N'08' TO RETURNCODE OF P-LLWDM418
                 MOVE N'55' TO REASONCODE OF P-LLWDM418
                 MOVE N'You decided on this deployment already' TO
                      INFOMESSAGE OF P-LLWDM418
              WHEN OTHER
                 MOVE N'INSERT approval' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R300-INSERT-DECISION-END.
           EXIT.

      *===============================================================*
      * R400-APPROVE: Count it; Q at the N-th, in one UPDATE with the *
      * old status in the WHERE. Then start it when it is due         *
      *===============================================================*
       R400-APPROVE SECTION.
           EXEC SQL
              UPDATE TBLWD011
                 SET APPROVEDCOUNT = APPROVEDCOUNT + 1,
                     DEPLSTATUS    = CASE WHEN APPROVEDCOUNT + 1
                                               >= APPROVALCOUNT
                                          THEN :C-Q ELSE :C-W END,
                     UPDATEDBY     = :W-USERID,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE DEPLID = :W-DEPLID
                 AND DEPLSTATUS = :C-W
           END-EXEC
           PERFORM R390-CHANGED

           IF RETURNCODE OF P-LLWDM418 = N'00'
              EXEC SQL
                 SELECT DEPLSTATUS,
                        CASE WHEN STARTAFTER <= CURRENT TIMESTAMP
                             THEN 'Y' ELSE 'N' END
                   INTO :W-STATUS,
                        :W-DUE
                   FROM TBLWD011
                  WHERE DEPLID = :W-DEPLID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT deployment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           MOVE W-DEPLID TO W-EV-DEPLID
           MOVE C-A TO W-EV-TYPE
           MOVE W-COMMENT-IND TO W-EV-COMMENT-IND
           PERFORM R650-ADD-EVENT

           IF  RETURNCODE OF P-LLWDM418 = N'00'
           AND W-STATUS = C-Q
              MOVE W-DEPLID TO W-EV-DEPLID
              MOVE C-Q TO W-EV-TYPE
              PERFORM R650-ADD-EVENT
           END-IF

           IF  RETURNCODE OF P-LLWDM418 = N'00'
           AND W-STATUS = C-Q
           AND W-DUE = 'Y'
              MOVE W-DEPLID TO W-ST-DEPLID
              MOVE W-ENVID TO W-ST-ENVID
              PERFORM R700-START-DEPLOYMENT
           END-IF
           .
       R400-APPROVE-END.
           EXIT.

      *===============================================================*
      * R500-REJECT: J, jobs K, event J                               *
      *===============================================================*
       R500-REJECT SECTION.
           EXEC SQL
              UPDATE TBLWD011
                 SET DEPLSTATUS  = :C-J,
                     ENDEDDATE   = CURRENT TIMESTAMP,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE DEPLID = :W-DEPLID
                 AND DEPLSTATUS = :C-W
           END-EXEC
           PERFORM R390-CHANGED

           IF RETURNCODE OF P-LLWDM418 = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-K,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-DEPLID
                    AND JOBSTATUS = :C-W
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE jobs' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           MOVE W-DEPLID TO W-EV-DEPLID
           MOVE C-J TO W-EV-TYPE
           MOVE W-COMMENT-IND TO W-EV-COMMENT-IND
           PERFORM R650-ADD-EVENT
           MOVE C-J TO W-STATUS
           .
       R500-REJECT-END.
           EXIT.

      *===============================================================*
      * R390-CHANGED: After the UPDATE of the deployment's status:    *
      * 100 means another request changed it first                    *
      *===============================================================*
       R390-CHANGED SECTION.
           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LLWDM418
              MOVE N'53' TO REASONCODE OF P-LLWDM418
              MOVE N'The deployment changed meanwhile' TO
                   INFOMESSAGE OF P-LLWDM418
           WHEN OTHER
              MOVE N'UPDATE deployment' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R390-CHANGED-END.
           EXIT.

      *===============================================================*
      * R600-ANSWER: Status and counts after the decision             *
      *===============================================================*
       R600-ANSWER SECTION.
           IF RETURNCODE OF P-LLWDM418 = N'00'
              EXEC SQL
                 SELECT DEPLSTATUS,
                        APPROVEDCOUNT,
                        APPROVALCOUNT
                   INTO :P-LLWDM418.DEPLSTATUS,
                        :P-LLWDM418.APPROVEDCOUNT,
                        :P-LLWDM418.APPROVALCOUNT
                   FROM TBLWD011
                  WHERE DEPLID = :W-DEPLID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT deployment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM418 = N'00'
           AND W-STATUS = C-Q
           AND W-ST-STARTED = 'N'
              MOVE N'Approved: waits for its time or environment' TO
                   INFOMESSAGE OF P-LLWDM418
           END-IF
           .
       R600-ANSWER-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM418==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM418==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM418==.

           COPY LWDSTRP REPLACING ==:IO:== BY ==P-LLWDM418==.

       END PROGRAM LWDM418.
