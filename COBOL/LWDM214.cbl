       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM214.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /jobRuns?deplID=&jobNo=: the runs of one job of a         *
      * deployment, newest first (M3), so the failed runs before a    *
      * retry stay readable. At most 20.                              *
      * Who may see it is decided by LWDM311, as for the deployment.  *
      * JOBRC -1: not known. Empty fields: not there yet.             *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Deployment not found, or no role in its application   *
      * 08 21 = Error: SQL error on OPEN/FETCH                        *
      * And the codes of LWDM311 and LWDCTXP                          *
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

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-DEPLID      PIC S9(9) COMP-5.
          05 W-JOBNO       PIC S9(4) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-SUBMITTED   PIC X(26).
          05 W-SUBMITTED-IND PIC S9(4) COMP-5.
          05 W-ENDED       PIC X(26).
          05 W-ENDED-IND   PIC S9(4) COMP-5.

       01 W-LLWDM311.
           COPY LLWDM311.

       LINKAGE SECTION.
       01 P-LLWDM214.
           COPY LLWDM214.

       PROCEDURE DIVISION USING P-LLWDM214.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R100-MAY-SEE

           IF RETURNCODE OF P-LLWDM214 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM214
           MOVE N'00' TO REASONCODE OF P-LLWDM214
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM214

           MOVE 0 TO RUN-COUNT OF P-LLWDM214
           MOVE DEPLID OF P-LLWDM214 TO W-DEPLID
           MOVE JOBNO OF P-LLWDM214 TO W-JOBNO
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R100-MAY-SEE: LWDM311 decides, as for the deployment itself   *
      *===============================================================*
       R100-MAY-SEE SECTION.
           INITIALIZE W-LLWDM311
           MOVE W-DEPLID TO DEPLID OF W-LLWDM311
           MOVE 'LWDM311' TO W-PGMNAME
           CALL W-PGMNAME USING W-LLWDM311

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM214
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM214
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM214
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The runs of the job                                *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT RUNID,
                     JOBNO,
                     JOBNAME,
                     RUNSTATUS,
                     JOBRESULT,
                     JESJOBID,
                     CHAR(SUBMITTEDDATE),
                     CHAR(ENDEDDATE),
                     COALESCE(JOBRC, -1),
                     ABENDCODE,
                     JOBMESSAGE,
                     OUTPUTSTATUS
                FROM TBLWD014
               WHERE DEPLID = :W-DEPLID
                 AND JOBNO = :W-JOBNO
               ORDER BY RUNID DESC
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'OPEN CURSOR' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           ELSE
              MOVE 'N' TO W-EOF
              PERFORM UNTIL W-EOF = 'Y'
                         OR RETURNCODE OF P-LLWDM214 NOT = N'00'
                         OR RUN-COUNT OF P-LLWDM214 >= 20
                 PERFORM R210-FETCH
              END-PERFORM

              EXEC SQL
                 CLOSE C1
              END-EXEC
           END-IF
           .
       R200-LIST-END.
           EXIT.

      *===============================================================*
      * R210-FETCH: One run                                           *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD014.RUNID,
                    :DCLTBLWD014.JOBNO,
                    :DCLTBLWD014.JOBNAME,
                    :DCLTBLWD014.RUNSTATUS,
                    :DCLTBLWD014.JOBRESULT
                       :DCLTBLWD014.JOBRESULT-IND,
                    :DCLTBLWD014.JESJOBID
                       :DCLTBLWD014.JESJOBID-IND,
                    :W-SUBMITTED :W-SUBMITTED-IND,
                    :W-ENDED :W-ENDED-IND,
                    :DCLTBLWD014.JOBRC,
                    :DCLTBLWD014.ABENDCODE
                       :DCLTBLWD014.ABENDCODE-IND,
                    :DCLTBLWD014.JOBMESSAGE
                       :DCLTBLWD014.JOBMESSAGE-IND,
                    :DCLTBLWD014.OUTPUTSTATUS
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO RUN-COUNT OF P-LLWDM214
              MOVE RUN-COUNT OF P-LLWDM214 TO W-N
              PERFORM R220-COPY
           WHEN 100
              MOVE 'Y' TO W-EOF
           WHEN OTHER
              MOVE N'FETCH CURSOR' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R210-FETCH-END.
           EXIT.

      *===============================================================*
      * R220-COPY: Copy the fetched run                               *
      *===============================================================*
       R220-COPY SECTION.
           MOVE RUNID OF DCLTBLWD014 TO RUNID OF P-LLWDM214(W-N)
           MOVE JOBNO OF DCLTBLWD014 TO RUN-JOBNO OF P-LLWDM214(W-N)
           MOVE JOBNAME OF DCLTBLWD014 TO JOBNAME OF P-LLWDM214(W-N)
           MOVE RUNSTATUS OF DCLTBLWD014 TO
                RUNSTATUS OF P-LLWDM214(W-N)
           IF JOBRESULT-IND OF DCLTBLWD014 >= 0
              MOVE JOBRESULT OF DCLTBLWD014 TO
                   JOBRESULT OF P-LLWDM214(W-N)
           ELSE
              MOVE SPACES TO JOBRESULT OF P-LLWDM214(W-N)
           END-IF
           IF JESJOBID-IND OF DCLTBLWD014 >= 0
              MOVE JESJOBID OF DCLTBLWD014 TO
                   JESJOBID OF P-LLWDM214(W-N)
           ELSE
              MOVE SPACES TO JESJOBID OF P-LLWDM214(W-N)
           END-IF
           IF W-SUBMITTED-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-SUBMITTED) TO
                   SUBMITTEDDATE OF P-LLWDM214(W-N)
           ELSE
              MOVE SPACES TO SUBMITTEDDATE OF P-LLWDM214(W-N)
           END-IF
           IF W-ENDED-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-ENDED) TO
                   ENDEDDATE OF P-LLWDM214(W-N)
           ELSE
              MOVE SPACES TO ENDEDDATE OF P-LLWDM214(W-N)
           END-IF
           MOVE JOBRC OF DCLTBLWD014 TO JOBRC OF P-LLWDM214(W-N)
           IF ABENDCODE-IND OF DCLTBLWD014 >= 0
              MOVE ABENDCODE OF DCLTBLWD014 TO
                   ABENDCODE OF P-LLWDM214(W-N)
           ELSE
              MOVE SPACES TO ABENDCODE OF P-LLWDM214(W-N)
           END-IF
           IF JOBMESSAGE-IND OF DCLTBLWD014 >= 0
              MOVE JOBMESSAGE OF DCLTBLWD014 TO
                   JOBMESSAGE OF P-LLWDM214(W-N)
           ELSE
              MOVE 0 TO JOBMESSAGE-LEN OF P-LLWDM214(W-N)
           END-IF
           MOVE OUTPUTSTATUS OF DCLTBLWD014 TO
                OUTPUTSTATUS OF P-LLWDM214(W-N)
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM214==.

       END PROGRAM LWDM214.
