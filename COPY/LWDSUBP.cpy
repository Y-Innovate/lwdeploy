      *===============================================================*
      * R100-SUBMIT-JOB: Start the task that submits the run, under   *
      * the submit userid, after the run has been committed. The      *
      * token goes on a channel, not START FROM, because that would   *
      * put it in a temporary storage queue. If the START fails, the  *
      * run and the deployment are set failed (LWDM910 F). Needs      *
      * LWDSUBW, and from the CICS program: W-RETURNCODE, the         *
      * container fields, R920-PUT-CONTAINER and the CEEMOUT fields.  *
      *===============================================================*
       R100-SUBMIT-JOB SECTION.
           MOVE RUNID OF W-LLWDC910 TO RUNID OF W-LLWDC911
           MOVE JOBTOKEN OF W-LLWDC910 TO JOBTOKEN OF W-LLWDC911
           MOVE SPACES TO JOBTOKEN OF W-LLWDC910

           MOVE '00'                 TO W-RETURNCODE
           MOVE C-CHNL-NAME-SUBMIT   TO W-CHNL-NAME
           MOVE C-CONT-NAME-SUBMIT   TO W-CONT-NAME
           MOVE LENGTH OF W-LLWDC911 TO W-CONT-LENGTH
           SET W-CONT-POINTER TO ADDRESS OF W-LLWDC911

           PERFORM R920-PUT-CONTAINER

           MOVE SPACES TO JOBTOKEN OF W-LLWDC911

           IF W-RETURNCODE = '00'
              EXEC CICS
                 START TRANSID(S-SUBMTXN OF W-LLWDC910)
                       CHANNEL(C-CHNL-NAME-SUBMIT)
                       USERID(S-SUBMUSR OF W-LLWDC910)
                       NOHANDLE
              END-EXEC

              IF EIBRESP NOT = DFHRESP(NORMAL)
                 MOVE '08' TO W-RETURNCODE

                 MOVE EIBRESP  TO W-EIBRESP
                 MOVE EIBRESP2 TO W-EIBRESP2
                 MOVE 256 TO Vstring-length
                 MOVE 1 TO W-MSGPTR
                 STRING 'START ERROR ' W-EIBRESP ' ' W-EIBRESP2
                        DELIMITED BY SIZE
                   INTO Vstring-text
                   WITH POINTER W-MSGPTR
                 COMPUTE Vstring-length = W-MSGPTR - 1
                 CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
              END-IF
           END-IF

           IF W-RETURNCODE NOT = '00'
              MOVE RUNID OF W-LLWDC910 TO RUNID OF W-LLWDM910
              MOVE N'F' TO OPCODE OF W-LLWDM910
              MOVE N'The submit task could not be started' TO
                   JOBMESSAGE OF W-LLWDM910

              MOVE 'LWDM910' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDM910

              EXEC CICS
                 SYNCPOINT
                 NOHANDLE
              END-EXEC
           END-IF
           .
       R100-SUBMIT-JOB-END.
           EXIT.
