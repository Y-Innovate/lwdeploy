       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM945.
      *===============================================================*
      * This program is a DB2 batch program of the LWD application:   *
      * step OUTLOAD of JCL/LWDTICK, the end of the output collector  *
      * (S3). Loads what REXX LWDR941 copied from SDSF into DB2, one  *
      * run at a time, with a commit after each run. Per run status:  *
      *   C: SPOOLFILES and SPOOLLINES; JOBSTEPS from the step        *
      *      messages in JESYSMSG; JOBRC and ABENDCODE from the       *
      *      return code SDSF shows for the job, or else from the     *
      *      steps; JESJOBID when the run had none (a run without a   *
      *      result step); OUTPUTSTATUS C.                            *
      *   N: not found in JES. OUTPUTSTATUS N once the run ended more *
      *      than JOBMINS minutes ago; until then it is tried again.  *
      *   B, X: still running, or an SDSF error: tried again later.   *
      * Only runs with OUTPUTSTATUS W are touched. Rows left by an    *
      * earlier attempt are deleted first.                            *
      * Step messages: IEF142I executed, with COND CODE; IEF472I      *
      * abended, with SYSTEM= or USER=; IEF202I, IEF206I and IEF272I  *
      * not executed. With two names after the job name, which is the *
      * step and which the procedure step is checked against the      *
      * names SDSF gave the step's SYSOUT data sets; without those,   *
      * the first is taken as the step. The program name is not in    *
      * these messages: PGMNAME stays empty.                          *
      * Static SQL, so the userid only needs the plan. Linked with    *
      * DSNELI: run it with DSN RUN under IKJEFT1B.                   *
      * ------------------------------------------------------------- *
      * Input: DD OUTDATA, RECFM=VB, from LWDR941 (see its header)    *
      * RETURN-CODE:                                                  *
      *  0 = Done                                                     *
      *  8 = Invalid input or an error, see SYSOUT; the run being     *
      *      loaded is rolled back, the runs before it are kept       *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OUTDATA ASSIGN TO OUTDATA
                  FILE STATUS IS W-FS.

       DATA DIVISION.
       FILE SECTION.
       FD OUTDATA
           RECORDING MODE V
           RECORD VARYING FROM 1 TO 300 CHARACTERS
                  DEPENDING ON W-RECLEN.
       01 OUTDATA-REC     PIC X(300).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD015 END-EXEC.

           EXEC SQL INCLUDE TBLWD016 END-EXEC.

           EXEC SQL INCLUDE TBLWD017 END-EXEC.

           COPY LWDCTXW.

       01 W-IO.
          05 RETURNCODE      PIC N(02).
          05 REASONCODE      PIC N(02).
          05 INFOMESSAGE     PIC N(72).

       01 WORK.
          05 C-MAXSTEPS      PIC S9(4) COMP-5 VALUE 255.
          05 C-JOBMINS       PIC N(8) VALUE N'JOBMINS'.
          05 W-FS            PIC XX.
          05 W-RC            PIC S9(4) COMP-5 VALUE 0.
          05 W-RECLEN        PIC 9(4) COMP-5.
          05 W-REC           PIC X(300).
          05 W-EOF           PIC X VALUE 'N'.
      *   State: blank between runs, L loading a run, S skipping one
          05 W-STATE         PIC X VALUE SPACE.
          05 W-MINUTES       PIC S9(9) COMP-5.
          05 W-RUNID         PIC S9(9) COMP-5.
          05 W-RUNID-X       PIC X(9) VALUE SPACES.
          05 W-OUTSTAT       PIC N.
          05 W-OLD           PIC N.
          05 W-J-STATUS      PIC X.
          05 W-J-JOBID       PIC X(8).
          05 W-J-RETCODE     PIC X(20).
          05 W-FILENO        PIC S9(4) COMP-5.
          05 W-LINENUM       PIC S9(9) COMP-5.
          05 W-DDNAME        PIC X(8).
          05 W-STEPN         PIC X(8).
          05 W-PROCS         PIC X(8).
          05 W-TRUNC         PIC N.
          05 W-TLEN          PIC S9(4) COMP-5.
          05 W-TEXT          PIC X(299).
          05 W-LT.
             49 W-LT-LEN     PIC S9(4) COMP-5.
             49 W-LT-TEXT    PIC N(255).
          05 W-NAT8          PIC N(8).
          05 W-NAT8-IND      PIC S9(4) COMP-5.
          05 W-NAT8B         PIC N(8).
          05 W-NAT8B-IND     PIC S9(4) COMP-5.
          05 W-JOBRC         PIC S9(4) COMP-5.
          05 W-JOBRC-IND     PIC S9(4) COMP-5.
          05 W-ABEND         PIC N(5).
          05 W-ABEND-IND     PIC S9(4) COMP-5.
          05 W-JOBID         PIC N(8).
          05 W-JOBID-IND     PIC S9(4) COMP-5.
          05 W-JOBMSG.
             49 W-JOBMSG-LEN  PIC S9(4) COMP-5.
             49 W-JOBMSG-TEXT PIC N(72).
          05 W-JOBMSG-IND    PIC S9(4) COMP-5.
          05 W-RUNS-C        PIC S9(4) COMP-5 VALUE 0.
          05 W-RUNS-N        PIC S9(4) COMP-5 VALUE 0.
          05 W-RUNS-LATER    PIC S9(4) COMP-5 VALUE 0.
          05 W-CNT-ED        PIC ZZZZ9.
      *   Parsing a step message
          05 W-MSGID         PIC X(8).
          05 W-KIND          PIC X.
          05 W-P             PIC S9(4) COMP-5.
          05 W-Q             PIC S9(4) COMP-5.
          05 W-CNT           PIC S9(4) COMP-5.
          05 W-REST-LEN      PIC S9(4) COMP-5.
          05 W-T1            PIC X(16).
          05 W-T2            PIC X(16).
          05 W-T3            PIC X(16).
          05 W-T4            PIC X(16).
          05 W-RC4           PIC X(4).
          05 W-SYS           PIC X(3).
          05 W-USR           PIC X(4).
          05 W-TMP           PIC X(15).
          05 W-S             PIC S9(4) COMP-5.
          05 W-K             PIC S9(4) COMP-5.
          05 W-FOUND         PIC X.
          05 W-NAME1         PIC X(8).
          05 W-NAME2         PIC X(8).
      *   The steps found in JESYSMSG, inserted at the end of the run
          05 W-STEP-COUNT    PIC S9(4) COMP-5.
          05 W-STEP OCCURS 255 TIMES.
             10 S-NAME1      PIC X(8).
             10 S-NAME2      PIC X(8).
             10 S-KIND       PIC X.
             10 S-RC         PIC S9(4) COMP-5.
             10 S-ABEND      PIC X(5).
      *   Step and procedure step of each SYSOUT data set (SDSF)
          05 W-PAIR-COUNT    PIC S9(4) COMP-5.
          05 W-PAIR OCCURS 255 TIMES.
             10 P-STEPN      PIC X(8).
             10 P-PROCS      PIC X(8).

       PROCEDURE DIVISION.
       MAIN SECTION.
           MOVE N'00' TO RETURNCODE OF W-IO
           MOVE N'00' TO REASONCODE OF W-IO
           MOVE SPACES TO INFOMESSAGE OF W-IO

           PERFORM R090-GET-USERID
           PERFORM R100-SETTINGS

           IF RETURNCODE OF W-IO = N'00'
              OPEN INPUT OUTDATA
              IF W-FS NOT = '00'
                 DISPLAY 'LWDM945 OPEN OUTDATA FILE STATUS ' W-FS
                 MOVE 8 TO W-RC
              ELSE
                 PERFORM UNTIL W-EOF = 'Y'
                            OR W-RC >= 8
                            OR RETURNCODE OF W-IO NOT = N'00'
                    PERFORM R110-READ
                 END-PERFORM
                 CLOSE OUTDATA
              END-IF
           END-IF

           IF RETURNCODE OF W-IO = N'00' AND W-RC < 8
              PERFORM R800-END-RUN
           END-IF

           IF RETURNCODE OF W-IO NOT = N'00'
              DISPLAY 'LWDM945 RUN ' W-RUNID-X ' '
                      FUNCTION DISPLAY-OF(RETURNCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(REASONCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(INFOMESSAGE OF W-IO)
              MOVE 8 TO W-RC
           END-IF

           IF W-RC >= 8
              EXEC SQL ROLLBACK END-EXEC
           ELSE
              EXEC SQL COMMIT END-EXEC
           END-IF

           MOVE W-RUNS-C TO W-CNT-ED
           DISPLAY 'LWDM945 RUNS COLLECTED:     ' W-CNT-ED
           MOVE W-RUNS-N TO W-CNT-ED
           DISPLAY 'LWDM945 RUNS WITHOUT OUTPUT:' W-CNT-ED
           MOVE W-RUNS-LATER TO W-CNT-ED
           DISPLAY 'LWDM945 RUNS FOR LATER:     ' W-CNT-ED

           MOVE W-RC TO RETURN-CODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R100-SETTINGS: JOBMINS                                        *
      *===============================================================*
       R100-SETTINGS SECTION.
           MOVE C-JOBMINS TO W-SETKEY
           PERFORM R091-GET-SETTING
           IF RETURNCODE OF W-IO = N'00'
              COMPUTE W-MINUTES = FUNCTION NUMVAL(FUNCTION
                 DISPLAY-OF(W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
           END-IF
           .
       R100-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R110-READ: One OUTDATA record, by its first byte              *
      *===============================================================*
       R110-READ SECTION.
           READ OUTDATA INTO W-REC
           EVALUATE W-FS
           WHEN '00'
           WHEN '04'
              EVALUATE W-REC(1:1)
              WHEN 'J'
                 PERFORM R200-RUN
              WHEN 'F'
                 PERFORM R300-FILE
              WHEN 'L'
                 PERFORM R400-LINE
              WHEN 'E'
                 PERFORM R450-END-FILE
              WHEN OTHER
                 DISPLAY 'LWDM945 INVALID RECORD ' W-REC(1:40)
                 MOVE 8 TO W-RC
              END-EVALUATE
           WHEN '10'
              MOVE 'Y' TO W-EOF
           WHEN OTHER
              DISPLAY 'LWDM945 READ OUTDATA FILE STATUS ' W-FS
              MOVE 8 TO W-RC
           END-EVALUATE
           .
       R110-READ-END.
           EXIT.

      *===============================================================*
      * R200-RUN: J record: end the previous run, start this one      *
      *===============================================================*
       R200-RUN SECTION.
           PERFORM R800-END-RUN

           MOVE W-REC(2:9) TO W-RUNID-X
           MOVE W-REC(11:1) TO W-J-STATUS
           MOVE W-REC(12:8) TO W-J-JOBID
           MOVE W-REC(20:20) TO W-J-RETCODE
           MOVE 'S' TO W-STATE

           IF W-RUNID-X IS NOT NUMERIC
              DISPLAY 'LWDM945 INVALID RUNID ' W-RUNID-X
              MOVE 8 TO W-RC
           ELSE
              MOVE W-RUNID-X TO W-RUNID
              PERFORM R210-READ-RUN
           END-IF

           IF W-RC < 8 AND RETURNCODE OF W-IO = N'00'
           AND W-STATE NOT = 'X'
              EVALUATE W-J-STATUS
              WHEN 'C'
                 PERFORM R220-START-LOAD
              WHEN 'N'
                 PERFORM R230-NOT-FOUND
              WHEN OTHER
                 ADD 1 TO W-RUNS-LATER
              END-EVALUATE
           END-IF

           IF W-STATE = 'X'
              MOVE 'S' TO W-STATE
           END-IF
           .
       R200-RUN-END.
           EXIT.

      *===============================================================*
      * R210-READ-RUN: Still W? W-OLD Y: ended more than JOBMINS      *
      * minutes ago. W-STATE X: not to be touched                     *
      *===============================================================*
       R210-READ-RUN SECTION.
           EXEC SQL
              SELECT OUTPUTSTATUS,
                     CASE WHEN COALESCE(ENDEDDATE, SUBMITTEDDATE,
                                        CREATEDDATE) <
                               CURRENT TIMESTAMP - :W-MINUTES MINUTES
                          THEN :C-Y ELSE :C-N END
                INTO :W-OUTSTAT,
                     :W-OLD
                FROM TBLWD014
               WHERE RUNID = :W-RUNID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-OUTSTAT NOT = C-W
                 DISPLAY 'LWDM945 RUN ' W-RUNID-X
                         ' IS NOT WAITING FOR OUTPUT'
                 MOVE 'X' TO W-STATE
              END-IF
           WHEN 100
              DISPLAY 'LWDM945 RUN ' W-RUNID-X ' NOT FOUND'
              MOVE 'X' TO W-STATE
           WHEN OTHER
              MOVE N'SELECT run' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R210-READ-RUN-END.
           EXIT.

      *===============================================================*
      * R220-START-LOAD: Remove what an earlier attempt left, then    *
      * load the records that follow                                  *
      *===============================================================*
       R220-START-LOAD SECTION.
           EXEC SQL
              DELETE FROM TBLWD017
               WHERE RUNID = :W-RUNID
           END-EXEC
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE N'DELETE spool lines' TO W-SQL-WHAT
              MOVE N'42' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 DELETE FROM TBLWD016
                  WHERE RUNID = :W-RUNID
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'DELETE spool files' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 DELETE FROM TBLWD015
                  WHERE RUNID = :W-RUNID
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'DELETE steps' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           MOVE 'L' TO W-STATE
           MOVE 0 TO W-FILENO
           MOVE 0 TO W-LINENUM
           MOVE SPACES TO W-DDNAME
           MOVE 0 TO W-STEP-COUNT
           MOVE 0 TO W-PAIR-COUNT
           .
       R220-START-LOAD-END.
           EXIT.

      *===============================================================*
      * R230-NOT-FOUND: N once the run is old enough; commit          *
      *===============================================================*
       R230-NOT-FOUND SECTION.
           IF W-OLD = C-Y
              EXEC SQL
                 UPDATE TBLWD014
                    SET OUTPUTSTATUS = :C-N,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUNID
                    AND OUTPUTSTATUS = :C-W
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 EXEC SQL COMMIT END-EXEC
                 ADD 1 TO W-RUNS-N
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'UPDATE run no output' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           ELSE
              ADD 1 TO W-RUNS-LATER
           END-IF
           .
       R230-NOT-FOUND-END.
           EXIT.

      *===============================================================*
      * R300-FILE: F record: a new spool file                         *
      *===============================================================*
       R300-FILE SECTION.
           IF W-STATE = 'L'
              ADD 1 TO W-FILENO
              MOVE 0 TO W-LINENUM
              MOVE W-REC(2:8) TO W-DDNAME
              MOVE W-REC(10:8) TO W-STEPN
              MOVE W-REC(18:8) TO W-PROCS

              IF  W-STEPN NOT = SPACES
              AND W-PAIR-COUNT < C-MAXSTEPS
                 ADD 1 TO W-PAIR-COUNT
                 MOVE W-STEPN TO P-STEPN(W-PAIR-COUNT)
                 MOVE W-PROCS TO P-PROCS(W-PAIR-COUNT)
              END-IF

              MOVE FUNCTION NATIONAL-OF(W-STEPN) TO W-NAT8
              MOVE 0 TO W-NAT8-IND
              IF W-STEPN = SPACES
                 MOVE -1 TO W-NAT8-IND
              END-IF
              MOVE FUNCTION NATIONAL-OF(W-PROCS) TO W-NAT8B
              MOVE 0 TO W-NAT8B-IND
              IF W-PROCS = SPACES
                 MOVE -1 TO W-NAT8B-IND
              END-IF
              MOVE FUNCTION NATIONAL-OF(W-DDNAME) TO
                   DDNAME OF DCLTBLWD016

              EXEC SQL
                 INSERT INTO TBLWD016
                      ( RUNID, FILENO, DDNAME, STEPNAME, PROCSTEP,
                        LINECOUNT, TRUNCATED,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-RUNID, :W-FILENO,
                          :DCLTBLWD016.DDNAME,
                          :W-NAT8 :W-NAT8-IND,
                          :W-NAT8B :W-NAT8B-IND,
                          0, :C-N,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT spool file' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R300-FILE-END.
           EXIT.

      *===============================================================*
      * R400-LINE: L record: one line of the current spool file       *
      *===============================================================*
       R400-LINE SECTION.
           IF W-STATE = 'L' AND W-FILENO > 0
              ADD 1 TO W-LINENUM
              COMPUTE W-TLEN = W-RECLEN - 1
              IF W-TLEN > 255
                 MOVE 255 TO W-TLEN
              END-IF

              MOVE SPACES TO W-TEXT
              MOVE 0 TO W-LT-LEN
              IF W-TLEN > 0
                 MOVE W-REC(2:W-TLEN) TO W-TEXT
                 MOVE W-TLEN TO W-LT-LEN
                 MOVE FUNCTION NATIONAL-OF(W-TEXT(1:W-TLEN)) TO
                      W-LT-TEXT
              END-IF

              EXEC SQL
                 INSERT INTO TBLWD017
                      ( RUNID, FILENO, LINENUM, LINETEXT,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-RUNID, :W-FILENO, :W-LINENUM, :W-LT,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT spool line' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF

              IF W-DDNAME = 'JESYSMSG' AND W-TLEN > 8
              AND RETURNCODE OF W-IO = N'00'
                 PERFORM R500-STEP-MESSAGE
              END-IF
           END-IF
           .
       R400-LINE-END.
           EXIT.

      *===============================================================*
      * R450-END-FILE: E record: lines and truncation of the file     *
      *===============================================================*
       R450-END-FILE SECTION.
           IF W-STATE = 'L' AND W-FILENO > 0
              IF W-REC(2:1) = 'Y'
                 MOVE C-Y TO W-TRUNC
              ELSE
                 MOVE C-N TO W-TRUNC
              END-IF

              EXEC SQL
                 UPDATE TBLWD016
                    SET LINECOUNT   = :W-LINENUM,
                        TRUNCATED   = :W-TRUNC,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUNID
                    AND FILENO = :W-FILENO
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE spool file' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R450-END-FILE-END.
           EXIT.

      *===============================================================*
      * R500-STEP-MESSAGE: A step message in W-TEXT(1:W-TLEN)? Then   *
      * one more entry in W-STEP                                      *
      *===============================================================*
       R500-STEP-MESSAGE SECTION.
           MOVE 0 TO W-P
           MOVE 'IEF142I ' TO W-MSGID
           MOVE 'E' TO W-KIND
           PERFORM R510-FIND

           IF W-P = 0
              MOVE 'IEF472I ' TO W-MSGID
              MOVE 'A' TO W-KIND
              PERFORM R510-FIND
           END-IF
           IF W-P = 0
              MOVE 'IEF272I ' TO W-MSGID
              MOVE 'F' TO W-KIND
              PERFORM R510-FIND
           END-IF
           IF W-P = 0
              MOVE 'IEF202I ' TO W-MSGID
              PERFORM R510-FIND
           END-IF
           IF W-P = 0
              MOVE 'IEF206I ' TO W-MSGID
              PERFORM R510-FIND
           END-IF

      *    After the message ID: job name, one or two names, '-'
           IF W-P > 0
              COMPUTE W-REST-LEN = W-TLEN - W-P - 7
           END-IF
           IF W-P > 0 AND W-REST-LEN > 0
           AND W-STEP-COUNT < C-MAXSTEPS
              MOVE SPACES TO W-T1 W-T2 W-T3 W-T4
              UNSTRING W-TEXT(W-P + 8:W-REST-LEN)
                 DELIMITED BY ALL SPACE
                 INTO W-T1 W-T2 W-T3 W-T4
              END-UNSTRING

              EVALUATE TRUE
              WHEN W-T3 = '-'
                 MOVE W-T2 TO W-NAME1
                 MOVE SPACES TO W-NAME2
                 PERFORM R520-ADD-STEP
              WHEN W-T4 = '-'
                 MOVE W-T2 TO W-NAME1
                 MOVE W-T3 TO W-NAME2
                 PERFORM R520-ADD-STEP
              WHEN OTHER
                 CONTINUE
              END-EVALUATE
           END-IF
           .
       R500-STEP-MESSAGE-END.
           EXIT.

      *===============================================================*
      * R510-FIND: W-P = position of W-MSGID in the line, or 0        *
      *===============================================================*
       R510-FIND SECTION.
           MOVE 0 TO W-CNT
           INSPECT W-TEXT(1:W-TLEN) TALLYING W-CNT
              FOR CHARACTERS BEFORE INITIAL W-MSGID
           IF W-CNT < W-TLEN - 7
              COMPUTE W-P = W-CNT + 1
           ELSE
              MOVE 0 TO W-P
           END-IF
           .
       R510-FIND-END.
           EXIT.

      *===============================================================*
      * R520-ADD-STEP: W-NAME1/2 and W-KIND, with the return code or  *
      * abend code from the rest of the message                       *
      *===============================================================*
       R520-ADD-STEP SECTION.
           ADD 1 TO W-STEP-COUNT
           MOVE W-STEP-COUNT TO W-S
           MOVE W-NAME1 TO S-NAME1(W-S)
           MOVE W-NAME2 TO S-NAME2(W-S)
           MOVE W-KIND TO S-KIND(W-S)
           MOVE -1 TO S-RC(W-S)
           MOVE SPACES TO S-ABEND(W-S)

           EVALUATE W-KIND
           WHEN 'E'
              MOVE 'COND CODE ' TO W-MSGID
              PERFORM R530-FIND-TEXT
              IF W-Q > 0 AND W-Q + 13 <= W-TLEN
                 MOVE W-TEXT(W-Q + 10:4) TO W-RC4
                 IF W-RC4 IS NUMERIC
                    MOVE W-RC4 TO S-RC(W-S)
                 END-IF
              END-IF
           WHEN 'A'
              MOVE SPACES TO W-SYS W-USR
              MOVE 'SYSTEM= ' TO W-MSGID
              PERFORM R530-FIND-TEXT
              IF W-Q > 0 AND W-Q + 9 <= W-TLEN
                 MOVE W-TEXT(W-Q + 7:3) TO W-SYS
              END-IF
              MOVE 'USER=   ' TO W-MSGID
              PERFORM R530-FIND-TEXT
              IF W-Q > 0 AND W-Q + 8 <= W-TLEN
                 MOVE W-TEXT(W-Q + 5:4) TO W-USR
              END-IF
              IF W-SYS NOT = SPACES AND W-SYS NOT = '000'
                 STRING 'S' W-SYS DELIMITED BY SIZE
                   INTO S-ABEND(W-S)
              ELSE
                 IF W-USR NOT = SPACES
                    STRING 'U' W-USR DELIMITED BY SIZE
                      INTO S-ABEND(W-S)
                 END-IF
              END-IF
           END-EVALUATE
           .
       R520-ADD-STEP-END.
           EXIT.

      *===============================================================*
      * R530-FIND-TEXT: W-Q = position of W-MSGID without its         *
      * trailing blanks, or 0                                         *
      *===============================================================*
       R530-FIND-TEXT SECTION.
           MOVE 0 TO W-CNT
           MOVE 0 TO W-Q
           EVALUATE W-MSGID
           WHEN 'COND CODE '
              INSPECT W-TEXT(1:W-TLEN) TALLYING W-CNT
                 FOR CHARACTERS BEFORE INITIAL 'COND CODE '
              IF W-CNT < W-TLEN - 9
                 COMPUTE W-Q = W-CNT + 1
              END-IF
           WHEN 'SYSTEM= '
              INSPECT W-TEXT(1:W-TLEN) TALLYING W-CNT
                 FOR CHARACTERS BEFORE INITIAL 'SYSTEM='
              IF W-CNT < W-TLEN - 6
                 COMPUTE W-Q = W-CNT + 1
              END-IF
           WHEN OTHER
              INSPECT W-TEXT(1:W-TLEN) TALLYING W-CNT
                 FOR CHARACTERS BEFORE INITIAL 'USER='
              IF W-CNT < W-TLEN - 4
                 COMPUTE W-Q = W-CNT + 1
              END-IF
           END-EVALUATE
           .
       R530-FIND-TEXT-END.
           EXIT.

      *===============================================================*
      * R800-END-RUN: When loading: the steps, the job's return code, *
      * OUTPUTSTATUS C, commit                                        *
      *===============================================================*
       R800-END-RUN SECTION.
           IF W-STATE = 'L' AND RETURNCODE OF W-IO = N'00'
           AND W-RC < 8
              PERFORM R810-INSERT-STEPS
              PERFORM R820-RUN-RESULT
              PERFORM R830-UPDATE-RUN
              IF RETURNCODE OF W-IO = N'00'
                 EXEC SQL COMMIT END-EXEC
                 ADD 1 TO W-RUNS-C
              END-IF
           END-IF
           MOVE SPACE TO W-STATE
           .
       R800-END-RUN-END.
           EXIT.

      *===============================================================*
      * R810-INSERT-STEPS: One JOBSTEPS row per step message          *
      *===============================================================*
       R810-INSERT-STEPS SECTION.
           PERFORM VARYING W-S FROM 1 BY 1
                     UNTIL W-S > W-STEP-COUNT
                        OR RETURNCODE OF W-IO NOT = N'00'
              PERFORM R815-STEP-NAMES

              MOVE W-S TO STEPNO OF DCLTBLWD015
              MOVE FUNCTION NATIONAL-OF(W-NAME1) TO
                   STEPNAME OF DCLTBLWD015
              IF W-NAME2 = SPACES
                 MOVE -1 TO PROCSTEP-IND OF DCLTBLWD015
                 MOVE SPACES TO PROCSTEP OF DCLTBLWD015
              ELSE
                 MOVE 0 TO PROCSTEP-IND OF DCLTBLWD015
                 MOVE FUNCTION NATIONAL-OF(W-NAME2) TO
                      PROCSTEP OF DCLTBLWD015
              END-IF
              MOVE -1 TO PGMNAME-IND OF DCLTBLWD015
              MOVE SPACES TO PGMNAME OF DCLTBLWD015

              IF S-RC(W-S) >= 0
                 MOVE 0 TO STEPRC-IND OF DCLTBLWD015
                 MOVE S-RC(W-S) TO STEPRC OF DCLTBLWD015
              ELSE
                 MOVE -1 TO STEPRC-IND OF DCLTBLWD015
                 MOVE 0 TO STEPRC OF DCLTBLWD015
              END-IF

              IF S-ABEND(W-S) NOT = SPACES
                 MOVE 0 TO ABENDCODE-IND OF DCLTBLWD015
                 MOVE FUNCTION NATIONAL-OF(S-ABEND(W-S)) TO
                      ABENDCODE OF DCLTBLWD015
              ELSE
                 MOVE -1 TO ABENDCODE-IND OF DCLTBLWD015
                 MOVE SPACES TO ABENDCODE OF DCLTBLWD015
              END-IF

              IF S-KIND(W-S) = 'F'
                 MOVE C-Y TO FLUSHED OF DCLTBLWD015
              ELSE
                 MOVE C-N TO FLUSHED OF DCLTBLWD015
              END-IF

              EXEC SQL
                 INSERT INTO TBLWD015
                      ( RUNID, STEPNO, STEPNAME, PROCSTEP, PGMNAME,
                        STEPRC, ABENDCODE, FLUSHED,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-RUNID,
                          :DCLTBLWD015.STEPNO,
                          :DCLTBLWD015.STEPNAME,
                          :DCLTBLWD015.PROCSTEP
                             :DCLTBLWD015.PROCSTEP-IND,
                          :DCLTBLWD015.PGMNAME
                             :DCLTBLWD015.PGMNAME-IND,
                          :DCLTBLWD015.STEPRC
                             :DCLTBLWD015.STEPRC-IND,
                          :DCLTBLWD015.ABENDCODE
                             :DCLTBLWD015.ABENDCODE-IND,
                          :DCLTBLWD015.FLUSHED,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT step' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-PERFORM
           .
       R810-INSERT-STEPS-END.
           EXIT.

      *===============================================================*
      * R815-STEP-NAMES: W-NAME1 step, W-NAME2 procedure step of      *
      * step W-S. Two names: their order as SDSF gave them for a      *
      * SYSOUT data set of the step, or else as in the message        *
      *===============================================================*
       R815-STEP-NAMES SECTION.
           MOVE S-NAME1(W-S) TO W-NAME1
           MOVE S-NAME2(W-S) TO W-NAME2

           IF W-NAME2 NOT = SPACES
              MOVE 'N' TO W-FOUND
              PERFORM VARYING W-K FROM 1 BY 1
                        UNTIL W-K > W-PAIR-COUNT OR W-FOUND = 'Y'
                 IF  P-STEPN(W-K) = S-NAME1(W-S)
                 AND P-PROCS(W-K) = S-NAME2(W-S)
                    MOVE 'Y' TO W-FOUND
                 END-IF
                 IF  P-STEPN(W-K) = S-NAME2(W-S)
                 AND P-PROCS(W-K) = S-NAME1(W-S)
                    MOVE 'Y' TO W-FOUND
                    MOVE S-NAME2(W-S) TO W-NAME1
                    MOVE S-NAME1(W-S) TO W-NAME2
                 END-IF
              END-PERFORM
           END-IF
           .
       R815-STEP-NAMES-END.
           EXIT.

      *===============================================================*
      * R820-RUN-RESULT: JOBRC, ABENDCODE and a message for the run.  *
      * SDSF's return code first: CC nnnn, ABEND Sxxx or Uxxxx; other *
      * texts (JCL ERROR, CANCELED, ...) become the message. Without  *
      * them: the highest step RC, or the first abend of a step       *
      *===============================================================*
       R820-RUN-RESULT SECTION.
           MOVE -1 TO W-JOBRC-IND
           MOVE 0 TO W-JOBRC
           MOVE -1 TO W-ABEND-IND
           MOVE SPACES TO W-ABEND
           MOVE -1 TO W-JOBMSG-IND
           MOVE 0 TO W-JOBMSG-LEN
           MOVE SPACES TO W-JOBMSG-TEXT

           EVALUATE TRUE
           WHEN W-J-RETCODE(1:3) = 'CC '
              MOVE W-J-RETCODE(4:4) TO W-RC4
              IF W-RC4 IS NUMERIC
                 MOVE W-RC4 TO W-JOBRC
                 MOVE 0 TO W-JOBRC-IND
              END-IF
           WHEN W-J-RETCODE(1:5) = 'ABEND'
              MOVE W-J-RETCODE(6:15) TO W-TMP
              MOVE 0 TO W-CNT
              INSPECT W-TMP TALLYING W-CNT FOR LEADING SPACES
              IF W-CNT < 11
                 MOVE FUNCTION NATIONAL-OF(W-TMP(W-CNT + 1:5)) TO
                      W-ABEND
                 MOVE 0 TO W-ABEND-IND
              END-IF
           WHEN W-J-RETCODE NOT = SPACES
              STRING N'JES: ' FUNCTION NATIONAL-OF(W-J-RETCODE)
                 DELIMITED BY SIZE INTO W-JOBMSG-TEXT
              MOVE 25 TO W-JOBMSG-LEN
              MOVE 0 TO W-JOBMSG-IND
           END-EVALUATE

           PERFORM VARYING W-S FROM 1 BY 1 UNTIL W-S > W-STEP-COUNT
              IF  S-ABEND(W-S) NOT = SPACES
              AND W-ABEND-IND < 0
                 MOVE FUNCTION NATIONAL-OF(S-ABEND(W-S)) TO W-ABEND
                 MOVE 0 TO W-ABEND-IND
              END-IF
              IF  S-RC(W-S) >= 0
              AND W-J-RETCODE(1:3) NOT = 'CC '
              AND (W-JOBRC-IND < 0 OR S-RC(W-S) > W-JOBRC)
                 MOVE S-RC(W-S) TO W-JOBRC
                 MOVE 0 TO W-JOBRC-IND
              END-IF
           END-PERFORM

      *    An abended job has no job return code
           IF W-ABEND-IND >= 0 AND W-J-RETCODE(1:3) NOT = 'CC '
              MOVE -1 TO W-JOBRC-IND
           END-IF

           MOVE FUNCTION NATIONAL-OF(W-J-JOBID) TO W-JOBID
           MOVE 0 TO W-JOBID-IND
           IF W-J-JOBID = SPACES
              MOVE -1 TO W-JOBID-IND
           END-IF
           .
       R820-RUN-RESULT-END.
           EXIT.

      *===============================================================*
      * R830-UPDATE-RUN: Results and OUTPUTSTATUS C. A value already  *
      * there is kept where nothing was found                         *
      *===============================================================*
       R830-UPDATE-RUN SECTION.
           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 UPDATE TBLWD014
                    SET JOBRC        = COALESCE(:W-JOBRC :W-JOBRC-IND,
                                                JOBRC),
                        ABENDCODE    = COALESCE(:W-ABEND :W-ABEND-IND,
                                                ABENDCODE),
                        JESJOBID     = COALESCE(JESJOBID,
                                                :W-JOBID :W-JOBID-IND),
                        JOBMESSAGE   = COALESCE(JOBMESSAGE,
                                          :W-JOBMSG :W-JOBMSG-IND),
                        OUTPUTSTATUS = :C-C,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE RUNID = :W-RUNID
                    AND OUTPUTSTATUS = :C-W
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'UPDATE run collected' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R830-UPDATE-RUN-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==W-IO==.

       END PROGRAM LWDM945.
