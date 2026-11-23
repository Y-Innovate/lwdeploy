       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM004.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET, POST, PUT and DELETE /admin/applications (A1): create,   *
      * read, update or delete an application, by OPCODE C, R, U or D *
      * (an LWW constant per path). Administrators only.              *
      * APPCODE: A-Z 0-9, at most 8, unique, made upper case. Both    *
      * groups must be in the RACFGRP allowlist. An application with  *
      * deployments can't be deleted; one without takes its           *
      * environments, versions, variables, templates, revisions and   *
      * template lines with it, in this unit of work.                 *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Application not found (R)                             *
      * 08 01 = Error: invalid OPCODE, or a required field is empty   *
      * 08 02 = Error: APPCODE not A-Z 0-9, or a group not in RACFGRP *
      * 08 11 = Error: APPCODE is taken                               *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 31 = Error: update of a missing application                *
      * 08 41 = Error: delete of a missing application                *
      * 08 50 = Error: not an administrator                           *
      * 08 53 = Error: delete of an application with deployments      *
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

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-ALLOWED     PIC N(36) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.
          05 W-I           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-END         PIC X.
          05 W-CH          PIC N.
          05 W-DESC-IND    PIC S9(4) COMP-5.
          05 W-COUNT       PIC S9(9) COMP-5.
          05 W-COUNT-ED    PIC Z(8)9.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM004.
           COPY LLWDM004.

       PROCEDURE DIVISION USING P-LLWDM004.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R098-REQUIRE-ADMIN

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EVALUATE OPCODE OF P-LLWDM004
              WHEN C-C
                 PERFORM R200-VALIDATE
                 PERFORM R300-INSERT
                 PERFORM R800-SELECT
              WHEN C-R
                 PERFORM R800-SELECT
              WHEN C-U
                 PERFORM R400-EXISTS
                 PERFORM R200-VALIDATE
                 PERFORM R410-UPDATE
                 PERFORM R800-SELECT
              WHEN C-D
                 PERFORM R400-EXISTS
                 PERFORM R500-DELETE
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM004
                 MOVE N'01' TO REASONCODE OF P-LLWDM004
                 MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM004
              END-EVALUATE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM004
           MOVE N'00' TO REASONCODE OF P-LLWDM004
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM004

           MOVE APPID OF P-LLWDM004 TO W-APPID

      *    A missing optional field arrives as binary zeros
           IF APPCODE OF P-LLWDM004(1:1) = NX'0000'
              MOVE SPACES TO APPCODE OF P-LLWDM004
           END-IF
           IF ACCESSGROUP OF P-LLWDM004(1:1) = NX'0000'
              MOVE SPACES TO ACCESSGROUP OF P-LLWDM004
           END-IF
           IF OWNERGROUP OF P-LLWDM004(1:1) = NX'0000'
              MOVE SPACES TO OWNERGROUP OF P-LLWDM004
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-VALIDATE: Code, name and the two groups                  *
      *===============================================================*
       R200-VALIDATE SECTION.
           IF RETURNCODE OF P-LLWDM004 = N'00'
              MOVE FUNCTION UPPER-CASE(APPCODE OF P-LLWDM004) TO
                   APPCODE OF P-LLWDM004
              MOVE FUNCTION UPPER-CASE(ACCESSGROUP OF P-LLWDM004) TO
                   ACCESSGROUP OF P-LLWDM004
              MOVE FUNCTION UPPER-CASE(OWNERGROUP OF P-LLWDM004) TO
                   OWNERGROUP OF P-LLWDM004
              EVALUATE TRUE
              WHEN APPCODE OF P-LLWDM004 = SPACES
                 MOVE N'appCode is required' TO
                      INFOMESSAGE OF P-LLWDM004
              WHEN APPNAME-LEN OF P-LLWDM004 < 1
              WHEN APPNAME-TEXT OF P-LLWDM004(1:APPNAME-LEN OF
                   P-LLWDM004) = SPACES
                 MOVE N'appName is required' TO
                      INFOMESSAGE OF P-LLWDM004
              WHEN ACCESSGROUP OF P-LLWDM004 = SPACES
                 MOVE N'accessGroup is required' TO
                      INFOMESSAGE OF P-LLWDM004
              WHEN OWNERGROUP OF P-LLWDM004 = SPACES
                 MOVE N'ownerGroup is required' TO
                      INFOMESSAGE OF P-LLWDM004
              END-EVALUATE
              IF INFOMESSAGE OF P-LLWDM004 NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM004
                 MOVE N'01' TO REASONCODE OF P-LLWDM004
              END-IF
           END-IF

      *    A-Z 0-9 up to the first blank, and only blanks after it
           IF RETURNCODE OF P-LLWDM004 = N'00'
              MOVE 'N' TO W-END
              PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > 8
                 MOVE APPCODE OF P-LLWDM004(W-I:1) TO W-CH
                 IF W-CH = SPACE
                    MOVE 'Y' TO W-END
                 ELSE
                    MOVE 0 TO W-T
                    INSPECT C-ALLOWED TALLYING W-T FOR ALL W-CH
                    IF W-T = 0 OR W-END = 'Y'
                       MOVE N'08' TO RETURNCODE OF P-LLWDM004
                       MOVE N'02' TO REASONCODE OF P-LLWDM004
                       MOVE N'appCode: A-Z and 0-9 only, at most 8' TO
                            INFOMESSAGE OF P-LLWDM004
                    END-IF
                 END-IF
              END-PERFORM
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              MOVE C-RACFGRP TO W-LIST-TABLE
              MOVE ACCESSGROUP OF P-LLWDM004 TO W-LIST-KEY
              PERFORM R210-GROUP-IN-LIST
           END-IF
           IF RETURNCODE OF P-LLWDM004 = N'00'
              MOVE OWNERGROUP OF P-LLWDM004 TO W-LIST-KEY
              PERFORM R210-GROUP-IN-LIST
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              IF APPDESCRIPTION-LEN OF P-LLWDM004 > 0
                 MOVE 0 TO W-DESC-IND
              ELSE
                 MOVE -1 TO W-DESC-IND
                 MOVE 0 TO APPDESCRIPTION-LEN OF P-LLWDM004
              END-IF
           END-IF
           .
       R200-VALIDATE-END.
           EXIT.

      *===============================================================*
      * R210-GROUP-IN-LIST: 08 02 when W-LIST-KEY isn't in RACFGRP    *
      *===============================================================*
       R210-GROUP-IN-LIST SECTION.
           PERFORM R099-IN-LIST

           IF  RETURNCODE OF P-LLWDM004 = N'00'
           AND W-IN-LIST NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LLWDM004
              MOVE N'02' TO REASONCODE OF P-LLWDM004
              STRING W-LIST-KEY DELIMITED BY N' '
                     N' is not in the allowlist of RACF groups'
                        DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM004
           END-IF
           .
       R210-GROUP-IN-LIST-END.
           EXIT.

      *===============================================================*
      * R300-INSERT: The new application                              *
      *===============================================================*
       R300-INSERT SECTION.
           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 SELECT APPID
                   INTO :DCLTBLWD004.APPID
                   FROM FINAL TABLE
                        (INSERT INTO TBLWD004
                              ( APPCODE, APPNAME, DESCRIPTION,
                                ACCESSGROUP, OWNERGROUP,
                                CREATEDBY, CREATEDDATE,
                                UPDATEDBY, UPDATEDDATE )
                         VALUES ( :P-LLWDM004.APPCODE,
                                  :P-LLWDM004.APPNAME,
                                  :P-LLWDM004.APPDESCRIPTION
                                     :W-DESC-IND,
                                  :P-LLWDM004.ACCESSGROUP,
                                  :P-LLWDM004.OWNERGROUP,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  :W-USERID, CURRENT TIMESTAMP ))
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE APPID OF DCLTBLWD004 TO W-APPID
              WHEN -803
                 PERFORM R310-TAKEN
              WHEN OTHER
                 MOVE N'INSERT application' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R300-INSERT-END.
           EXIT.

      *===============================================================*
      * R310-TAKEN: 08 11, the code belongs to another application    *
      *===============================================================*
       R310-TAKEN SECTION.
           MOVE N'08' TO RETURNCODE OF P-LLWDM004
           MOVE N'11' TO REASONCODE OF P-LLWDM004
           STRING N'Application code ' DELIMITED BY SIZE
                  APPCODE OF P-LLWDM004 DELIMITED BY N' '
                  N' is taken' DELIMITED BY SIZE
             INTO INFOMESSAGE OF P-LLWDM004
           .
       R310-TAKEN-END.
           EXIT.

      *===============================================================*
      * R400-EXISTS: The application of U and D exists (08 31, 41)    *
      *===============================================================*
       R400-EXISTS SECTION.
           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 SELECT APPCODE
                   INTO :DCLTBLWD004.APPCODE
                   FROM TBLWD004
                  WHERE APPID = :W-APPID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LLWDM004
                 IF OPCODE OF P-LLWDM004 = C-D
                    MOVE N'41' TO REASONCODE OF P-LLWDM004
                 ELSE
                    MOVE N'31' TO REASONCODE OF P-LLWDM004
                 END-IF
                 MOVE N'Application not found' TO
                      INFOMESSAGE OF P-LLWDM004
              WHEN OTHER
                 MOVE N'SELECT application' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R400-EXISTS-END.
           EXIT.

      *===============================================================*
      * R410-UPDATE: Code, name, description and groups               *
      *===============================================================*
       R410-UPDATE SECTION.
           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 UPDATE TBLWD004
                    SET APPCODE     = :P-LLWDM004.APPCODE,
                        APPNAME     = :P-LLWDM004.APPNAME,
                        DESCRIPTION = :P-LLWDM004.APPDESCRIPTION
                                         :W-DESC-IND,
                        ACCESSGROUP = :P-LLWDM004.ACCESSGROUP,
                        OWNERGROUP  = :P-LLWDM004.OWNERGROUP,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE APPID = :W-APPID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 PERFORM R310-TAKEN
              WHEN OTHER
                 MOVE N'UPDATE application' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R410-UPDATE-END.
           EXIT.

      *===============================================================*
      * R500-DELETE: Refused with deployments; otherwise the children *
      * first (the foreign keys are ON DELETE RESTRICT), then the     *
      * application                                                   *
      *===============================================================*
       R500-DELETE SECTION.
           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD011
                  WHERE APPID = :W-APPID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT deployments' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM004 = N'00'
           AND W-COUNT > 0
              MOVE W-COUNT TO W-COUNT-ED
              MOVE N'08' TO RETURNCODE OF P-LLWDM004
              MOVE N'53' TO REASONCODE OF P-LLWDM004
              STRING APPCODE OF DCLTBLWD004 DELIMITED BY N' '
                     N' has ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-COUNT-ED))
                        DELIMITED BY SIZE
                     N' deployments: it can''t be deleted'
                        DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM004
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD010
                  WHERE TEMPLATEID IN
                        (SELECT TEMPLATEID FROM TBLWD008
                          WHERE APPID = :W-APPID)
              END-EXEC
              MOVE N'DELETE template lines' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD009
                  WHERE TEMPLATEID IN
                        (SELECT TEMPLATEID FROM TBLWD008
                          WHERE APPID = :W-APPID)
              END-EXEC
              MOVE N'DELETE template revisions' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD008
                  WHERE APPID = :W-APPID
              END-EXEC
              MOVE N'DELETE templates' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD007
                  WHERE APPID = :W-APPID
              END-EXEC
              MOVE N'DELETE variables' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD006
                  WHERE APPID = :W-APPID
              END-EXEC
              MOVE N'DELETE environments' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD005
                  WHERE APPID = :W-APPID
              END-EXEC
              MOVE N'DELETE versions' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF

           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD004
                  WHERE APPID = :W-APPID
              END-EXEC
              MOVE N'DELETE application' TO W-SQL-WHAT
              PERFORM R510-CHECK-DELETE
           END-IF
           .
       R500-DELETE-END.
           EXIT.

      *===============================================================*
      * R510-CHECK-DELETE: SQLCODE of a DELETE; 100 is no rows        *
      *===============================================================*
       R510-CHECK-DELETE SECTION.
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE N'42' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R510-CHECK-DELETE-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The application as the response                  *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM004 = N'00'
              EXEC SQL
                 SELECT APPID,
                        APPCODE,
                        APPNAME,
                        DESCRIPTION,
                        ACCESSGROUP,
                        OWNERGROUP,
                        CREATEDBY,
                        CHAR(CREATEDDATE),
                        UPDATEDBY,
                        CHAR(UPDATEDDATE)
                   INTO :DCLTBLWD004.APPID,
                        :DCLTBLWD004.APPCODE,
                        :DCLTBLWD004.APPNAME,
                        :DCLTBLWD004.DESCRIPTION
                           :DCLTBLWD004.DESCRIPTION-IND,
                        :DCLTBLWD004.ACCESSGROUP,
                        :DCLTBLWD004.OWNERGROUP,
                        :DCLTBLWD004.CREATEDBY,
                        :W-CREATED,
                        :DCLTBLWD004.UPDATEDBY,
                        :W-UPDATED
                   FROM TBLWD004
                  WHERE APPID = :W-APPID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R810-COPY
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM004
                 MOVE N'01' TO REASONCODE OF P-LLWDM004
                 MOVE N'Application not found' TO
                      INFOMESSAGE OF P-LLWDM004
              WHEN OTHER
                 MOVE N'SELECT application' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R800-SELECT-END.
           EXIT.

      *===============================================================*
      * R810-COPY: Copy the selected application                      *
      *===============================================================*
       R810-COPY SECTION.
           MOVE APPID OF DCLTBLWD004 TO APPID OF P-LLWDM004
           MOVE APPCODE OF DCLTBLWD004 TO APPCODE OF P-LLWDM004
           MOVE APPNAME OF DCLTBLWD004 TO APPNAME OF P-LLWDM004
           IF DESCRIPTION-IND OF DCLTBLWD004 >= 0
              MOVE DESCRIPTION OF DCLTBLWD004 TO
                   APPDESCRIPTION OF P-LLWDM004
           ELSE
              MOVE 0 TO APPDESCRIPTION-LEN OF P-LLWDM004
           END-IF
           MOVE ACCESSGROUP OF DCLTBLWD004 TO
                ACCESSGROUP OF P-LLWDM004
           MOVE OWNERGROUP OF DCLTBLWD004 TO OWNERGROUP OF P-LLWDM004
           MOVE CREATEDBY OF DCLTBLWD004 TO CREATEDBY OF P-LLWDM004
           MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                CREATEDDATE OF P-LLWDM004
           MOVE UPDATEDBY OF DCLTBLWD004 TO UPDATEDBY OF P-LLWDM004
           MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                UPDATEDDATE OF P-LLWDM004
           .
       R810-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM004==.

       END PROGRAM LWDM004.
