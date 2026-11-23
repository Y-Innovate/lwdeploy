       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM405.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /versions: register a version (O4), by an owner or the   *
      * CI pipeline, whose service userid is in the owner group.      *
      * The name is made upper case and may hold A-Z 0-9 . _ - only,  *
      * as it goes into JCL as ${LWDVER}. LOCTYPE D: a dataset        *
      * prefix of at most 44 characters; U: a USS path starting with  *
      * a slash. Whether it exists is not checked: the jobs do that.  *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Application not found, or no role in it               *
      * 08 01 = Error: name empty or with other characters            *
      * 08 02 = Error: LOCTYPE is not D or U                          *
      * 08 03 = Error: location empty or invalid for its type         *
      * 08 11 = Error: the application has a version of this name     *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 50 = Error: not an owner of the application                *
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

           COPY LWDCTXW.

       01 WORK.
          05 C-ALLOWED     PIC N(39) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-'.
          05 W-I           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-CH          PIC N.
          05 W-DESC-IND    PIC S9(4) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM405.
           COPY LLWDM405.

       PROCEDURE DIVISION USING P-LLWDM405.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE
           PERFORM R110-REQUIRE-OWNER

           PERFORM R200-VALIDATE
           PERFORM R300-INSERT
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM405
           MOVE N'00' TO REASONCODE OF P-LLWDM405
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM405

           MOVE APPID OF P-LLWDM405 TO W-APPID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-REQUIRE-OWNER: Only owners register versions             *
      *===============================================================*
       R110-REQUIRE-OWNER SECTION.
           IF  RETURNCODE OF P-LLWDM405 = N'00'
           AND W-IS-OWNER NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LLWDM405
              MOVE N'50' TO REASONCODE OF P-LLWDM405
              MOVE N'Only owners of the application register versions'
                TO INFOMESSAGE OF P-LLWDM405
           END-IF
           .
       R110-REQUIRE-OWNER-END.
           EXIT.

      *===============================================================*
      * R200-VALIDATE: Name, type and location                        *
      *===============================================================*
       R200-VALIDATE SECTION.
           IF RETURNCODE OF P-LLWDM405 = N'00'
              IF VERSIONNAME-LEN OF P-LLWDM405 < 1
              OR VERSIONNAME-LEN OF P-LLWDM405 > 30
                 MOVE N'08' TO RETURNCODE OF P-LLWDM405
                 MOVE N'01' TO REASONCODE OF P-LLWDM405
                 MOVE N'versionName is empty' TO
                      INFOMESSAGE OF P-LLWDM405
              ELSE
                 MOVE FUNCTION UPPER-CASE(VERSIONNAME-TEXT OF
                      P-LLWDM405) TO VERSIONNAME-TEXT OF P-LLWDM405
                 PERFORM VARYING W-I FROM 1 BY 1
                           UNTIL W-I > VERSIONNAME-LEN OF P-LLWDM405
                              OR RETURNCODE OF P-LLWDM405 NOT = N'00'
                    MOVE VERSIONNAME-TEXT OF P-LLWDM405(W-I:1) TO W-CH
                    MOVE 0 TO W-T
                    INSPECT C-ALLOWED TALLYING W-T FOR ALL W-CH
                    IF W-T = 0
                       MOVE N'08' TO RETURNCODE OF P-LLWDM405
                       MOVE N'01' TO REASONCODE OF P-LLWDM405
                       MOVE N'versionName may hold A-Z 0-9 . _ - only'
                         TO INFOMESSAGE OF P-LLWDM405
                    END-IF
                 END-PERFORM
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM405 = N'00'
           AND LOCTYPE OF P-LLWDM405 NOT = C-D
           AND LOCTYPE OF P-LLWDM405 NOT = C-U
              MOVE N'08' TO RETURNCODE OF P-LLWDM405
              MOVE N'02' TO REASONCODE OF P-LLWDM405
              MOVE N'locType must be D or U' TO
                   INFOMESSAGE OF P-LLWDM405
           END-IF

           IF RETURNCODE OF P-LLWDM405 = N'00'
              EVALUATE TRUE
              WHEN LOCATION-LEN OF P-LLWDM405 < 1
              WHEN LOCATION-LEN OF P-LLWDM405 > 255
                 MOVE N'location is empty' TO INFOMESSAGE OF P-LLWDM405
              WHEN LOCTYPE OF P-LLWDM405 = C-D
               AND LOCATION-LEN OF P-LLWDM405 > 44
                 MOVE N'A dataset prefix has at most 44 characters' TO
                      INFOMESSAGE OF P-LLWDM405
              WHEN LOCTYPE OF P-LLWDM405 = C-U
               AND LOCATION-TEXT OF P-LLWDM405(1:1) NOT = N'/'
                 MOVE N'A USS path starts with /' TO
                      INFOMESSAGE OF P-LLWDM405
              END-EVALUATE
              IF INFOMESSAGE OF P-LLWDM405 NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM405
                 MOVE N'03' TO REASONCODE OF P-LLWDM405
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM405 = N'00'
              IF  LOCTYPE OF P-LLWDM405 = C-D
                 MOVE FUNCTION UPPER-CASE(LOCATION-TEXT OF P-LLWDM405)
                   TO LOCATION-TEXT OF P-LLWDM405
              END-IF
              IF DESCRIPTION-LEN OF P-LLWDM405 > 0
                 MOVE 0 TO W-DESC-IND
              ELSE
                 MOVE -1 TO W-DESC-IND
                 MOVE 0 TO DESCRIPTION-LEN OF P-LLWDM405
              END-IF
           END-IF
           .
       R200-VALIDATE-END.
           EXIT.

      *===============================================================*
      * R300-INSERT: Insert the version and return it                 *
      *===============================================================*
       R300-INSERT SECTION.
           IF RETURNCODE OF P-LLWDM405 = N'00'
              EXEC SQL
                 SELECT VERSIONID,
                        CHAR(CREATEDDATE)
                   INTO :DCLTBLWD005.VERSIONID,
                        :DCLTBLWD005.CREATEDDATE
                   FROM FINAL TABLE
                        (INSERT INTO TBLWD005
                              ( APPID, VERSIONNAME, LOCTYPE, LOCATION,
                                DESCRIPTION, VERSIONSTATUS,
                                CREATEDBY, CREATEDDATE,
                                UPDATEDBY, UPDATEDDATE )
                         VALUES ( :W-APPID,
                                  :P-LLWDM405.VERSIONNAME,
                                  :P-LLWDM405.LOCTYPE,
                                  :P-LLWDM405.LOCATION,
                                  :P-LLWDM405.DESCRIPTION :W-DESC-IND,
                                  :C-A,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  :W-USERID, CURRENT TIMESTAMP ))
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE VERSIONID OF DCLTBLWD005 TO
                      VERSIONID OF P-LLWDM405
                 MOVE C-A TO VERSIONSTATUS OF P-LLWDM405
                 MOVE C-N TO ISUSED OF P-LLWDM405
                 MOVE W-USERID TO CREATEDBY OF P-LLWDM405
                 MOVE W-USERID TO UPDATEDBY OF P-LLWDM405
                 MOVE FUNCTION NATIONAL-OF(CREATEDDATE OF DCLTBLWD005)
                   TO CREATEDDATE OF P-LLWDM405
                 MOVE CREATEDDATE OF P-LLWDM405 TO
                      UPDATEDDATE OF P-LLWDM405
              WHEN -803
                 MOVE N'08' TO RETURNCODE OF P-LLWDM405
                 MOVE N'11' TO REASONCODE OF P-LLWDM405
                 MOVE N'The application has a version of this name' TO
                      INFOMESSAGE OF P-LLWDM405
              WHEN OTHER
                 MOVE N'INSERT version' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R300-INSERT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM405==.

       END PROGRAM LWDM405.
