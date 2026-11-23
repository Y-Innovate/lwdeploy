       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDC910.
      *===============================================================*
      * This program submits a run with the CICS SPOOL commands to    *
      * the JES internal reader, under the deploy userid (S1).        *
      * Initial program of the submit transaction, started by the     *
      * wrappers (LWDSUBP) under the submit userid, the only one with *
      * surrogate access to the deploy userids. Container LLWDC911    *
      * holds the run and its token. It trusts nothing else: LWDM910  *
      * checks the token and claims the run, LWDM920 builds the JCL   *
      * from DB2, so a START from anywhere else can't submit anything.*
      * Every job goes through here: the first of a deployment, a     *
      * retry, and since iteration 4 the next job after a result      *
      * (POST /jobResults, LWDM916).                                  *
      * ------------------------------------------------------------- *
      * W-RC:                                                         *
      *   00 = Submitted                                              *
      *   08 = A CICS command, LWDM910 or LWDM920 failed              *
      * After a failure a claimed run is set failed (LWDM910 F). A    *
      * run that was not claimed is left alone and only gets a        *
      * message.                                                      *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WORK.
           05  C-CHNL-NAME-SUBMIT    PIC X(16) VALUE 'LWDSUBMIT'.
           05  C-CONT-NAME-SUBMIT    PIC X(16) VALUE 'LLWDC911'.
           05  W-PGMNAME             PIC X(8).
           05  W-RC                  PIC X(2)  VALUE '00'.
           05  W-CONT-LENGTH         PIC S9(9) USAGE COMP-5.
           05  W-CLAIMED             PIC X     VALUE 'N'.
           05  W-TOKEN               PIC X(8).
           05  W-EIBRESP             PIC 9(8).
           05  W-EIBRESP2            PIC 9(8).
           05  W-RUNID-E             PIC Z(8)9.
           05  W-I                   PIC S9(4) USAGE COMP-5.
           05  W-LEN80               PIC S9(9) USAGE COMP-5 VALUE 80.
           05  W-FAILMSG             PIC X(72) VALUE SPACES.

           05  W-MSGPTR              PIC S9(4) BINARY.
           05  MSGDEST               PIC S9(9) BINARY VALUE 2.
           05  FC.
               10  Condition-Token-Value.
               COPY  CEEIGZCT.
                   15  Case-1-Condition-ID.
                       20  Severity    PIC S9(4) BINARY.
                       20  Msg-No      PIC S9(4) BINARY.
                   15  Case-2-Condition-ID
                             REDEFINES Case-1-Condition-ID.
                       20  Class-Code  PIC S9(4) BINARY.
                       20  Cause-Code  PIC S9(4) BINARY.
                   15  Case-Sev-Ctl    PIC X.
                   15  Facility-ID     PIC XXX.
               10  I-S-Info            PIC S9(9) BINARY.
           05  MSGSTR.
               10  Vstring-length    PIC S9(4) BINARY.
               10  Vstring-text.
                   15  Vstring-char  PIC X
                               OCCURS 0 TO 256 TIMES
                               DEPENDING ON Vstring-length
                                  of MSGSTR.

       01  W-LLWDC911.
           COPY LLWDC911.
       01  W-LLWDM910.
           COPY LLWDM910.
       01  W-LLWDM920.
           COPY LLWDM920.

       PROCEDURE DIVISION.
       MAIN SECTION.
           PERFORM R001-INIT

           IF W-RC = '00'
              PERFORM R050-CLAIM-RUN
           END-IF

           IF W-RC = '00'
              PERFORM R080-BUILD-JCL
           END-IF

           IF W-RC = '00'
              PERFORM R100-OPEN
           END-IF

           IF W-RC = '00'
              PERFORM VARYING W-I FROM 1 BY 1
                        UNTIL W-I > REC-COUNT OF W-LLWDM920
                           OR W-RC NOT = '00'
                 PERFORM R900-WRITE
              END-PERFORM
              PERFORM R190-CLOSE
           END-IF

           IF  W-CLAIMED = 'Y'
           AND W-RC NOT = '00'
              PERFORM R060-SET-FAILED
           END-IF

           EXEC CICS
              RETURN
           END-EXEC
           .

      *===============================================================*
      * R001-INIT: Get the run and token from the channel             *
      *===============================================================*
       R001-INIT SECTION.
           MOVE LENGTH OF W-LLWDC911 TO W-CONT-LENGTH

           EXEC CICS
              GET CONTAINER(C-CONT-NAME-SUBMIT)
                  CHANNEL(C-CHNL-NAME-SUBMIT)
                  INTO(W-LLWDC911)
                  FLENGTH(W-CONT-LENGTH)
                  NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE 'GET CONTAINER ERROR' TO W-FAILMSG
              PERFORM R950-CICS-MESSAGE
           ELSE
              MOVE RUNID OF W-LLWDC911 TO W-RUNID-E
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R050-CLAIM-RUN: Check the token and claim the run. Commits    *
      * the claim first, so a run is never submitted twice            *
      *===============================================================*
       R050-CLAIM-RUN SECTION.
           INITIALIZE W-LLWDM910
           MOVE N'C' TO OPCODE OF W-LLWDM910
           MOVE RUNID OF W-LLWDC911 TO RUNID OF W-LLWDM910
           MOVE JOBTOKEN OF W-LLWDC911 TO JOBTOKEN OF W-LLWDM910

           MOVE 'LWDM910' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM910

           MOVE SPACES TO JOBTOKEN OF W-LLWDC911
           MOVE SPACES TO JOBTOKEN OF W-LLWDM910

           IF RETURNCODE OF W-LLWDM910 = N'00'
              MOVE 'Y' TO W-CLAIMED

              EXEC CICS
                 SYNCPOINT
                 NOHANDLE
              END-EXEC

              IF EIBRESP NOT = DFHRESP(NORMAL)
                 MOVE 'SYNCPOINT ERROR' TO W-FAILMSG
                 PERFORM R950-CICS-MESSAGE
              END-IF
           ELSE
              MOVE '08' TO W-RC
              PERFORM R960-MODULE-MESSAGE
           END-IF
           .
       R050-CLAIM-RUN-END.
           EXIT.

      *===============================================================*
      * R060-SET-FAILED: Run, job and deployment failed               *
      *===============================================================*
       R060-SET-FAILED SECTION.
           INITIALIZE W-LLWDM910
           MOVE N'F' TO OPCODE OF W-LLWDM910
           MOVE RUNID OF W-LLWDC911 TO RUNID OF W-LLWDM910
           MOVE FUNCTION NATIONAL-OF(W-FAILMSG) TO
                JOBMESSAGE OF W-LLWDM910

           MOVE 'LWDM910' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM910

           IF RETURNCODE OF W-LLWDM910 NOT = N'00'
              PERFORM R960-MODULE-MESSAGE
           END-IF

           EXEC CICS
              SYNCPOINT
              NOHANDLE
           END-EXEC
           .
       R060-SET-FAILED-END.
           EXIT.

      *===============================================================*
      * R080-BUILD-JCL: The records of the run, with USER=            *
      *===============================================================*
       R080-BUILD-JCL SECTION.
           INITIALIZE W-LLWDM920
           MOVE RUNID OF W-LLWDC911 TO RUNID OF W-LLWDM920
           SET MODE-CICS OF W-LLWDM920 TO TRUE

           MOVE 'LWDM920' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM920

           IF RETURNCODE OF W-LLWDM920 NOT = N'00'
              MOVE '08' TO W-RC
              MOVE FUNCTION DISPLAY-OF(INFOMESSAGE OF W-LLWDM920) TO
                   W-FAILMSG
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'LWDM920 ERROR RUN ' W-RUNID-E ' ' W-FAILMSG
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF
           .
       R080-BUILD-JCL-END.
           EXIT.

      *===============================================================*
      * R100-OPEN: Open the internal reader                           *
      *===============================================================*
       R100-OPEN SECTION.
           EXEC CICS
              SPOOLOPEN OUTPUT
                        TOKEN(W-TOKEN)
                        USERID('INTRDR')
                        NODE('LOCAL')
                        RECORDLENGTH(80)
                        NOCC
                        NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE 'SPOOLOPEN ERROR' TO W-FAILMSG
              PERFORM R950-CICS-MESSAGE
           END-IF
           .
       R100-OPEN-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE: KEEP releases the job to JES. After a failure a   *
      * partial job is deleted                                        *
      *===============================================================*
       R190-CLOSE SECTION.
           IF W-RC = '00'
              EXEC CICS
                 SPOOLCLOSE TOKEN(W-TOKEN)
                            KEEP
                            NOHANDLE
              END-EXEC
           ELSE
              EXEC CICS
                 SPOOLCLOSE TOKEN(W-TOKEN)
                            DELETE
                            NOHANDLE
              END-EXEC
           END-IF

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE 'SPOOLCLOSE ERROR' TO W-FAILMSG
              PERFORM R950-CICS-MESSAGE
           END-IF
           .
       R190-CLOSE-END.
           EXIT.

      *===============================================================*
      * R900-WRITE: Write JCL record W-I                              *
      *===============================================================*
       R900-WRITE SECTION.
           EXEC CICS
              SPOOLWRITE TOKEN(W-TOKEN)
                         FROM(REC OF W-LLWDM920(W-I))
                         FLENGTH(W-LEN80)
                         NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE 'SPOOLWRITE ERROR' TO W-FAILMSG
              PERFORM R950-CICS-MESSAGE
           END-IF
           .
       R900-WRITE-END.
           EXIT.

      *===============================================================*
      * R950-CICS-MESSAGE: A CICS command failed: W-RC 08, and the    *
      * message W-FAILMSG with EIBRESP and EIBRESP2                   *
      *===============================================================*
       R950-CICS-MESSAGE SECTION.
           MOVE '08' TO W-RC

           MOVE EIBRESP  TO W-EIBRESP
           MOVE EIBRESP2 TO W-EIBRESP2
           MOVE 256 TO Vstring-length
           MOVE 1 TO W-MSGPTR
           STRING W-FAILMSG DELIMITED BY '  '
                  ' ' W-EIBRESP ' ' W-EIBRESP2
                  ' RUN ' W-RUNID-E
                  DELIMITED BY SIZE
             INTO Vstring-text
             WITH POINTER W-MSGPTR
           COMPUTE Vstring-length = W-MSGPTR - 1
           CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           .
       R950-CICS-MESSAGE-END.
           EXIT.

      *===============================================================*
      * R960-MODULE-MESSAGE: LWDM910 failed. Never logs the token     *
      *===============================================================*
       R960-MODULE-MESSAGE SECTION.
           MOVE 256 TO Vstring-length
           MOVE 1 TO W-MSGPTR
           STRING 'LWDM910 ERROR RUN ' W-RUNID-E ' RC '
                  FUNCTION DISPLAY-OF(RETURNCODE OF W-LLWDM910) ' '
                  FUNCTION DISPLAY-OF(REASONCODE OF W-LLWDM910) ' '
                  FUNCTION DISPLAY-OF(INFOMESSAGE OF W-LLWDM910)
                  DELIMITED BY SIZE
             INTO Vstring-text
             WITH POINTER W-MSGPTR
           COMPUTE Vstring-length = W-MSGPTR - 1
           CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           .
       R960-MODULE-MESSAGE-END.
           EXIT.

       END PROGRAM LWDC910.
