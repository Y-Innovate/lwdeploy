       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDC950.
      *===============================================================*
      * This program sends the queued notification mails (S5) with   *
      * the CICS SPOOL commands to the JES writer of CSSMTP           *
      * (docs/11-iteration-7.md). Linked to by the tick's wrapper     *
      * LWDC930 after its commit, in the same task (LWDQ, the         *
      * scheduler's userid). LWDM950 gives the settings and, mail by  *
      * mail, the SMTP lines; every mail is one spool data set, and   *
      * its result is committed before the next one.                  *
      * At most MAILMAX mails per tick, sent or not; an empty         *
      * MAILWRTR sends nothing. A mail that can't be written is tried *
      * again in the next ticks, three times in all (LWDM950 F), and  *
      * gets a message here.                                          *
      * ------------------------------------------------------------- *
      * COMMAREA: PIC S9(4) COMP-5, out: the mails written            *
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
           05  W-PGMNAME             PIC X(8).
           05  W-RC                  PIC X(2)  VALUE '00'.
           05  W-STOP                PIC X     VALUE 'N'.
           05  W-SENT                PIC S9(4) USAGE COMP-5 VALUE 0.
           05  W-TRIED               PIC S9(4) USAGE COMP-5 VALUE 0.
           05  W-TOKEN               PIC X(8).
           05  W-NODE                PIC X(8)  VALUE 'LOCAL'.
           05  W-EIBRESP             PIC 9(8).
           05  W-EIBRESP2            PIC 9(8).
           05  W-MAILID-E            PIC Z(8)9.
           05  W-COUNT-E             PIC Z(8)9.
           05  W-I                   PIC S9(4) USAGE COMP-5.
           05  W-RECLEN              PIC S9(9) USAGE COMP-5.
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

       01  W-LLWDM950.
           COPY LLWDM950.

       LINKAGE SECTION.
       01  DFHCOMMAREA               PIC S9(4) USAGE COMP-5.

       PROCEDURE DIVISION.
       MAIN SECTION.
           PERFORM R100-PREPARE

           PERFORM UNTIL W-STOP = 'Y'
                      OR W-TRIED >= MAIL-MAX OF W-LLWDM950
              PERFORM R200-NEXT-MAIL
              IF W-STOP = 'N'
                 ADD 1 TO W-TRIED
                 PERFORM R300-WRITE-MAIL
                 PERFORM R400-RESULT
              END-IF
           END-PERFORM

           IF EIBCALEN >= LENGTH OF DFHCOMMAREA
              MOVE W-SENT TO DFHCOMMAREA
           END-IF

           IF W-TRIED > 0
              MOVE W-SENT TO W-COUNT-E
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'LWDC950 MAILS SENT ' W-COUNT-E
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF

           EXEC CICS
              RETURN
           END-EXEC
           .

      *===============================================================*
      * R100-PREPARE: Settings, and old mails dropped (committed)     *
      *===============================================================*
       R100-PREPARE SECTION.
           INITIALIZE W-LLWDM950
           SET MAIL-PREPARE OF W-LLWDM950 TO TRUE
           MOVE 'LWDM950' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM950

           IF RETURNCODE OF W-LLWDM950 NOT = N'00'
              PERFORM R960-MODULE-MESSAGE
              MOVE 'Y' TO W-STOP
              EXEC CICS
                 SYNCPOINT ROLLBACK
                 NOHANDLE
              END-EXEC
           ELSE
              IF MAIL-MAX OF W-LLWDM950 <= 0
                 MOVE 'Y' TO W-STOP
              END-IF
              EXEC CICS
                 SYNCPOINT
                 NOHANDLE
              END-EXEC
           END-IF
           MOVE 0 TO MAILID OF W-LLWDM950
           .
       R100-PREPARE-END.
           EXIT.

      *===============================================================*
      * R200-NEXT-MAIL: The next mail after the last one tried; none  *
      * left or an error stops                                        *
      *===============================================================*
       R200-NEXT-MAIL SECTION.
           SET MAIL-NEXT OF W-LLWDM950 TO TRUE
           CALL W-PGMNAME USING W-LLWDM950
           MOVE MAILID OF W-LLWDM950 TO W-MAILID-E

           EVALUATE TRUE
           WHEN RETURNCODE OF W-LLWDM950 NOT = N'00'
              PERFORM R960-MODULE-MESSAGE
              MOVE 'Y' TO W-STOP
              EXEC CICS
                 SYNCPOINT ROLLBACK
                 NOHANDLE
              END-EXEC
           WHEN MAIL-FOUND OF W-LLWDM950 NOT = 'Y'
              MOVE 'Y' TO W-STOP
           END-EVALUATE
           .
       R200-NEXT-MAIL-END.
           EXIT.

      *===============================================================*
      * R300-WRITE-MAIL: One spool data set for the CSSMTP writer     *
      *===============================================================*
       R300-WRITE-MAIL SECTION.
           MOVE '00' TO W-RC
           EXEC CICS
              SPOOLOPEN OUTPUT
                        TOKEN(W-TOKEN)
                        NODE(W-NODE)
                        USERID(MAIL-WRITER OF W-LLWDM950)
                        CLASS(MAIL-CLASS OF W-LLWDM950)
                        RECORDLENGTH(255)
                        NOCC
                        NOHANDLE
           END-EXEC
           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE 'SPOOLOPEN ERROR' TO W-FAILMSG
              PERFORM R950-CICS-MESSAGE
           END-IF

           PERFORM VARYING W-I FROM 1 BY 1
                     UNTIL W-I > REC-COUNT OF W-LLWDM950
                        OR W-RC NOT = '00'
              MOVE REC-LEN OF W-LLWDM950(W-I) TO W-RECLEN
      *       An empty line is one blank
              IF W-RECLEN < 1
                 MOVE 1 TO W-RECLEN
              END-IF
              EXEC CICS
                 SPOOLWRITE TOKEN(W-TOKEN)
                            FROM(REC OF W-LLWDM950(W-I))
                            FLENGTH(W-RECLEN)
                            NOHANDLE
              END-EXEC
              IF EIBRESP NOT = DFHRESP(NORMAL)
                 MOVE 'SPOOLWRITE ERROR' TO W-FAILMSG
                 PERFORM R950-CICS-MESSAGE
              END-IF
           END-PERFORM

           IF W-FAILMSG(1:9) NOT = 'SPOOLOPEN'
              IF W-RC = '00'
                 EXEC CICS
                    SPOOLCLOSE TOKEN(W-TOKEN)
                               KEEP
                               NOHANDLE
                 END-EXEC
                 IF EIBRESP NOT = DFHRESP(NORMAL)
                    MOVE 'SPOOLCLOSE ERROR' TO W-FAILMSG
                    PERFORM R950-CICS-MESSAGE
                 END-IF
              ELSE
                 EXEC CICS
                    SPOOLCLOSE TOKEN(W-TOKEN)
                               DELETE
                               NOHANDLE
                 END-EXEC
              END-IF
           END-IF
           MOVE SPACES TO W-FAILMSG
           .
       R300-WRITE-MAIL-END.
           EXIT.

      *===============================================================*
      * R400-RESULT: Sent or failed, committed                        *
      *===============================================================*
       R400-RESULT SECTION.
           IF W-RC = '00'
              SET MAIL-SENT OF W-LLWDM950 TO TRUE
           ELSE
              SET MAIL-FAILED OF W-LLWDM950 TO TRUE
           END-IF
           CALL W-PGMNAME USING W-LLWDM950

           IF RETURNCODE OF W-LLWDM950 NOT = N'00'
              PERFORM R960-MODULE-MESSAGE
              MOVE 'Y' TO W-STOP
              EXEC CICS
                 SYNCPOINT ROLLBACK
                 NOHANDLE
              END-EXEC
           ELSE
              EXEC CICS
                 SYNCPOINT
                 NOHANDLE
              END-EXEC
              IF W-RC = '00'
                 ADD 1 TO W-SENT
              END-IF
           END-IF
           .
       R400-RESULT-END.
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
           STRING 'LWDC950 ' W-FAILMSG DELIMITED BY '  '
                  ' ' W-EIBRESP ' ' W-EIBRESP2
                  ' MAIL ' W-MAILID-E
                  DELIMITED BY SIZE
             INTO Vstring-text
             WITH POINTER W-MSGPTR
           COMPUTE Vstring-length = W-MSGPTR - 1
           CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           .
       R950-CICS-MESSAGE-END.
           EXIT.

      *===============================================================*
      * R960-MODULE-MESSAGE: LWDM950 failed                           *
      *===============================================================*
       R960-MODULE-MESSAGE SECTION.
           MOVE 256 TO Vstring-length
           MOVE 1 TO W-MSGPTR
           STRING 'LWDM950 ERROR ' MAIL-OPCODE OF W-LLWDM950
                  ' MAIL ' W-MAILID-E ' RC '
                  FUNCTION DISPLAY-OF(RETURNCODE OF W-LLWDM950) ' '
                  FUNCTION DISPLAY-OF(REASONCODE OF W-LLWDM950) ' '
                  FUNCTION DISPLAY-OF(INFOMESSAGE OF W-LLWDM950)
                  DELIMITED BY SIZE
             INTO Vstring-text
             WITH POINTER W-MSGPTR
           COMPUTE Vstring-length = W-MSGPTR - 1
           CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           .
       R960-MODULE-MESSAGE-END.
           EXIT.

       END PROGRAM LWDC950.
