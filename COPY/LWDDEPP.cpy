      *===============================================================*
      * LWDDEPP: New runs, history events, a failed run and a         *
      * succeeded deployment. Copy with                               *
      *    COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDMnnn==.         *
      * Needs LWDDEPW, LWDCTXW, LWDCTXP, LWDSECW, LWDSECP, LWDMALW and *
      * LWDMALP, also in modules that only add events.                *
      *===============================================================*

      *===============================================================*
      * R600-NEW-RUN: A new run of job W-RUN-JOBNO of deployment      *
      * W-RUN-DEPLID, status N. RUNID comes from the sequence, so the *
      * job name (JOBPRFX + RUNID in base 36) is known at the insert. *
      * W-RUN-WITH-TOKEN = Y: a random token in W-TOKEN, its hash in  *
      * JOBHASH, for the CICS submit task. N: no token, for the       *
      * result step, which submits the next job itself.               *
      * Returns W-RUN-ID and W-RUN-JOBNAME.                           *
      *===============================================================*
       R600-NEW-RUN SECTION.
           MOVE C-JOBPRFX TO W-SETKEY
           PERFORM R091-GET-SETTING

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT NEXT VALUE FOR SQLWD014
                   INTO :W-RUN-ID
                   FROM SYSIBM.SYSDUMMY1
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'NEXT VALUE RUNID' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              MOVE SPACES TO W-RUN-JOBNAME
              MOVE W-SETVALUE-TEXT(1:2) TO W-RUN-JOBNAME(1:2)
              MOVE W-RUN-ID TO W-RUN-NUM
              PERFORM VARYING W-RUN-I FROM 8 BY -1 UNTIL W-RUN-I < 3
                 COMPUTE W-RUN-DIG = FUNCTION MOD(W-RUN-NUM, 36)
                 MOVE C-B36(W-RUN-DIG + 1:1) TO
                      W-RUN-JOBNAME(W-RUN-I:1)
                 COMPUTE W-RUN-NUM = W-RUN-NUM / 36
              END-PERFORM

              MOVE -1 TO W-RUN-HASH-IND
              IF W-RUN-WITH-TOKEN = 'Y'
                 PERFORM R800-NEW-TOKEN
                 IF A991-OK
                    PERFORM R810-HASH
                 END-IF
                 IF A991-OK
                    MOVE W-TOKENHASH TO W-RUN-HASH
                    MOVE 0 TO W-RUN-HASH-IND
                 ELSE
                    MOVE N'08' TO RETURNCODE OF :IO:
                    MOVE N'90' TO REASONCODE OF :IO:
                    MOVE N'LWDA991 failed' TO INFOMESSAGE OF :IO:
                 END-IF
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 INSERT INTO TBLWD014
                      ( RUNID, DEPLID, JOBNO, JOBNAME, RUNSTATUS,
                        JOBRESULT, JESJOBID, SUBMITTEDDATE, ENDEDDATE,
                        JOBRC, ABENDCODE, JOBMESSAGE, OUTPUTSTATUS,
                        JOBHASH,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-RUN-ID, :W-RUN-DEPLID, :W-RUN-JOBNO,
                          :W-RUN-JOBNAME, :C-N,
                          NULL, NULL, NULL, NULL,
                          NULL, NULL, NULL, :C-W,
                          :W-RUN-HASH :W-RUN-HASH-IND,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT run' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET LASTRUNID   = :W-RUN-ID,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-RUN-DEPLID
                    AND JOBNO  = :W-RUN-JOBNO
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE job' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R600-NEW-RUN-END.
           EXIT.

      *===============================================================*
      * R650-ADD-EVENT: History event W-EV-TYPE of deployment         *
      * W-EV-DEPLID, with W-EV-JOBNO and W-EV-COMMENT when their      *
      * indicators are 0, and its mails (R750-QUEUE-MAIL, LWDMALP)    *
      *===============================================================*
       R650-ADD-EVENT SECTION.
           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 INSERT INTO TBLWD019
                      ( DEPLID, EVENTNO, EVENTTYPE, JOBNO, COMMENTTEXT,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 SELECT :W-EV-DEPLID,
                        COALESCE(MAX(EVENTNO), 0) + 1,
                        :W-EV-TYPE,
                        :W-EV-JOBNO :W-EV-JOBNO-IND,
                        :W-EV-COMMENT :W-EV-COMMENT-IND,
                        :W-USERID, CURRENT TIMESTAMP,
                        :W-USERID, CURRENT TIMESTAMP
                   FROM TBLWD019
                  WHERE DEPLID = :W-EV-DEPLID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT event' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

      *    The mails of the event (LWDMALP)
           PERFORM R750-QUEUE-MAIL

           MOVE -1 TO W-EV-JOBNO-IND
           MOVE -1 TO W-EV-COMMENT-IND
           .
       R650-ADD-EVENT-END.
           EXIT.

      *===============================================================*
      * R660-RUN-FAILED: Run W-RUN-ID failed: it gets W-FAIL-RUNSTATUS*
      * (F: not submitted or no result; E: ended badly), result       *
      * W-FAIL-RESULT and message W-FAIL-MSG. Its job and deployment  *
      * become F; the deployment keeps the environment (S1). The      *
      * environment is H, possibly half deployed, when the job ran    *
      * (H, A) or an earlier job did. Event F with the job number.    *
      *===============================================================*
       R660-RUN-FAILED SECTION.
           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT R.DEPLID,
                        R.JOBNO,
                        D.ENVID
                   INTO :W-RUN-DEPLID,
                        :W-RUN-JOBNO,
                        :W-FAIL-ENVID
                   FROM TBLWD014 R
                   JOIN TBLWD011 D
                     ON D.DEPLID = R.DEPLID
                  WHERE R.RUNID = :W-RUN-ID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT failed run' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD014
                    SET RUNSTATUS   = :W-FAIL-RUNSTATUS,
                        JOBRESULT   = :W-FAIL-RESULT,
                        JOBMESSAGE  = :W-FAIL-MSG,
                        ENDEDDATE   = CURRENT TIMESTAMP,
                        JOBHASH     = NULL,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUN-ID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE failed run' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-F,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-RUN-DEPLID
                    AND JOBNO  = :W-RUN-JOBNO
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE failed job' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD011
                    SET DEPLSTATUS  = :C-F,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-RUN-DEPLID
                    AND DEPLSTATUS = :C-U
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE failed deployment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND (W-FAIL-RESULT = C-H OR W-FAIL-RESULT = C-A
            OR  W-RUN-JOBNO > 1)
              EXEC SQL
                 UPDATE TBLWD006
                    SET ENVSTATE    = :C-H,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE ENVID = :W-FAIL-ENVID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE environment state' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              MOVE W-RUN-DEPLID TO W-EV-DEPLID
              MOVE C-F TO W-EV-TYPE
              MOVE W-RUN-JOBNO TO W-EV-JOBNO
              MOVE 0 TO W-EV-JOBNO-IND
              MOVE SPACES TO W-EV-COMMENT-TEXT
              MOVE W-FAIL-MSG-LEN TO W-EV-COMMENT-LEN
              IF W-FAIL-MSG-LEN > 0
                 MOVE W-FAIL-MSG-TEXT(1:W-FAIL-MSG-LEN) TO
                      W-EV-COMMENT-TEXT
                 MOVE 0 TO W-EV-COMMENT-IND
              END-IF
              PERFORM R650-ADD-EVENT
           END-IF
           .
       R660-RUN-FAILED-END.
           EXIT.

      *===============================================================*
      * R670-DEPL-SUCCEEDED: Deployment W-OK-DEPLID, now U, is S. The *
      * inventory of environment W-OK-ENVID gets version              *
      * W-OK-VERSIONID, ENVSTATE O, and the environment is free.      *
      * Event S. Shared by the result step and D4 continue.           *
      *===============================================================*
       R670-DEPL-SUCCEEDED SECTION.
           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD011
                    SET DEPLSTATUS  = :C-S,
                        ENDEDDATE   = CURRENT TIMESTAMP,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-OK-DEPLID
                    AND DEPLSTATUS = :C-U
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE deployment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD006
                    SET CURRENTDEPLID    = :W-OK-DEPLID,
                        CURRENTVERSIONID = :W-OK-VERSIONID,
                        ENVSTATE         = :C-O,
                        ACTIVEDEPLID     = NULL,
                        UPDATEDBY        = :W-USERID,
                        UPDATEDDATE      = CURRENT TIMESTAMP
                  WHERE ENVID = :W-OK-ENVID
                    AND ACTIVEDEPLID = :W-OK-DEPLID
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE environment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              MOVE W-OK-DEPLID TO W-EV-DEPLID
              MOVE C-S TO W-EV-TYPE
              PERFORM R650-ADD-EVENT
           END-IF
           .
       R670-DEPL-SUCCEEDED-END.
           EXIT.
