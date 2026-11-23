       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM208.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /templates?appID= (O2): the active job templates of an    *
      * application in order, for whoever may see it. At most 20      *
      * (LWDM008 refuses a 21st), so no paging. A deployment runs one *
      * job per template, in this order.                              *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no templates             *
      * 04 01 = Application not found, or no role in it               *
      * 08 21 = Error: SQL error on OPEN/FETCH                        *
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

           EXEC SQL INCLUDE TBLWD008 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM208.
           COPY LLWDM208.

       PROCEDURE DIVISION USING P-LLWDM208.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           IF RETURNCODE OF P-LLWDM208 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM208
           MOVE N'00' TO REASONCODE OF P-LLWDM208
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM208

           MOVE 0 TO TPL-COUNT OF P-LLWDM208
           MOVE APPID OF P-LLWDM208 TO W-APPID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The active templates in order                      *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT TEMPLATEID,
                     TEMPLATENAME,
                     SORTORDER,
                     MAXRC,
                     CURRENTREV,
                     UPDATEDBY,
                     CHAR(UPDATEDDATE)
                FROM TBLWD008
               WHERE APPID = :W-APPID
                 AND TEMPLATESTATUS = :C-A
               ORDER BY SORTORDER, TEMPLATEID
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
                         OR RETURNCODE OF P-LLWDM208 NOT = N'00'
                         OR TPL-COUNT OF P-LLWDM208 >= 20
                 EXEC SQL
                    FETCH C1
                     INTO :DCLTBLWD008.TEMPLATEID,
                          :DCLTBLWD008.TEMPLATENAME,
                          :DCLTBLWD008.SORTORDER,
                          :DCLTBLWD008.MAXRC,
                          :DCLTBLWD008.CURRENTREV,
                          :DCLTBLWD008.UPDATEDBY,
                          :W-UPDATED
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    ADD 1 TO TPL-COUNT OF P-LLWDM208
                    MOVE TPL-COUNT OF P-LLWDM208 TO W-N
                    MOVE TEMPLATEID OF DCLTBLWD008 TO
                         TEMPLATEID OF P-LLWDM208(W-N)
                    MOVE TEMPLATENAME OF DCLTBLWD008 TO
                         TEMPLATENAME OF P-LLWDM208(W-N)
                    MOVE SORTORDER OF DCLTBLWD008 TO
                         SORTORDER OF P-LLWDM208(W-N)
                    MOVE MAXRC OF DCLTBLWD008 TO
                         MAXRC OF P-LLWDM208(W-N)
                    MOVE CURRENTREV OF DCLTBLWD008 TO
                         CURRENTREV OF P-LLWDM208(W-N)
                    MOVE UPDATEDBY OF DCLTBLWD008 TO
                         UPDATEDBY OF P-LLWDM208(W-N)
                    MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                         UPDATEDDATE OF P-LLWDM208(W-N)
                 WHEN 100
                    MOVE 'Y' TO W-EOF
                 WHEN OTHER
                    MOVE N'FETCH CURSOR' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE C1
              END-EXEC
           END-IF
           .
       R200-LIST-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM208==.

       END PROGRAM LWDM208.
