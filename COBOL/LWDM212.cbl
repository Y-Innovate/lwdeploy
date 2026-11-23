       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM212.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /deploymentJobs?deplID=: the jobs of a deployment, in     *
      * order, each with its latest run (M3, D2). At most 20 jobs.    *
      * Who may see it is decided by LWDM311, as for the deployment.  *
      * JOBRC -1: not known yet. Run fields are empty before the      *
      * first submission.                                             *
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

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

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
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-RUNSTATUS-IND PIC S9(4) COMP-5.

       01 W-LLWDM311.
           COPY LLWDM311.

       LINKAGE SECTION.
       01 P-LLWDM212.
           COPY LLWDM212.

       PROCEDURE DIVISION USING P-LLWDM212.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R100-MAY-SEE

           IF RETURNCODE OF P-LLWDM212 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM212
           MOVE N'00' TO REASONCODE OF P-LLWDM212
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM212

           MOVE 0 TO JOB-COUNT OF P-LLWDM212
           MOVE DEPLID OF P-LLWDM212 TO W-DEPLID
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

           MOVE RETURNCODE OF W-LLWDM311 TO RETURNCODE OF P-LLWDM212
           MOVE REASONCODE OF W-LLWDM311 TO REASONCODE OF P-LLWDM212
           MOVE INFOMESSAGE OF W-LLWDM311 TO INFOMESSAGE OF P-LLWDM212
           .
       R100-MAY-SEE-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The jobs with their latest run                     *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT J.JOBNO,
                     J.JOBTITLE,
                     J.TEMPLATEID,
                     J.TEMPLATEREV,
                     J.MAXRC,
                     J.JOBSTATUS,
                     J.LINECOUNT,
                     COALESCE(J.LASTRUNID, 0),
                     R.RUNSTATUS,
                     R.JOBRESULT,
                     COALESCE(R.JOBRC, -1),
                     R.ABENDCODE,
                     J.SKIPREASON
                FROM TBLWD012 J
                LEFT JOIN TBLWD014 R
                  ON R.RUNID = J.LASTRUNID
               WHERE J.DEPLID = :W-DEPLID
               ORDER BY J.JOBNO
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
                         OR RETURNCODE OF P-LLWDM212 NOT = N'00'
                         OR JOB-COUNT OF P-LLWDM212 >= 20
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
      * R210-FETCH: One job                                           *
      *===============================================================*
       R210-FETCH SECTION.
      *    RUNSTATUS has no indicator in the DCLGEN: it is NOT NULL in
      *    the table, but NULL here without a run, so W-RUNSTATUS-IND
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD012.JOBNO,
                    :DCLTBLWD012.JOBTITLE,
                    :DCLTBLWD012.TEMPLATEID,
                    :DCLTBLWD012.TEMPLATEREV,
                    :DCLTBLWD012.MAXRC,
                    :DCLTBLWD012.JOBSTATUS,
                    :DCLTBLWD012.LINECOUNT,
                    :DCLTBLWD012.LASTRUNID,
                    :DCLTBLWD014.RUNSTATUS :W-RUNSTATUS-IND,
                    :DCLTBLWD014.JOBRESULT
                       :DCLTBLWD014.JOBRESULT-IND,
                    :DCLTBLWD014.JOBRC,
                    :DCLTBLWD014.ABENDCODE
                       :DCLTBLWD014.ABENDCODE-IND,
                    :DCLTBLWD012.SKIPREASON
                       :DCLTBLWD012.SKIPREASON-IND
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO JOB-COUNT OF P-LLWDM212
              MOVE JOB-COUNT OF P-LLWDM212 TO W-N
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
      * R220-COPY: Copy the fetched job                               *
      *===============================================================*
       R220-COPY SECTION.
           MOVE JOBNO OF DCLTBLWD012 TO JOBNO OF P-LLWDM212(W-N)
           MOVE JOBTITLE OF DCLTBLWD012 TO JOBTITLE OF P-LLWDM212(W-N)
           MOVE TEMPLATEID OF DCLTBLWD012 TO
                TEMPLATEID OF P-LLWDM212(W-N)
           MOVE TEMPLATEREV OF DCLTBLWD012 TO
                TEMPLATEREV OF P-LLWDM212(W-N)
           MOVE MAXRC OF DCLTBLWD012 TO MAXRC OF P-LLWDM212(W-N)
           MOVE JOBSTATUS OF DCLTBLWD012 TO
                JOBSTATUS OF P-LLWDM212(W-N)
           MOVE LINECOUNT OF DCLTBLWD012 TO
                LINECOUNT OF P-LLWDM212(W-N)
           MOVE LASTRUNID OF DCLTBLWD012 TO
                LASTRUNID OF P-LLWDM212(W-N)
           IF W-RUNSTATUS-IND >= 0
              MOVE RUNSTATUS OF DCLTBLWD014 TO
                   RUNSTATUS OF P-LLWDM212(W-N)
           ELSE
              MOVE SPACES TO RUNSTATUS OF P-LLWDM212(W-N)
           END-IF
           IF JOBRESULT-IND OF DCLTBLWD014 >= 0
              MOVE JOBRESULT OF DCLTBLWD014 TO
                   JOBRESULT OF P-LLWDM212(W-N)
           ELSE
              MOVE SPACES TO JOBRESULT OF P-LLWDM212(W-N)
           END-IF
           MOVE JOBRC OF DCLTBLWD014 TO JOBRC OF P-LLWDM212(W-N)
           IF ABENDCODE-IND OF DCLTBLWD014 >= 0
              MOVE ABENDCODE OF DCLTBLWD014 TO
                   ABENDCODE OF P-LLWDM212(W-N)
           ELSE
              MOVE SPACES TO ABENDCODE OF P-LLWDM212(W-N)
           END-IF
           IF SKIPREASON-IND OF DCLTBLWD012 >= 0
              MOVE SKIPREASON OF DCLTBLWD012 TO
                   SKIPREASON OF P-LLWDM212(W-N)
           ELSE
              MOVE 0 TO SKIPREASON-LEN OF P-LLWDM212(W-N)
           END-IF
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM212==.

       END PROGRAM LWDM212.
