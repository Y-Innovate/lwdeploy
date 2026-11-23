      *===============================================================*
      * LWDSTRP: Start a deployment, or submit one of its jobs, from  *
      * a CICS module. Copy with                                      *
      *    COPY LWDSTRP REPLACING ==:IO:== BY ==P-LLWDMnnn==.         *
      * Needs LWDSTRW, LWDCTXW/P, LWDSECW/P, LWDDEPW/P, and the       *
      * module's P-LLWDC910: the run that the wrapper hands to the    *
      * submit task after its commit. One run per call at most, so a  *
      * section here is performed at most once per request. The       *
      * module sets RUNID OF P-LLWDC910 to 0 first.                   *
      *===============================================================*

      *===============================================================*
      * R700-START-DEPLOYMENT: Q deployment W-ST-DEPLID takes its     *
      * environment W-ST-ENVID if that is free, becomes U, and job 1  *
      * gets a run with a token. W-ST-STARTED = N when the            *
      * environment is busy or the deployment is no longer Q: it      *
      * then waits for the scheduler (S4) and nothing changes.        *
      *===============================================================*
       R700-START-DEPLOYMENT SECTION.
           MOVE 'N' TO W-ST-STARTED

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 UPDATE TBLWD006
                    SET ACTIVEDEPLID = :W-ST-DEPLID,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE ENVID = :W-ST-ENVID
                    AND ACTIVEDEPLID IS NULL
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE 'Y' TO W-ST-STARTED
              WHEN 100
      *          Busy: the deployment waits as Q
                 CONTINUE
              WHEN OTHER
                 MOVE N'UPDATE environment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND W-ST-STARTED = 'Y'
              EXEC SQL
                 UPDATE TBLWD011
                    SET DEPLSTATUS  = :C-U,
                        STARTEDDATE = CURRENT TIMESTAMP,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE DEPLID = :W-ST-DEPLID
                    AND DEPLSTATUS = :C-Q
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
      *          Cancelled or started meanwhile: give the environment
      *          back
                 MOVE 'N' TO W-ST-STARTED
                 EXEC SQL
                    UPDATE TBLWD006
                       SET ACTIVEDEPLID = NULL
                     WHERE ENVID = :W-ST-ENVID
                       AND ACTIVEDEPLID = :W-ST-DEPLID
                 END-EXEC
                 IF SQLCODE NOT = 0
                    MOVE N'UPDATE environment back' TO W-SQL-WHAT
                    MOVE N'32' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-IF
              WHEN OTHER
                 MOVE N'UPDATE deployment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND W-ST-STARTED = 'Y'
              MOVE W-ST-DEPLID TO W-EV-DEPLID
              MOVE C-U TO W-EV-TYPE
              PERFORM R650-ADD-EVENT
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND W-ST-STARTED = 'Y'
              EXEC SQL
                 SELECT MIN(JOBNO)
                   INTO :W-ST-JOBNO :W-ST-JOBNO-IND
                   FROM TBLWD012
                  WHERE DEPLID = :W-ST-DEPLID
                    AND JOBSTATUS = :C-W
              END-EXEC

              EVALUATE TRUE
              WHEN SQLCODE NOT = 0
                 MOVE N'SELECT first job' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              WHEN W-ST-JOBNO-IND < 0
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'53' TO REASONCODE OF :IO:
                 MOVE N'The deployment has no job waiting' TO
                      INFOMESSAGE OF :IO:
              WHEN OTHER
                 PERFORM R710-SUBMIT-JOB
              END-EVALUATE
           END-IF
           .
       R700-START-DEPLOYMENT-END.
           EXIT.

      *===============================================================*
      * R710-SUBMIT-JOB: A run with a token of job W-ST-JOBNO of      *
      * deployment W-ST-DEPLID, handed to the wrapper in P-LLWDC910   *
      * with the submit userid and transaction. The job must be W.    *
      *===============================================================*
       R710-SUBMIT-JOB SECTION.
           IF RETURNCODE OF :IO: = N'00'
              MOVE W-ST-DEPLID TO W-RUN-DEPLID
              MOVE W-ST-JOBNO TO W-RUN-JOBNO
              MOVE 'Y' TO W-RUN-WITH-TOKEN
              PERFORM R600-NEW-RUN
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              PERFORM R720-SUBMIT-SETTINGS
           END-IF

           IF RETURNCODE OF :IO: = N'00'
              MOVE W-RUN-ID TO RUNID OF P-LLWDC910
              MOVE W-TOKEN TO JOBTOKEN OF P-LLWDC910
           END-IF
           MOVE SPACES TO W-TOKEN
           .
       R710-SUBMIT-JOB-END.
           EXIT.

      *===============================================================*
      * R720-SUBMIT-SETTINGS: Userid and transaction of the submit    *
      * task, for the wrapper's START                                 *
      *===============================================================*
       R720-SUBMIT-SETTINGS SECTION.
           MOVE C-SUBMUSR TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF :IO: = N'00'
              MOVE SPACES TO S-SUBMUSR OF P-LLWDC910
              MOVE FUNCTION DISPLAY-OF(W-SETVALUE-TEXT
                   (1:FUNCTION MIN(W-SETVALUE-LEN, 8)))
                TO S-SUBMUSR OF P-LLWDC910
           END-IF

           MOVE C-SUBMTXN TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF :IO: = N'00'
              MOVE SPACES TO S-SUBMTXN OF P-LLWDC910
              MOVE FUNCTION DISPLAY-OF(W-SETVALUE-TEXT
                   (1:FUNCTION MIN(W-SETVALUE-LEN, 4)))
                TO S-SUBMTXN OF P-LLWDC910
           END-IF
           .
       R720-SUBMIT-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R730-START-NEXT-QUEUED: Environment W-ST-ENVID was just freed:*
      * start its oldest due Q deployment, if there is one            *
      *===============================================================*
       R730-START-NEXT-QUEUED SECTION.
           MOVE 'N' TO W-ST-STARTED

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT DEPLID
                   INTO :W-ST-DEPLID
                   FROM TBLWD011
                  WHERE ENVID = :W-ST-ENVID
                    AND DEPLSTATUS = :C-Q
                    AND STARTAFTER <= CURRENT TIMESTAMP
                  ORDER BY STARTAFTER, DEPLID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R700-START-DEPLOYMENT
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'SELECT next queued' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R730-START-NEXT-QUEUED-END.
           EXIT.
