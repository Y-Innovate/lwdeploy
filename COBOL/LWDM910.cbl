       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM910.
      *===============================================================*
      * This program is a DB2 module of the LWD application, for the  *
      * submit task (LWDC910) and the wrappers that start it.         *
      * OPCODE C: claim run RUNID for submission. The run must be N,  *
      *           and SHA-256 of JOBTOKEN must equal JOBHASH. Then    *
      *           the run is S, JOBHASH is cleared so the token works *
      *           once, and the job is S. Commit before submitting,   *
      *           so a run is never submitted twice.                  *
      * OPCODE F: run RUNID could not be submitted: run F, result X,  *
      *           message JOBMESSAGE, job and deployment F (R660).    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Run not found, or not N any more                      *
      * 08 01 = Error: OPCODE invalid                                 *
      * 08 50 = Error: wrong job token                                *
      * 08 90 = Error: LWDA991 failed                                 *
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

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.

       01 WORK.
          05 W-HASH-IND      PIC S9(4) COMP-5.
       01 W-JOBHASH          USAGE SQL TYPE IS BINARY(32).

       LINKAGE SECTION.
       01 P-LLWDM910.
           COPY LLWDM910.

       PROCEDURE DIVISION USING P-LLWDM910.
       MAIN SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM910
           MOVE N'00' TO REASONCODE OF P-LLWDM910
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM910

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LLWDM910 = N'00'
              EVALUATE OPCODE OF P-LLWDM910
              WHEN C-C
                 PERFORM R100-CLAIM
              WHEN C-F
                 PERFORM R200-FAILED
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM910
                 MOVE N'01' TO REASONCODE OF P-LLWDM910
                 MOVE N'OPCODE is invalid' TO
                      INFOMESSAGE OF P-LLWDM910
              END-EVALUATE
           END-IF

           MOVE SPACES TO JOBTOKEN OF P-LLWDM910
           MOVE SPACES TO W-TOKEN
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R100-CLAIM: Check the token, set the run and job submitted    *
      *===============================================================*
       R100-CLAIM SECTION.
           MOVE RUNID OF P-LLWDM910 TO W-RUN-ID

           EXEC SQL
              SELECT DEPLID,
                     JOBNO,
                     JOBHASH
                INTO :W-RUN-DEPLID,
                     :W-RUN-JOBNO,
                     :W-JOBHASH :W-HASH-IND
                FROM TBLWD014
               WHERE RUNID = :W-RUN-ID
                 AND RUNSTATUS = :C-N
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE JOBTOKEN OF P-LLWDM910 TO W-TOKEN
              PERFORM R810-HASH
              EVALUATE TRUE
              WHEN NOT A991-OK
                 MOVE N'08' TO RETURNCODE OF P-LLWDM910
                 MOVE N'90' TO REASONCODE OF P-LLWDM910
                 MOVE N'LWDA991 failed' TO INFOMESSAGE OF P-LLWDM910
              WHEN W-HASH-IND < 0
              WHEN W-TOKENHASH NOT = W-JOBHASH
                 MOVE N'08' TO RETURNCODE OF P-LLWDM910
                 MOVE N'50' TO REASONCODE OF P-LLWDM910
                 MOVE N'Wrong job token' TO INFOMESSAGE OF P-LLWDM910
              END-EVALUATE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LLWDM910
              MOVE N'01' TO REASONCODE OF P-LLWDM910
              MOVE N'Run not found, or not new any more' TO
                   INFOMESSAGE OF P-LLWDM910
           WHEN OTHER
              MOVE N'SELECT run' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE

           IF RETURNCODE OF P-LLWDM910 = N'00'
              EXEC SQL
                 UPDATE TBLWD014
                    SET RUNSTATUS     = :C-S,
                        SUBMITTEDDATE = CURRENT TIMESTAMP,
                        JOBHASH       = NULL,
                        UPDATEDBY     = :W-USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUN-ID
                    AND RUNSTATUS = :C-N
              END-EXEC
              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM910
                 MOVE N'01' TO REASONCODE OF P-LLWDM910
                 MOVE N'Run was claimed meanwhile' TO
                      INFOMESSAGE OF P-LLWDM910
              WHEN OTHER
                 MOVE N'UPDATE run' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LLWDM910 = N'00'
              EXEC SQL
                 UPDATE TBLWD012
                    SET JOBSTATUS   = :C-S,
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
       R100-CLAIM-END.
           EXIT.

      *===============================================================*
      * R200-FAILED: The run could not be submitted                   *
      *===============================================================*
       R200-FAILED SECTION.
           MOVE RUNID OF P-LLWDM910 TO W-RUN-ID
           MOVE C-F TO W-FAIL-RUNSTATUS
           MOVE C-X TO W-FAIL-RESULT
           MOVE JOBMESSAGE OF P-LLWDM910 TO W-FAIL-MSG-TEXT
           MOVE 72 TO W-FAIL-MSG-LEN
           PERFORM UNTIL W-FAIL-MSG-LEN = 0
                      OR W-FAIL-MSG-TEXT(W-FAIL-MSG-LEN:1) NOT = SPACE
              SUBTRACT 1 FROM W-FAIL-MSG-LEN
           END-PERFORM

           PERFORM R660-RUN-FAILED
           .
       R200-FAILED-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM910==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM910==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM910==.

       END PROGRAM LWDM910.
