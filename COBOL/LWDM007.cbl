       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM007.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST, PUT and DELETE /variables (O1, O3, O4): a variable of   *
      * one level, by OPCODE C, U or D (an LWW constant per path).    *
      * Owners of the application only (administrators too).         *
      * C: the level comes from ENVID and VERSIONID (both 0: the      *
      *   application; both set: 08 02); the environment or version   *
      *   must be one of the application (08 13).                     *
      * C, U: VARNAME A-Z 0-9 _, starting with a letter, at most 16,  *
      *   not starting with LWD (the built-ins), made upper case;     *
      *   unique per level. U keeps the level. Values are never       *
      *   secret.                                                     *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Application not found, or no role in it               *
      * 08 01 = Error: invalid OPCODE, or VARNAME empty               *
      * 08 02 = Error: both levels, or VARNAME not valid              *
      * 08 11 = Error: the level has a variable of this name          *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 13 = Error: environment or version not of the application  *
      * 08 31 = Error: update of a missing variable                   *
      * 08 41 = Error: delete of a missing variable                   *
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

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD007 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-FIRST       PIC N(26) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
          05 C-NAME        PIC N(37) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
          05 W-VARID       PIC S9(9) COMP-5.
          05 W-ENVID       PIC S9(9) COMP-5.
          05 W-VERSIONID   PIC S9(9) COMP-5.
          05 W-ENV-IND     PIC S9(4) COMP-5.
          05 W-VER-IND     PIC S9(4) COMP-5.
          05 W-DESC-IND    PIC S9(4) COMP-5.
          05 W-COUNT       PIC S9(9) COMP-5.
          05 W-I           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-CH          PIC N.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM007.
           COPY LLWDM007.

       PROCEDURE DIVISION USING P-LLWDM007.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           EVALUATE OPCODE OF P-LLWDM007
           WHEN C-C
              MOVE APPID OF P-LLWDM007 TO W-APPID
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R106-REQUIRE-OWNER
              PERFORM R200-CHECK-LEVEL
              PERFORM R300-CHECK-NAME
              PERFORM R400-INSERT
              PERFORM R800-SELECT
           WHEN C-U
              PERFORM R150-VARIABLE-APP
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R106-REQUIRE-OWNER
              PERFORM R300-CHECK-NAME
              PERFORM R410-UPDATE
              PERFORM R800-SELECT
           WHEN C-D
              PERFORM R150-VARIABLE-APP
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R106-REQUIRE-OWNER
              PERFORM R500-DELETE
           WHEN OTHER
              IF RETURNCODE OF P-LLWDM007 = N'00'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM007
                 MOVE N'01' TO REASONCODE OF P-LLWDM007
                 MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM007
              END-IF
           END-EVALUATE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM007
           MOVE N'00' TO REASONCODE OF P-LLWDM007
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM007

           MOVE VARID OF P-LLWDM007 TO W-VARID
           MOVE ENVID OF P-LLWDM007 TO W-ENVID
           MOVE VERSIONID OF P-LLWDM007 TO W-VERSIONID

           IF VARDESCRIPTION-LEN OF P-LLWDM007 > 0
              MOVE 0 TO W-DESC-IND
           ELSE
              MOVE -1 TO W-DESC-IND
              MOVE 0 TO VARDESCRIPTION-LEN OF P-LLWDM007
           END-IF
           IF VARVALUE-LEN OF P-LLWDM007 < 0
              MOVE 0 TO VARVALUE-LEN OF P-LLWDM007
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-VARIABLE-APP: W-APPID of the variable of U and D         *
      *===============================================================*
       R150-VARIABLE-APP SECTION.
           IF RETURNCODE OF P-LLWDM007 = N'00'
              EXEC SQL
                 SELECT APPID
                   INTO :W-APPID
                   FROM TBLWD007
                  WHERE VARID = :W-VARID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LLWDM007
                 IF OPCODE OF P-LLWDM007 = C-D
                    MOVE N'41' TO REASONCODE OF P-LLWDM007
                 ELSE
                    MOVE N'31' TO REASONCODE OF P-LLWDM007
                 END-IF
                 MOVE N'Variable not found' TO INFOMESSAGE OF P-LLWDM007
              WHEN OTHER
                 MOVE N'SELECT variable' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R150-VARIABLE-APP-END.
           EXIT.

      *===============================================================*
      * R200-CHECK-LEVEL: One level, and of this application; the     *
      * indicators of ENVID and VERSIONID                             *
      *===============================================================*
       R200-CHECK-LEVEL SECTION.
           IF  RETURNCODE OF P-LLWDM007 = N'00'
           AND W-ENVID > 0 AND W-VERSIONID > 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM007
              MOVE N'02' TO REASONCODE OF P-LLWDM007
              MOVE N'A variable belongs to an environment or a version'
                TO INFOMESSAGE OF P-LLWDM007
           END-IF

           IF  RETURNCODE OF P-LLWDM007 = N'00'
           AND W-ENVID > 0
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD006
                  WHERE ENVID = :W-ENVID
                    AND APPID = :W-APPID
              END-EXEC
              PERFORM R210-PARENT
           END-IF

           IF  RETURNCODE OF P-LLWDM007 = N'00'
           AND W-VERSIONID > 0
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD005
                  WHERE VERSIONID = :W-VERSIONID
                    AND APPID = :W-APPID
              END-EXEC
              PERFORM R210-PARENT
           END-IF

           MOVE 0 TO W-ENV-IND W-VER-IND
           IF W-ENVID <= 0
              MOVE -1 TO W-ENV-IND
           END-IF
           IF W-VERSIONID <= 0
              MOVE -1 TO W-VER-IND
           END-IF
           .
       R200-CHECK-LEVEL-END.
           EXIT.

      *===============================================================*
      * R210-PARENT: After a COUNT of the environment or version      *
      *===============================================================*
       R210-PARENT SECTION.
           EVALUATE TRUE
           WHEN SQLCODE NOT = 0
              MOVE N'SELECT level' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           WHEN W-COUNT = 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM007
              MOVE N'13' TO REASONCODE OF P-LLWDM007
              MOVE N'Environment or version not in this application'
                TO INFOMESSAGE OF P-LLWDM007
           END-EVALUATE
           .
       R210-PARENT-END.
           EXIT.

      *===============================================================*
      * R300-CHECK-NAME: A-Z 0-9 _, a letter first, at most 16, not   *
      * LWD...                                                        *
      *===============================================================*
       R300-CHECK-NAME SECTION.
           IF RETURNCODE OF P-LLWDM007 = N'00'
              IF VARNAME-LEN OF P-LLWDM007 < 1
              OR VARNAME-LEN OF P-LLWDM007 > 16
                 MOVE N'08' TO RETURNCODE OF P-LLWDM007
                 MOVE N'01' TO REASONCODE OF P-LLWDM007
                 MOVE N'varName is required' TO
                      INFOMESSAGE OF P-LLWDM007
              ELSE
                 MOVE FUNCTION UPPER-CASE(VARNAME-TEXT OF P-LLWDM007)
                   TO VARNAME-TEXT OF P-LLWDM007
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM007 = N'00'
              PERFORM VARYING W-I FROM 1 BY 1
                        UNTIL W-I > VARNAME-LEN OF P-LLWDM007
                 MOVE VARNAME-TEXT OF P-LLWDM007(W-I:1) TO W-CH
                 MOVE 0 TO W-T
                 IF W-I = 1
                    INSPECT C-FIRST TALLYING W-T FOR ALL W-CH
                 ELSE
                    INSPECT C-NAME TALLYING W-T FOR ALL W-CH
                 END-IF
                 IF  W-T = 0
                 AND RETURNCODE OF P-LLWDM007 = N'00'
                    MOVE N'08' TO RETURNCODE OF P-LLWDM007
                    MOVE N'02' TO REASONCODE OF P-LLWDM007
                    MOVE N'varName: A-Z 0-9 _, starting with a letter'
                      TO INFOMESSAGE OF P-LLWDM007
                 END-IF
              END-PERFORM
           END-IF

           IF  RETURNCODE OF P-LLWDM007 = N'00'
           AND VARNAME-LEN OF P-LLWDM007 >= 3
           AND VARNAME-TEXT OF P-LLWDM007(1:3) = N'LWD'
              MOVE N'08' TO RETURNCODE OF P-LLWDM007
              MOVE N'02' TO REASONCODE OF P-LLWDM007
              MOVE N'varName: names starting with LWD are LWD''s own'
                TO INFOMESSAGE OF P-LLWDM007
           END-IF
           .
       R300-CHECK-NAME-END.
           EXIT.

      *===============================================================*
      * R310-TAKEN: 08 11, the level has the name already             *
      *===============================================================*
       R310-TAKEN SECTION.
           MOVE N'08' TO RETURNCODE OF P-LLWDM007
           MOVE N'11' TO REASONCODE OF P-LLWDM007
           STRING VARNAME-TEXT OF P-LLWDM007(1:VARNAME-LEN OF
                     P-LLWDM007) DELIMITED BY SIZE
                  N' is defined at this level already'
                     DELIMITED BY SIZE
             INTO INFOMESSAGE OF P-LLWDM007
           .
       R310-TAKEN-END.
           EXIT.

      *===============================================================*
      * R400-INSERT: The new variable                                 *
      *===============================================================*
       R400-INSERT SECTION.
           IF RETURNCODE OF P-LLWDM007 = N'00'
              EXEC SQL
                 SELECT VARID
                   INTO :W-VARID
                   FROM FINAL TABLE
                        (INSERT INTO TBLWD007
                              ( APPID, ENVID, VERSIONID, VARNAME,
                                VARVALUE, DESCRIPTION,
                                CREATEDBY, CREATEDDATE,
                                UPDATEDBY, UPDATEDDATE )
                         VALUES ( :W-APPID,
                                  :W-ENVID :W-ENV-IND,
                                  :W-VERSIONID :W-VER-IND,
                                  :P-LLWDM007.VARNAME,
                                  :P-LLWDM007.VARVALUE,
                                  :P-LLWDM007.VARDESCRIPTION
                                     :W-DESC-IND,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  :W-USERID, CURRENT TIMESTAMP ))
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 PERFORM R310-TAKEN
              WHEN OTHER
                 MOVE N'INSERT variable' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R400-INSERT-END.
           EXIT.

      *===============================================================*
      * R410-UPDATE: Name, value and description                      *
      *===============================================================*
       R410-UPDATE SECTION.
           IF RETURNCODE OF P-LLWDM007 = N'00'
              EXEC SQL
                 UPDATE TBLWD007
                    SET VARNAME     = :P-LLWDM007.VARNAME,
                        VARVALUE    = :P-LLWDM007.VARVALUE,
                        DESCRIPTION = :P-LLWDM007.VARDESCRIPTION
                                         :W-DESC-IND,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE VARID = :W-VARID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 PERFORM R310-TAKEN
              WHEN OTHER
                 MOVE N'UPDATE variable' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R410-UPDATE-END.
           EXIT.

      *===============================================================*
      * R500-DELETE: The variable                                     *
      *===============================================================*
       R500-DELETE SECTION.
           IF RETURNCODE OF P-LLWDM007 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD007
                  WHERE VARID = :W-VARID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'DELETE variable' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R500-DELETE-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The variable as the response                     *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM007 = N'00'
              EXEC SQL
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
                   FROM TBLWD007
                  WHERE VARID = :W-VARID
              END-EXEC

              IF SQLCODE = 0
                 MOVE VARID OF DCLTBLWD007 TO VARID OF P-LLWDM007
                 MOVE APPID OF DCLTBLWD007 TO APPID OF P-LLWDM007
                 MOVE ENVID OF DCLTBLWD007 TO ENVID OF P-LLWDM007
                 MOVE VERSIONID OF DCLTBLWD007 TO
                      VERSIONID OF P-LLWDM007
                 MOVE VARNAME OF DCLTBLWD007 TO VARNAME OF P-LLWDM007
                 MOVE VARVALUE OF DCLTBLWD007 TO VARVALUE OF P-LLWDM007
                 IF DESCRIPTION-IND OF DCLTBLWD007 >= 0
                    MOVE DESCRIPTION OF DCLTBLWD007 TO
                         VARDESCRIPTION OF P-LLWDM007
                 ELSE
                    MOVE 0 TO VARDESCRIPTION-LEN OF P-LLWDM007
                 END-IF
                 MOVE CREATEDBY OF DCLTBLWD007 TO
                      CREATEDBY OF P-LLWDM007
                 MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                      CREATEDDATE OF P-LLWDM007
                 MOVE UPDATEDBY OF DCLTBLWD007 TO
                      UPDATEDBY OF P-LLWDM007
                 MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                      UPDATEDDATE OF P-LLWDM007
              ELSE
                 MOVE N'SELECT variable' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R800-SELECT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM007==.

       END PROGRAM LWDM007.
