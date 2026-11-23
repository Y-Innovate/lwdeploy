       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM005.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * One version, by OPCODE (an LWW constant per path):            *
      * R GET /versions/{versionID} (M2, O4), for whoever may see its *
      *   application                                                 *
      * U PUT /versions/{versionID}: name, location and description,  *
      *   with the checks of LWDM405, which creates versions          *
      * D DELETE /versions/{versionID}, with its variables            *
      * T POST /versionRetirements/{versionID}: status R, once        *
      * U, D and T are for owners of the application only             *
      * (administrators too). U and D only while ISUSED is N: the     *
      * version was never requested for a deployment. A retired       *
      * version stays in the inventory and history.                   *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Version not found, or no role in its application      *
      * 08 01 = Error: invalid OPCODE, or versionName not valid       *
      * 08 02 = Error: LOCTYPE is not D or U                          *
      * 08 03 = Error: location empty or invalid for its type         *
      * 08 11 = Error: the application has a version of this name     *
      * 08 21/32/42 = Error: SQL error                                *
      * 08 31 = Error: update or retirement of a missing version      *
      * 08 41 = Error: delete of a missing version                    *
      * 08 50 = Error: not an owner of the application                *
      * 08 53 = Error: used (U, D), or retired already (T)            *
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

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-ALLOWED     PIC N(39) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-'.
          05 W-VERSIONID   PIC S9(9) COMP-5.
          05 W-I           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-CH          PIC N.
          05 W-USED        PIC X.
          05 W-DESC-IND    PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM005.
           COPY LLWDM005.

       PROCEDURE DIVISION USING P-LLWDM005.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF  RETURNCODE OF P-LLWDM005 = N'00'
           AND OPCODE OF P-LLWDM005 NOT = C-R
           AND OPCODE OF P-LLWDM005 NOT = C-U
           AND OPCODE OF P-LLWDM005 NOT = C-D
           AND OPCODE OF P-LLWDM005 NOT = C-T
              MOVE N'08' TO RETURNCODE OF P-LLWDM005
              MOVE N'01' TO REASONCODE OF P-LLWDM005
              MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM005
           END-IF

           PERFORM R150-VERSION-APP
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE
           IF OPCODE OF P-LLWDM005 NOT = C-R
              PERFORM R106-REQUIRE-OWNER
           END-IF

           EVALUATE OPCODE OF P-LLWDM005
           WHEN C-U
              PERFORM R200-REQUIRE-UNUSED
              PERFORM R300-VALIDATE
              PERFORM R310-UPDATE
           WHEN C-D
              PERFORM R200-REQUIRE-UNUSED
              PERFORM R400-DELETE
           WHEN C-T
              PERFORM R500-RETIRE
           END-EVALUATE

           IF OPCODE OF P-LLWDM005 NOT = C-D
              PERFORM R800-SELECT
           END-IF

      *    Not the application: the version is what was asked for
           IF RETURNCODE OF P-LLWDM005 = N'04'
              MOVE N'Version not found' TO INFOMESSAGE OF P-LLWDM005
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM005
           MOVE N'00' TO REASONCODE OF P-LLWDM005
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM005

           MOVE VERSIONID OF P-LLWDM005 TO W-VERSIONID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-VERSION-APP: W-APPID, name and status of the version,    *
      * and W-USED; not found is 04 01 (R), 08 41 (D) or 08 31        *
      *===============================================================*
       R150-VERSION-APP SECTION.
           IF RETURNCODE OF P-LLWDM005 = N'00'
              EXEC SQL
                 SELECT V.APPID,
                        V.VERSIONNAME,
                        V.VERSIONSTATUS,
                        CASE WHEN EXISTS
                             (SELECT 1 FROM TBLWD011 D
                               WHERE D.VERSIONID = V.VERSIONID)
                             THEN 'Y' ELSE 'N' END
                   INTO :W-APPID,
                        :DCLTBLWD005.VERSIONNAME,
                        :DCLTBLWD005.VERSIONSTATUS,
                        :W-USED
                   FROM TBLWD005 V
                  WHERE V.VERSIONID = :W-VERSIONID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 EVALUATE OPCODE OF P-LLWDM005
                 WHEN C-R
                    MOVE N'04' TO RETURNCODE OF P-LLWDM005
                    MOVE N'01' TO REASONCODE OF P-LLWDM005
                 WHEN C-D
                    MOVE N'08' TO RETURNCODE OF P-LLWDM005
                    MOVE N'41' TO REASONCODE OF P-LLWDM005
                 WHEN OTHER
                    MOVE N'08' TO RETURNCODE OF P-LLWDM005
                    MOVE N'31' TO REASONCODE OF P-LLWDM005
                 END-EVALUATE
                 MOVE N'Version not found' TO INFOMESSAGE OF P-LLWDM005
              WHEN OTHER
                 MOVE N'SELECT version' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R150-VERSION-APP-END.
           EXIT.

      *===============================================================*
      * R200-REQUIRE-UNUSED: 08 53 once requested for a deployment    *
      *===============================================================*
       R200-REQUIRE-UNUSED SECTION.
           IF  RETURNCODE OF P-LLWDM005 = N'00'
           AND W-USED = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LLWDM005
              MOVE N'53' TO REASONCODE OF P-LLWDM005
              IF OPCODE OF P-LLWDM005 = C-D
                 STRING VERSIONNAME-TEXT OF DCLTBLWD005(1:
                           VERSIONNAME-LEN OF DCLTBLWD005)
                           DELIMITED BY SIZE
                        N' has been deployed: retire it instead'
                           DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM005
              ELSE
                 STRING VERSIONNAME-TEXT OF DCLTBLWD005(1:
                           VERSIONNAME-LEN OF DCLTBLWD005)
                           DELIMITED BY SIZE
                        N' has been deployed: it can''t be changed'
                           DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM005
              END-IF
           END-IF
           .
       R200-REQUIRE-UNUSED-END.
           EXIT.

      *===============================================================*
      * R300-VALIDATE: Name, type and location, as LWDM405            *
      *===============================================================*
       R300-VALIDATE SECTION.
           IF RETURNCODE OF P-LLWDM005 = N'00'
              IF VERSIONNAME-LEN OF P-LLWDM005 < 1
              OR VERSIONNAME-LEN OF P-LLWDM005 > 30
                 MOVE N'08' TO RETURNCODE OF P-LLWDM005
                 MOVE N'01' TO REASONCODE OF P-LLWDM005
                 MOVE N'versionName is empty' TO
                      INFOMESSAGE OF P-LLWDM005
              ELSE
                 MOVE FUNCTION UPPER-CASE(VERSIONNAME-TEXT OF
                      P-LLWDM005) TO VERSIONNAME-TEXT OF P-LLWDM005
                 PERFORM VARYING W-I FROM 1 BY 1
                           UNTIL W-I > VERSIONNAME-LEN OF P-LLWDM005
                              OR RETURNCODE OF P-LLWDM005 NOT = N'00'
                    MOVE VERSIONNAME-TEXT OF P-LLWDM005(W-I:1) TO W-CH
                    MOVE 0 TO W-T
                    INSPECT C-ALLOWED TALLYING W-T FOR ALL W-CH
                    IF W-T = 0
                       MOVE N'08' TO RETURNCODE OF P-LLWDM005
                       MOVE N'01' TO REASONCODE OF P-LLWDM005
                       MOVE N'versionName may hold A-Z 0-9 . _ - only'
                         TO INFOMESSAGE OF P-LLWDM005
                    END-IF
                 END-PERFORM
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM005 = N'00'
              MOVE FUNCTION UPPER-CASE(LOCTYPE OF P-LLWDM005) TO
                   LOCTYPE OF P-LLWDM005
              IF  LOCTYPE OF P-LLWDM005 NOT = C-D
              AND LOCTYPE OF P-LLWDM005 NOT = C-U
                 MOVE N'08' TO RETURNCODE OF P-LLWDM005
                 MOVE N'02' TO REASONCODE OF P-LLWDM005
                 MOVE N'locType must be D or U' TO
                      INFOMESSAGE OF P-LLWDM005
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM005 = N'00'
              EVALUATE TRUE
              WHEN LOCATION-LEN OF P-LLWDM005 < 1
              WHEN LOCATION-LEN OF P-LLWDM005 > 255
                 MOVE N'location is empty' TO INFOMESSAGE OF P-LLWDM005
              WHEN LOCTYPE OF P-LLWDM005 = C-D
               AND LOCATION-LEN OF P-LLWDM005 > 44
                 MOVE N'A dataset prefix has at most 44 characters' TO
                      INFOMESSAGE OF P-LLWDM005
              WHEN LOCTYPE OF P-LLWDM005 = C-U
               AND LOCATION-TEXT OF P-LLWDM005(1:1) NOT = N'/'
                 MOVE N'A USS path starts with /' TO
                      INFOMESSAGE OF P-LLWDM005
              END-EVALUATE
              IF INFOMESSAGE OF P-LLWDM005 NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM005
                 MOVE N'03' TO REASONCODE OF P-LLWDM005
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM005 = N'00'
              IF LOCTYPE OF P-LLWDM005 = C-D
                 MOVE FUNCTION UPPER-CASE(LOCATION-TEXT OF P-LLWDM005)
                   TO LOCATION-TEXT OF P-LLWDM005
              END-IF
              IF DESCRIPTION-LEN OF P-LLWDM005 > 0
                 MOVE 0 TO W-DESC-IND
              ELSE
                 MOVE -1 TO W-DESC-IND
                 MOVE 0 TO DESCRIPTION-LEN OF P-LLWDM005
              END-IF
           END-IF
           .
       R300-VALIDATE-END.
           EXIT.

      *===============================================================*
      * R310-UPDATE: Name, type, location and description             *
      *===============================================================*
       R310-UPDATE SECTION.
           IF RETURNCODE OF P-LLWDM005 = N'00'
              EXEC SQL
                 UPDATE TBLWD005
                    SET VERSIONNAME = :P-LLWDM005.VERSIONNAME,
                        LOCTYPE     = :P-LLWDM005.LOCTYPE,
                        LOCATION    = :P-LLWDM005.LOCATION,
                        DESCRIPTION = :P-LLWDM005.DESCRIPTION
                                         :W-DESC-IND,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE VERSIONID = :W-VERSIONID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 MOVE N'08' TO RETURNCODE OF P-LLWDM005
                 MOVE N'11' TO REASONCODE OF P-LLWDM005
                 STRING N'The application has a version ' DELIMITED BY
                           SIZE
                        VERSIONNAME-TEXT OF P-LLWDM005(1:
                           VERSIONNAME-LEN OF P-LLWDM005)
                           DELIMITED BY SIZE
                        N' already' DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM005
              WHEN OTHER
                 MOVE N'UPDATE version' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R310-UPDATE-END.
           EXIT.

      *===============================================================*
      * R400-DELETE: Its variables, then the version                  *
      *===============================================================*
       R400-DELETE SECTION.
           IF RETURNCODE OF P-LLWDM005 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD007
                  WHERE VERSIONID = :W-VERSIONID
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'DELETE variables' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM005 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD005
                  WHERE VERSIONID = :W-VERSIONID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'DELETE version' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R400-DELETE-END.
           EXIT.

      *===============================================================*
      * R500-RETIRE: Status R, once                                   *
      *===============================================================*
       R500-RETIRE SECTION.
           IF  RETURNCODE OF P-LLWDM005 = N'00'
           AND VERSIONSTATUS OF DCLTBLWD005 = C-R
              MOVE N'08' TO RETURNCODE OF P-LLWDM005
              MOVE N'53' TO REASONCODE OF P-LLWDM005
              STRING VERSIONNAME-TEXT OF DCLTBLWD005(1:
                        VERSIONNAME-LEN OF DCLTBLWD005)
                        DELIMITED BY SIZE
                     N' is retired already' DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM005
           END-IF

           IF RETURNCODE OF P-LLWDM005 = N'00'
              EXEC SQL
                 UPDATE TBLWD005
                    SET VERSIONSTATUS = :C-R,
                        UPDATEDBY     = :W-USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE VERSIONID = :W-VERSIONID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE version' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R500-RETIRE-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The version as the response                      *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM005 = N'00'
              EXEC SQL
                 SELECT VERSIONID,
                        APPID,
                        VERSIONNAME,
                        LOCTYPE,
                        LOCATION,
                        DESCRIPTION,
                        VERSIONSTATUS,
                        CREATEDBY,
                        CHAR(CREATEDDATE),
                        UPDATEDBY,
                        CHAR(UPDATEDDATE)
                   INTO :DCLTBLWD005.VERSIONID,
                        :DCLTBLWD005.APPID,
                        :DCLTBLWD005.VERSIONNAME,
                        :DCLTBLWD005.LOCTYPE,
                        :DCLTBLWD005.LOCATION,
                        :DCLTBLWD005.DESCRIPTION
                           :DCLTBLWD005.DESCRIPTION-IND,
                        :DCLTBLWD005.VERSIONSTATUS,
                        :DCLTBLWD005.CREATEDBY,
                        :W-CREATED,
                        :DCLTBLWD005.UPDATEDBY,
                        :W-UPDATED
                   FROM TBLWD005
                  WHERE VERSIONID = :W-VERSIONID
              END-EXEC

              IF SQLCODE = 0
                 MOVE VERSIONID OF DCLTBLWD005 TO
                      VERSIONID OF P-LLWDM005
                 MOVE APPID OF DCLTBLWD005 TO APPID OF P-LLWDM005
                 MOVE VERSIONNAME OF DCLTBLWD005 TO
                      VERSIONNAME OF P-LLWDM005
                 MOVE LOCTYPE OF DCLTBLWD005 TO LOCTYPE OF P-LLWDM005
                 MOVE LOCATION OF DCLTBLWD005 TO LOCATION OF P-LLWDM005
                 IF DESCRIPTION-IND OF DCLTBLWD005 >= 0
                    MOVE DESCRIPTION OF DCLTBLWD005 TO
                         DESCRIPTION OF P-LLWDM005
                 ELSE
                    MOVE 0 TO DESCRIPTION-LEN OF P-LLWDM005
                 END-IF
                 MOVE VERSIONSTATUS OF DCLTBLWD005 TO
                      VERSIONSTATUS OF P-LLWDM005
                 MOVE FUNCTION NATIONAL-OF(W-USED) TO
                      ISUSED OF P-LLWDM005
                 MOVE CREATEDBY OF DCLTBLWD005 TO
                      CREATEDBY OF P-LLWDM005
                 MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                      CREATEDDATE OF P-LLWDM005
                 MOVE UPDATEDBY OF DCLTBLWD005 TO
                      UPDATEDBY OF P-LLWDM005
                 MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                      UPDATEDDATE OF P-LLWDM005
              ELSE
                 MOVE N'SELECT version' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R800-SELECT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM005==.

       END PROGRAM LWDM005.
