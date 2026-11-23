       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM207.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /variables?appID=&envID=&versionID= (O1, O3, O4): the     *
      * variables of one level, for whoever may see the application:  *
      *   application: ENVID and VERSIONID 0                          *
      *   environment: ENVID of an environment of the application     *
      *   version:     VERSIONID of a version of the application      *
      * Both set is 08 02. Values are never secret (they are shown to *
      * every member). By VARID; VARID-SINCE: paging, after this ID.  *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no variables             *
      * 04 01 = Application not found, or no role in it               *
      * 08 02 = Error: both envID and versionID                       *
      * 08 13 = Error: the environment or version isn't one of the    *
      *         application                                           *
      * 08 21 = Error: SQL error                                      *
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

           EXEC SQL INCLUDE TBLWD007 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-ENVID       PIC S9(9) COMP-5.
          05 W-VERSIONID   PIC S9(9) COMP-5.
          05 W-SINCE       PIC S9(9) COMP-5.
          05 W-COUNT       PIC S9(9) COMP-5.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM207.
           COPY LLWDM207.

       PROCEDURE DIVISION USING P-LLWDM207.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE
           PERFORM R150-CHECK-LEVEL

           IF RETURNCODE OF P-LLWDM207 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM207
           MOVE N'00' TO REASONCODE OF P-LLWDM207
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM207

           MOVE 0 TO VAR-COUNT OF P-LLWDM207
           MOVE APPID OF P-LLWDM207 TO W-APPID
           MOVE ENVID OF P-LLWDM207 TO W-ENVID
           MOVE VERSIONID OF P-LLWDM207 TO W-VERSIONID
           MOVE VARID-SINCE OF P-LLWDM207 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-CHECK-LEVEL: One level, and of this application          *
      *===============================================================*
       R150-CHECK-LEVEL SECTION.
           IF  RETURNCODE OF P-LLWDM207 = N'00'
           AND W-ENVID > 0 AND W-VERSIONID > 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM207
              MOVE N'02' TO REASONCODE OF P-LLWDM207
              MOVE N'A level is an environment or a version, not both'
                TO INFOMESSAGE OF P-LLWDM207
           END-IF

           IF  RETURNCODE OF P-LLWDM207 = N'00'
           AND W-ENVID > 0
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD006
                  WHERE ENVID = :W-ENVID
                    AND APPID = :W-APPID
              END-EXEC
              PERFORM R160-PARENT
           END-IF

           IF  RETURNCODE OF P-LLWDM207 = N'00'
           AND W-VERSIONID > 0
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD005
                  WHERE VERSIONID = :W-VERSIONID
                    AND APPID = :W-APPID
              END-EXEC
              PERFORM R160-PARENT
           END-IF
           .
       R150-CHECK-LEVEL-END.
           EXIT.

      *===============================================================*
      * R160-PARENT: After a COUNT of the environment or version      *
      *===============================================================*
       R160-PARENT SECTION.
           EVALUATE TRUE
           WHEN SQLCODE NOT = 0
              MOVE N'SELECT level' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           WHEN W-COUNT = 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM207
              MOVE N'13' TO REASONCODE OF P-LLWDM207
              MOVE N'Environment or version not in this application'
                TO INFOMESSAGE OF P-LLWDM207
           END-EVALUATE
           .
       R160-PARENT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: Up to 20 variables of the level, by VARID          *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT VARID,
                     APPID,
                     COALESCE(ENVID, 0),
                     COALESCE(VERSIONID, 0),
                     VARNAME,
                     VARVALUE,
                     DESCRIPTION,
                     CREATEDBY,
                     CHAR(CREATEDDATE),
                     UPDATEDBY,
                     CHAR(UPDATEDDATE)
                FROM TBLWD007
               WHERE APPID = :W-APPID
                 AND COALESCE(ENVID, 0) = :W-ENVID
                 AND COALESCE(VERSIONID, 0) = :W-VERSIONID
                 AND VARID > :W-SINCE
               ORDER BY VARID
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
                         OR RETURNCODE OF P-LLWDM207 NOT = N'00'
                         OR VAR-COUNT OF P-LLWDM207 >= 20
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
      * R210-FETCH: One variable                                      *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD007.VARID,
                    :DCLTBLWD007.APPID,
                    :DCLTBLWD007.ENVID,
                    :DCLTBLWD007.VERSIONID,
                    :DCLTBLWD007.VARNAME,
                    :DCLTBLWD007.VARVALUE,
                    :DCLTBLWD007.DESCRIPTION
                       :DCLTBLWD007.DESCRIPTION-IND,
                    :DCLTBLWD007.CREATEDBY,
                    :W-CREATED,
                    :DCLTBLWD007.UPDATEDBY,
                    :W-UPDATED
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO VAR-COUNT OF P-LLWDM207
              MOVE VAR-COUNT OF P-LLWDM207 TO W-N
              MOVE VARID OF DCLTBLWD007 TO VARID OF P-LLWDM207(W-N)
              MOVE APPID OF DCLTBLWD007 TO
                   VAR-APPID OF P-LLWDM207(W-N)
              MOVE ENVID OF DCLTBLWD007 TO
                   VAR-ENVID OF P-LLWDM207(W-N)
              MOVE VERSIONID OF DCLTBLWD007 TO
                   VAR-VERSIONID OF P-LLWDM207(W-N)
              MOVE VARNAME OF DCLTBLWD007 TO
                   VARNAME OF P-LLWDM207(W-N)
              MOVE VARVALUE OF DCLTBLWD007 TO
                   VARVALUE OF P-LLWDM207(W-N)
              IF DESCRIPTION-IND OF DCLTBLWD007 >= 0
                 MOVE DESCRIPTION OF DCLTBLWD007 TO
                      VARDESCRIPTION OF P-LLWDM207(W-N)
              ELSE
                 MOVE 0 TO VARDESCRIPTION-LEN OF P-LLWDM207(W-N)
              END-IF
              MOVE CREATEDBY OF DCLTBLWD007 TO
                   CREATEDBY OF P-LLWDM207(W-N)
              MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                   CREATEDDATE OF P-LLWDM207(W-N)
              MOVE UPDATEDBY OF DCLTBLWD007 TO
                   UPDATEDBY OF P-LLWDM207(W-N)
              MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                   UPDATEDDATE OF P-LLWDM207(W-N)
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

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM207==.

       END PROGRAM LWDM207.
