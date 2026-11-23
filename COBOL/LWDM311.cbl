       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM311.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /deployments/{deplID}: a deployment (M3, D2, AP2), also   *
      * called by LWDM411 to answer POST /deployments.                *
      * Who may see it: a member, owner or approver of the            *
      * application, someone in the approver group copied into the    *
      * deployment, or an administrator; anyone else gets 04 01.      *
      * Flags for the UI, checked again by the operations themselves: *
      * CANCANCEL  = requester or member, and W, Q or F, or U while   *
      *              no job is submitted (D3)                         *
      * CANRETRY   = member, and F (D4); retry and continue check     *
      *              the deployer group themselves                    *
      * CANAPPROVE = W, in the deployment's approver group, not the   *
      *              requester and not decided by this user yet (AP2) *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Deployment not found, or no role in its application   *
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

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD018 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-DEPLID         PIC S9(9) COMP-5.
          05 W-STARTAFTER     PIC X(26).
          05 W-STARTED        PIC X(26).
          05 W-STARTED-IND    PIC S9(4) COMP-5.
          05 W-ENDED          PIC X(26).
          05 W-ENDED-IND      PIC S9(4) COMP-5.
          05 W-REQUESTED      PIC X(26).
          05 W-BUSY           PIC X.
          05 W-DECIDED        PIC X.
          05 W-IN-DEPLGROUP   PIC X.
          05 W-FLAG           PIC X.

       LINKAGE SECTION.
       01 P-LLWDM311.
           COPY LLWDM311.

       PROCEDURE DIVISION USING P-LLWDM311.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R200-READ

           IF RETURNCODE OF P-LLWDM311 = N'00'
              MOVE APPID OF DCLTBLWD011 TO W-APPID
              PERFORM R100-APP-ROLES
              PERFORM R210-DEPLOYMENT-GROUP
              PERFORM R220-CHECK-SEE
           END-IF

           IF RETURNCODE OF P-LLWDM311 = N'00'
              PERFORM R300-COPY
              PERFORM R310-FLAGS
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM311
           MOVE N'00' TO REASONCODE OF P-LLWDM311
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM311

           MOVE DEPLID OF P-LLWDM311 TO W-DEPLID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-READ: The deployment with its application, environment   *
      * and version                                                   *
      *===============================================================*
       R200-READ SECTION.
           IF RETURNCODE OF P-LLWDM311 = N'00'
              EXEC SQL
                 SELECT D.APPID,
                        A.APPCODE,
                        A.APPNAME,
                        D.ENVID,
                        E.ENVCODE,
                        E.ENVNAME,
                        D.VERSIONID,
                        V.VERSIONNAME,
                        V.LOCATION,
                        D.DEPLSTATUS,
                        CHAR(D.STARTAFTER),
                        D.REQUESTNOTE,
                        D.DEPLOYUSER,
                        D.APPROVERGROUP,
                        D.APPROVALCOUNT,
                        D.APPROVEDCOUNT,
                        CHAR(D.STARTEDDATE),
                        CHAR(D.ENDEDDATE),
                        D.CREATEDBY,
                        CHAR(D.CREATEDDATE)
                   INTO :DCLTBLWD011.APPID,
                        :DCLTBLWD004.APPCODE,
                        :DCLTBLWD004.APPNAME,
                        :DCLTBLWD011.ENVID,
                        :DCLTBLWD006.ENVCODE,
                        :DCLTBLWD006.ENVNAME,
                        :DCLTBLWD011.VERSIONID,
                        :DCLTBLWD005.VERSIONNAME,
                        :DCLTBLWD005.LOCATION,
                        :DCLTBLWD011.DEPLSTATUS,
                        :W-STARTAFTER,
                        :DCLTBLWD011.REQUESTNOTE
                           :DCLTBLWD011.REQUESTNOTE-IND,
                        :DCLTBLWD011.DEPLOYUSER,
                        :DCLTBLWD011.APPROVERGROUP
                           :DCLTBLWD011.APPROVERGROUP-IND,
                        :DCLTBLWD011.APPROVALCOUNT,
                        :DCLTBLWD011.APPROVEDCOUNT,
                        :W-STARTED :W-STARTED-IND,
                        :W-ENDED :W-ENDED-IND,
                        :DCLTBLWD011.CREATEDBY,
                        :W-REQUESTED
                   FROM TBLWD011 D
                   JOIN TBLWD004 A
                     ON A.APPID = D.APPID
                   JOIN TBLWD006 E
                     ON E.ENVID = D.ENVID
                   JOIN TBLWD005 V
                     ON V.VERSIONID = D.VERSIONID
                  WHERE D.DEPLID = :W-DEPLID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM311
                 MOVE N'01' TO REASONCODE OF P-LLWDM311
                 MOVE N'Deployment not found' TO
                      INFOMESSAGE OF P-LLWDM311
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
      * R210-DEPLOYMENT-GROUP: Is the user in the approver group that *
      * was copied into the deployment?                               *
      *===============================================================*
       R210-DEPLOYMENT-GROUP SECTION.
           MOVE 'N' TO W-IN-DEPLGROUP
           IF  RETURNCODE OF P-LLWDM311 = N'00'
           AND APPROVERGROUP-IND OF DCLTBLWD011 >= 0
              MOVE APPROVERGROUP OF DCLTBLWD011 TO W-GROUP
              PERFORM R096-CHECK-GROUP
              MOVE W-IN-GROUP TO W-IN-DEPLGROUP
           END-IF
           .
       R210-DEPLOYMENT-GROUP-END.
           EXIT.

      *===============================================================*
      * R220-CHECK-SEE: 04 01 for anyone without a role               *
      *===============================================================*
       R220-CHECK-SEE SECTION.
           IF  RETURNCODE OF P-LLWDM311 = N'00'
           AND W-CAN-SEE NOT = 'Y'
           AND W-IN-DEPLGROUP NOT = 'Y'
              MOVE N'04' TO RETURNCODE OF P-LLWDM311
              MOVE N'01' TO REASONCODE OF P-LLWDM311
              MOVE N'Deployment not found' TO
                   INFOMESSAGE OF P-LLWDM311
           END-IF
           .
       R220-CHECK-SEE-END.
           EXIT.

      *===============================================================*
      * R300-COPY: Copy the deployment into the IO area               *
      *===============================================================*
       R300-COPY SECTION.
           MOVE APPID OF DCLTBLWD011 TO APPID OF P-LLWDM311
           MOVE APPCODE OF DCLTBLWD004 TO APPCODE OF P-LLWDM311
           MOVE APPNAME OF DCLTBLWD004 TO APPNAME OF P-LLWDM311
           MOVE ENVID OF DCLTBLWD011 TO ENVID OF P-LLWDM311
           MOVE ENVCODE OF DCLTBLWD006 TO ENVCODE OF P-LLWDM311
           MOVE ENVNAME OF DCLTBLWD006 TO ENVNAME OF P-LLWDM311
           MOVE VERSIONID OF DCLTBLWD011 TO VERSIONID OF P-LLWDM311
           MOVE VERSIONNAME OF DCLTBLWD005 TO
                VERSIONNAME OF P-LLWDM311
           MOVE LOCATION OF DCLTBLWD005 TO LOCATION OF P-LLWDM311
           MOVE DEPLSTATUS OF DCLTBLWD011 TO DEPLSTATUS OF P-LLWDM311
           MOVE FUNCTION NATIONAL-OF(W-STARTAFTER) TO
                STARTAFTER OF P-LLWDM311
           IF REQUESTNOTE-IND OF DCLTBLWD011 >= 0
              MOVE REQUESTNOTE OF DCLTBLWD011 TO
                   REQUESTNOTE OF P-LLWDM311
           ELSE
              MOVE 0 TO REQUESTNOTE-LEN OF P-LLWDM311
           END-IF
           MOVE DEPLOYUSER OF DCLTBLWD011 TO DEPLOYUSER OF P-LLWDM311
           IF APPROVERGROUP-IND OF DCLTBLWD011 >= 0
              MOVE APPROVERGROUP OF DCLTBLWD011 TO
                   APPROVERGROUP OF P-LLWDM311
           ELSE
              MOVE SPACES TO APPROVERGROUP OF P-LLWDM311
           END-IF
           MOVE APPROVALCOUNT OF DCLTBLWD011 TO
                APPROVALCOUNT OF P-LLWDM311
           MOVE APPROVEDCOUNT OF DCLTBLWD011 TO
                APPROVEDCOUNT OF P-LLWDM311
           IF W-STARTED-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-STARTED) TO
                   STARTEDDATE OF P-LLWDM311
           ELSE
              MOVE SPACES TO STARTEDDATE OF P-LLWDM311
           END-IF
           IF W-ENDED-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-ENDED) TO
                   ENDEDDATE OF P-LLWDM311
           ELSE
              MOVE SPACES TO ENDEDDATE OF P-LLWDM311
           END-IF
           MOVE CREATEDBY OF DCLTBLWD011 TO REQUESTEDBY OF P-LLWDM311
           MOVE FUNCTION NATIONAL-OF(W-REQUESTED) TO
                REQUESTEDDATE OF P-LLWDM311
           .
       R300-COPY-END.
           EXIT.

      *===============================================================*
      * R310-FLAGS: What the user can do with it now                  *
      *===============================================================*
       R310-FLAGS SECTION.
      *    Cancel (D3): requester or member, in a state that allows it
           MOVE 'N' TO W-FLAG
           IF  CREATEDBY OF DCLTBLWD011 = W-USERID
            OR W-IS-MEMBER = 'Y'
              EVALUATE DEPLSTATUS OF DCLTBLWD011
              WHEN C-W
              WHEN C-Q
              WHEN C-F
                 MOVE 'Y' TO W-FLAG
              WHEN C-U
                 PERFORM R320-JOB-BUSY
                 IF W-BUSY = 'N'
                    MOVE 'Y' TO W-FLAG
                 END-IF
              END-EVALUATE
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-FLAG) TO CANCANCEL OF P-LLWDM311

      *    Retry and continue (D4): member, failed
           IF  W-IS-MEMBER = 'Y'
           AND DEPLSTATUS OF DCLTBLWD011 = C-F
              MOVE C-Y TO CANRETRY OF P-LLWDM311
           ELSE
              MOVE C-N TO CANRETRY OF P-LLWDM311
           END-IF

      *    Approve (AP2): waiting, approver, not own, not decided yet
           MOVE 'N' TO W-FLAG
           IF  DEPLSTATUS OF DCLTBLWD011 = C-W
           AND W-IN-DEPLGROUP = 'Y'
           AND CREATEDBY OF DCLTBLWD011 NOT = W-USERID
              PERFORM R330-DECIDED
              IF W-DECIDED = 'N'
                 MOVE 'Y' TO W-FLAG
              END-IF
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-FLAG) TO CANAPPROVE OF P-LLWDM311
           .
       R310-FLAGS-END.
           EXIT.

      *===============================================================*
      * R320-JOB-BUSY: W-BUSY = Y when a job is submitted or running  *
      *===============================================================*
       R320-JOB-BUSY SECTION.
           MOVE 'Y' TO W-BUSY
           EXEC SQL
              SELECT CASE WHEN EXISTS
                          (SELECT 1 FROM TBLWD012 J
                            WHERE J.DEPLID = :W-DEPLID
                              AND J.JOBSTATUS = :C-S)
                          THEN 'Y' ELSE 'N' END
                INTO :W-BUSY
                FROM SYSIBM.SYSDUMMY1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'SELECT jobs' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R320-JOB-BUSY-END.
           EXIT.

      *===============================================================*
      * R330-DECIDED: W-DECIDED = Y when this user decided already    *
      *===============================================================*
       R330-DECIDED SECTION.
           MOVE 'Y' TO W-DECIDED
           EXEC SQL
              SELECT CASE WHEN EXISTS
                          (SELECT 1 FROM TBLWD018 A
                            WHERE A.DEPLID = :W-DEPLID
                              AND A.USERID = :W-USERID)
                          THEN 'Y' ELSE 'N' END
                INTO :W-DECIDED
                FROM SYSIBM.SYSDUMMY1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'SELECT approvals' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R330-DECIDED-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM311==.

       END PROGRAM LWDM311.
