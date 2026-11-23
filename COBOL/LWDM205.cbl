       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM205.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /versions?appID=: the versions of an application, newest  *
      * first (M2, D1, O4). ISUSED = Y when a deployment refers to    *
      * the version, which then can't be changed any more.            *
      * VERSIONSTATUS-FILTER: A or R; empty = all.                    *
      * VERSIONID-SINCE: paging, entries before this ID (0 = start).  *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no versions              *
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

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-SINCE       PIC S9(9) COMP-5.
          05 W-STATUS      PIC N.
          05 W-ISUSED      PIC X.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM205.
           COPY LLWDM205.

       PROCEDURE DIVISION USING P-LLWDM205.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           IF RETURNCODE OF P-LLWDM205 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM205
           MOVE N'00' TO REASONCODE OF P-LLWDM205
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM205

           MOVE 0 TO VER-COUNT OF P-LLWDM205
           MOVE APPID OF P-LLWDM205 TO W-APPID
           MOVE VERSIONID-SINCE OF P-LLWDM205 TO W-SINCE
           MOVE VERSIONSTATUS-FILTER OF P-LLWDM205 TO W-STATUS
      *    A missing optional field arrives as binary zeros
           IF W-STATUS = NX'0000'
              MOVE SPACE TO W-STATUS
           END-IF

           IF  W-STATUS NOT = SPACE
           AND W-STATUS NOT = C-A
           AND W-STATUS NOT = C-R
              MOVE N'08' TO RETURNCODE OF P-LLWDM205
              MOVE N'01' TO REASONCODE OF P-LLWDM205
              MOVE N'versionStatus_filter must be A or R' TO
                   INFOMESSAGE OF P-LLWDM205
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: Up to 20 versions, newest first                    *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT V.VERSIONID,
                     V.VERSIONNAME,
                     V.LOCTYPE,
                     V.LOCATION,
                     V.VERSIONSTATUS,
                     CASE WHEN EXISTS
                          (SELECT 1 FROM TBLWD011 D
                            WHERE D.VERSIONID = V.VERSIONID)
                          THEN 'Y' ELSE 'N' END,
                     V.CREATEDBY,
                     CHAR(V.CREATEDDATE)
                FROM TBLWD005 V
               WHERE V.APPID = :W-APPID
                 AND (:W-STATUS = :C-BLANK
                  OR  V.VERSIONSTATUS = :W-STATUS)
                 AND (:W-SINCE = 0 OR V.VERSIONID < :W-SINCE)
               ORDER BY V.VERSIONID DESC
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
                         OR RETURNCODE OF P-LLWDM205 NOT = N'00'
                         OR VER-COUNT OF P-LLWDM205 >= 20
                 EXEC SQL
                    FETCH C1
                     INTO :DCLTBLWD005.VERSIONID,
                          :DCLTBLWD005.VERSIONNAME,
                          :DCLTBLWD005.LOCTYPE,
                          :DCLTBLWD005.LOCATION,
                          :DCLTBLWD005.VERSIONSTATUS,
                          :W-ISUSED,
                          :DCLTBLWD005.CREATEDBY,
                          :DCLTBLWD005.CREATEDDATE
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    ADD 1 TO VER-COUNT OF P-LLWDM205
                    MOVE VER-COUNT OF P-LLWDM205 TO W-N
                    PERFORM R210-COPY
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

      *===============================================================*
      * R210-COPY: Copy the fetched version                           *
      *===============================================================*
       R210-COPY SECTION.
           MOVE VERSIONID OF DCLTBLWD005 TO VERSIONID OF P-LLWDM205(W-N)
           MOVE VERSIONNAME OF DCLTBLWD005 TO
                VERSIONNAME OF P-LLWDM205(W-N)
           MOVE LOCTYPE OF DCLTBLWD005 TO LOCTYPE OF P-LLWDM205(W-N)
           MOVE LOCATION OF DCLTBLWD005 TO LOCATION OF P-LLWDM205(W-N)
           MOVE VERSIONSTATUS OF DCLTBLWD005 TO
                VERSIONSTATUS OF P-LLWDM205(W-N)
           MOVE FUNCTION NATIONAL-OF(W-ISUSED) TO
                ISUSED OF P-LLWDM205(W-N)
           MOVE CREATEDBY OF DCLTBLWD005 TO
                CREATEDBY OF P-LLWDM205(W-N)
           MOVE FUNCTION NATIONAL-OF(CREATEDDATE OF DCLTBLWD005) TO
                CREATEDDATE OF P-LLWDM205(W-N)
           .
       R210-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM205==.

       END PROGRAM LWDM205.
