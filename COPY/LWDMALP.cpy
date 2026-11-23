      *===============================================================*
      * LWDMALP: Notification mails of a history event (S5,           *
      * docs/11-iteration-7.md). Copy with                            *
      *    COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDMnnn==.         *
      * Needs LWDMALW, LWDDEPW, LWDCTXW and LWDCTXP. R650-ADD-EVENT   *
      * of LWDDEPP performs R750-QUEUE-MAIL after every event, so     *
      * every module that copies LWDDEPP copies this too.             *
      * Event -> mail:                                                *
      *   R request, while the deployment is W -> A to the approvers  *
      *   Q queued after the last approval, J rejected -> D           *
      *   E expired -> X                                              *
      *   S succeeded, F failed, C cancelled -> E, also to the owners *
      * The requester gets D, X and E with NOTIFYOWN Y; approvers A   *
      * with NOTIFYAPPROVE Y; owners E with NOTIFYAPP Y. Approvers    *
      * and owners come from USERGROUPS, the groups cached at their   *
      * last sign-in. Never to a user without an address, and never   *
      * to the user who caused the event. An empty MAILWRTR setting   *
      * switches mail off. The mails are queued in MAILQUEUE in the   *
      * caller's unit of work; the tick sends them (LWDC950).         *
      *===============================================================*

      *===============================================================*
      * R750-QUEUE-MAIL: The mails of event W-EV-TYPE of deployment   *
      * W-EV-DEPLID                                                   *
      *===============================================================*
       R750-QUEUE-MAIL SECTION.
           MOVE SPACE TO W-ML-TYPE
           IF RETURNCODE OF :IO: = N'00'
              EVALUATE W-EV-TYPE
              WHEN C-R
                 MOVE C-A TO W-ML-TYPE
              WHEN C-Q
              WHEN C-J
                 MOVE C-D TO W-ML-TYPE
              WHEN C-E
                 MOVE C-X TO W-ML-TYPE
              WHEN C-S
              WHEN C-F
              WHEN C-C
                 MOVE C-E TO W-ML-TYPE
              END-EVALUATE
           END-IF

           IF W-ML-TYPE NOT = SPACE
              PERFORM R751-MAIL-SETTINGS
           END-IF

           IF  W-ML-TYPE NOT = SPACE
           AND W-ML-ON = 'Y'
              PERFORM R752-DEPLOYMENT
           END-IF

      *    A request that didn't wait for approval needs no approvers
           IF  W-ML-TYPE = C-A
           AND W-ML-STATUS NOT = C-W
              MOVE SPACE TO W-ML-TYPE
           END-IF

           IF  W-ML-TYPE NOT = SPACE
           AND W-ML-ON = 'Y'
           AND RETURNCODE OF :IO: = N'00'
              PERFORM R753-TEXT
              PERFORM R754-INSERT
           END-IF
           .
       R750-QUEUE-MAIL-END.
           EXIT.

      *===============================================================*
      * R751-MAIL-SETTINGS: MAILWRTR and MAILURL, once per task       *
      *===============================================================*
       R751-MAIL-SETTINGS SECTION.
           IF  W-ML-ON = SPACE
           AND RETURNCODE OF :IO: = N'00'
              MOVE 'N' TO W-ML-ON
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
                 IF  W-SETVALUE-LEN > 0
                 AND W-SETVALUE-TEXT(1:W-SETVALUE-LEN) NOT = SPACES
                    MOVE 'Y' TO W-ML-ON
                 END-IF
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'SELECT setting MAILWRTR' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE

              IF W-ML-ON = 'Y'
                 MOVE C-MAILURL TO W-SETKEY
                 PERFORM R091-GET-SETTING
                 IF RETURNCODE OF :IO: = N'00'
                    MOVE W-SETVALUE TO W-ML-URL
                 END-IF
              END-IF
           END-IF
           .
       R751-MAIL-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R752-DEPLOYMENT: What the mail is about, and the groups       *
      *===============================================================*
       R752-DEPLOYMENT SECTION.
           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT D.DEPLSTATUS,
                        A.APPCODE,
                        E.ENVCODE,
                        V.VERSIONNAME,
                        D.CREATEDBY,
                        D.APPROVERGROUP,
                        A.OWNERGROUP
                   INTO :W-ML-STATUS,
                        :W-ML-APPCODE,
                        :W-ML-ENVCODE,
                        :W-ML-VERSION,
                        :W-ML-REQBY,
                        :W-ML-APRGRP :W-ML-APRGRP-IND,
                        :W-ML-OWNGRP
                   FROM TBLWD011 D
                   JOIN TBLWD004 A
                     ON A.APPID = D.APPID
                   JOIN TBLWD006 E
                     ON E.ENVID = D.ENVID
                   JOIN TBLWD005 V
                     ON V.VERSIONID = D.VERSIONID
                  WHERE D.DEPLID = :W-EV-DEPLID
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'SELECT deployment for mail' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
              IF W-ML-APRGRP-IND < 0
                 MOVE SPACES TO W-ML-APRGRP
              END-IF
           END-IF
           .
       R752-DEPLOYMENT-END.
           EXIT.

      *===============================================================*
      * R753-TEXT: Recipients, subject and body                       *
      *===============================================================*
       R753-TEXT SECTION.
           MOVE 'N' TO W-ML-TO-APR W-ML-TO-REQ W-ML-TO-OWN
           EVALUATE TRUE
           WHEN W-ML-TYPE = C-A
              MOVE 'Y' TO W-ML-TO-APR
              MOVE N'waits for your approval' TO W-ML-WHAT
           WHEN W-ML-TYPE = C-D AND W-ML-STATUS = C-J
              MOVE 'Y' TO W-ML-TO-REQ
              MOVE N'was rejected' TO W-ML-WHAT
           WHEN W-ML-TYPE = C-D
              MOVE 'Y' TO W-ML-TO-REQ
              MOVE N'was approved' TO W-ML-WHAT
           WHEN W-ML-TYPE = C-X
              MOVE 'Y' TO W-ML-TO-REQ
              MOVE N'expired without a decision' TO W-ML-WHAT
           WHEN OTHER
              MOVE 'Y' TO W-ML-TO-REQ W-ML-TO-OWN
              EVALUATE W-EV-TYPE
              WHEN C-S
                 MOVE N'succeeded' TO W-ML-WHAT
              WHEN C-F
                 MOVE N'failed' TO W-ML-WHAT
              WHEN OTHER
                 MOVE N'was cancelled' TO W-ML-WHAT
              END-EVALUATE
           END-EVALUATE

           MOVE SPACES TO W-ML-SUBJECT-TEXT
           MOVE 1 TO W-ML-PTR
           STRING N'LWD: ' DELIMITED BY SIZE
                  W-ML-APPCODE DELIMITED BY N' '
                  N' ' DELIMITED BY SIZE
                  W-ML-VERSION-TEXT(1:W-ML-VERSION-LEN)
                     DELIMITED BY SIZE
                  N' to ' DELIMITED BY SIZE
                  W-ML-ENVCODE DELIMITED BY N' '
                  N' ' DELIMITED BY SIZE
                  W-ML-WHAT DELIMITED BY N'  '
             INTO W-ML-SUBJECT-TEXT
             WITH POINTER W-ML-PTR
           COMPUTE W-ML-SUBJECT-LEN = W-ML-PTR - 1

           MOVE W-EV-DEPLID TO W-ML-DEPLID-ED
           MOVE SPACES TO W-ML-BODY-TEXT
           MOVE 1 TO W-ML-PTR
           STRING N'Deployment ' DELIMITED BY SIZE
                  FUNCTION NATIONAL-OF(FUNCTION TRIM(W-ML-DEPLID-ED))
                     DELIMITED BY SIZE
                  N': ' DELIMITED BY SIZE
                  W-ML-APPCODE DELIMITED BY N' '
                  N' ' DELIMITED BY SIZE
                  W-ML-VERSION-TEXT(1:W-ML-VERSION-LEN)
                     DELIMITED BY SIZE
                  N' to ' DELIMITED BY SIZE
                  W-ML-ENVCODE DELIMITED BY N' '
                  C-ML-LF DELIMITED BY SIZE
                  N'Requested by ' DELIMITED BY SIZE
                  W-ML-REQBY DELIMITED BY N' '
                  C-ML-LF DELIMITED BY SIZE
                  N'It ' DELIMITED BY SIZE
                  W-ML-WHAT DELIMITED BY N'  '
                  N'.' DELIMITED BY SIZE
                  C-ML-LF DELIMITED BY SIZE
                  C-ML-LF DELIMITED BY SIZE
                  W-ML-URL-TEXT(1:W-ML-URL-LEN) DELIMITED BY SIZE
                  N'/deployment?deplID=' DELIMITED BY SIZE
                  FUNCTION NATIONAL-OF(FUNCTION TRIM(W-ML-DEPLID-ED))
                     DELIMITED BY SIZE
                  C-ML-LF DELIMITED BY SIZE
                  C-ML-LF DELIMITED BY SIZE
                  N'Which mails LWD sends you is up to you: '
                     DELIMITED BY SIZE
                  W-ML-URL-TEXT(1:W-ML-URL-LEN) DELIMITED BY SIZE
                  N'/profile' DELIMITED BY SIZE
             INTO W-ML-BODY-TEXT
             WITH POINTER W-ML-PTR
           COMPUTE W-ML-BODY-LEN = W-ML-PTR - 1
           .
       R753-TEXT-END.
           EXIT.

      *===============================================================*
      * R754-INSERT: One mail per recipient with an address           *
      *===============================================================*
       R754-INSERT SECTION.
           EXEC SQL
              INSERT INTO TBLWD020
                   ( USERID, EMAIL, DEPLID, MAILTYPE, SUBJECT, BODY,
                     MAILSTATUS, ATTEMPTS, SENTDATE,
                     CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
              SELECT U.USERID, U.EMAIL, :W-EV-DEPLID, :W-ML-TYPE,
                     :W-ML-SUBJECT, :W-ML-BODY,
                     :C-N, 0, CAST(NULL AS TIMESTAMP),
                     :W-USERID, CURRENT TIMESTAMP,
                     :W-USERID, CURRENT TIMESTAMP
                FROM TBLWD002 U
               WHERE U.EMAIL IS NOT NULL
                 AND U.USERID <> :W-USERID
                 AND (   (    :W-ML-TO-APR = 'Y'
                          AND U.NOTIFYAPPROVE = :C-Y
                          AND U.USERID <> :W-ML-REQBY
                          AND EXISTS
                              (SELECT 1 FROM TBLWD003 G
                                WHERE G.USERID = U.USERID
                                  AND G.RACFGROUP = :W-ML-APRGRP))
                      OR (    :W-ML-TO-REQ = 'Y'
                          AND U.USERID = :W-ML-REQBY
                          AND U.NOTIFYOWN = :C-Y)
                      OR (    :W-ML-TO-OWN = 'Y'
                          AND U.NOTIFYAPP = :C-Y
                          AND U.USERID <> :W-ML-REQBY
                          AND EXISTS
                              (SELECT 1 FROM TBLWD003 G
                                WHERE G.USERID = U.USERID
                                  AND G.RACFGROUP = :W-ML-OWNGRP)))
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE N'INSERT mail' TO W-SQL-WHAT
              MOVE N'12' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R754-INSERT-END.
           EXIT.
