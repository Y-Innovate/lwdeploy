       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM008.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * One job template (O2), by OPCODE (an LWW constant per path):  *
      * R GET /templates/{templateID}, for whoever may see the        *
      *   application; a deleted template too, so frozen JCL can be   *
      *   traced to it                                                *
      * C POST /templates: without JCL (CURRENTREV 0), status A, at   *
      *   most 20 active ones; SORTORDER 0 puts it last. A deployment *
      *   refuses the application until it has JCL (LWDM411)         *
      * U PUT /templates/{templateID}: name, order (0 keeps it) and   *
      *   highest RC                                                  *
      * D DELETE /templates/{templateID}: status D; the revisions     *
      *   stay                                                        *
      * C, U and D are for owners only (administrators too); a        *
      * deleted template can't be changed. MAXRC 0 to 4095.           *
      * The JCL itself: LWDM310 and LWDM410.                          *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Template not found, or no role in its application     *
      * 08 01 = Error: invalid OPCODE, or templateName empty          *
      * 08 02 = Error: maxRC or sortOrder out of range                *
      * 08 12/21/32 = Error: SQL error                                *
      * 08 31 = Error: update of a missing template                   *
      * 08 41 = Error: delete of a missing template                   *
      * 08 50 = Error: not an owner of the application                *
      * 08 53 = Error: a 21st template, or a deleted one changed      *
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
          05 C-MAXTPLS     PIC S9(4) COMP-5 VALUE 20.
          05 W-TEMPLATEID  PIC S9(9) COMP-5.
          05 W-COUNT       PIC S9(9) COMP-5.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM008.
           COPY LLWDM008.

       PROCEDURE DIVISION USING P-LLWDM008.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           EVALUATE OPCODE OF P-LLWDM008
           WHEN C-R
              PERFORM R150-TEMPLATE-APP
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R800-SELECT
           WHEN C-C
              MOVE APPID OF P-LLWDM008 TO W-APPID
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R106-REQUIRE-OWNER
              PERFORM R200-VALIDATE
              PERFORM R300-INSERT
              PERFORM R800-SELECT
           WHEN C-U
              PERFORM R150-TEMPLATE-APP
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R106-REQUIRE-OWNER
              PERFORM R160-REQUIRE-ACTIVE
              PERFORM R200-VALIDATE
              PERFORM R400-UPDATE
              PERFORM R800-SELECT
           WHEN C-D
              PERFORM R150-TEMPLATE-APP
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              PERFORM R106-REQUIRE-OWNER
              PERFORM R160-REQUIRE-ACTIVE
              PERFORM R500-DELETE
           WHEN OTHER
              IF RETURNCODE OF P-LLWDM008 = N'00'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM008
                 MOVE N'01' TO REASONCODE OF P-LLWDM008
                 MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM008
              END-IF
           END-EVALUATE

      *    Not the application: the template is what was asked for
           IF RETURNCODE OF P-LLWDM008 = N'04'
              MOVE N'Template not found' TO INFOMESSAGE OF P-LLWDM008
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM008
           MOVE N'00' TO REASONCODE OF P-LLWDM008
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM008

           MOVE TEMPLATEID OF P-LLWDM008 TO W-TEMPLATEID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-TEMPLATE-APP: W-APPID, name and status of the template;  *
      * not found is 04 01 (R), 08 41 (D) or 08 31 (U)                *
      *===============================================================*
       R150-TEMPLATE-APP SECTION.
           IF RETURNCODE OF P-LLWDM008 = N'00'
              EXEC SQL
                 SELECT APPID,
                        TEMPLATENAME,
                        TEMPLATESTATUS
                   INTO :W-APPID,
                        :DCLTBLWD008.TEMPLATENAME,
                        :DCLTBLWD008.TEMPLATESTATUS
                   FROM TBLWD008
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 EVALUATE OPCODE OF P-LLWDM008
                 WHEN C-R
                    MOVE N'04' TO RETURNCODE OF P-LLWDM008
                    MOVE N'01' TO REASONCODE OF P-LLWDM008
                 WHEN C-D
                    MOVE N'08' TO RETURNCODE OF P-LLWDM008
                    MOVE N'41' TO REASONCODE OF P-LLWDM008
                 WHEN OTHER
                    MOVE N'08' TO RETURNCODE OF P-LLWDM008
                    MOVE N'31' TO REASONCODE OF P-LLWDM008
                 END-EVALUATE
                 MOVE N'Template not found' TO INFOMESSAGE OF P-LLWDM008
              WHEN OTHER
                 MOVE N'SELECT template' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R150-TEMPLATE-APP-END.
           EXIT.

      *===============================================================*
      * R160-REQUIRE-ACTIVE: A deleted template isn't changed (08 53) *
      *===============================================================*
       R160-REQUIRE-ACTIVE SECTION.
           IF  RETURNCODE OF P-LLWDM008 = N'00'
           AND TEMPLATESTATUS OF DCLTBLWD008 NOT = C-A
              MOVE N'08' TO RETURNCODE OF P-LLWDM008
              MOVE N'53' TO REASONCODE OF P-LLWDM008
              STRING TEMPLATENAME-TEXT OF DCLTBLWD008(1:
                        TEMPLATENAME-LEN OF DCLTBLWD008)
                        DELIMITED BY SIZE
                     N' is deleted' DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM008
           END-IF
           .
       R160-REQUIRE-ACTIVE-END.
           EXIT.

      *===============================================================*
      * R200-VALIDATE: Name, highest RC and order of C and U          *
      *===============================================================*
       R200-VALIDATE SECTION.
           IF RETURNCODE OF P-LLWDM008 = N'00'
              EVALUATE TRUE
              WHEN TEMPLATENAME-LEN OF P-LLWDM008 < 1
              WHEN TEMPLATENAME-TEXT OF P-LLWDM008(1:TEMPLATENAME-LEN
                   OF P-LLWDM008) = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM008
                 MOVE N'01' TO REASONCODE OF P-LLWDM008
                 MOVE N'templateName is required' TO
                      INFOMESSAGE OF P-LLWDM008
              WHEN MAXRC OF P-LLWDM008 < 0
              WHEN MAXRC OF P-LLWDM008 > 4095
                 MOVE N'08' TO RETURNCODE OF P-LLWDM008
                 MOVE N'02' TO REASONCODE OF P-LLWDM008
                 MOVE N'maxRC: 0 to 4095' TO INFOMESSAGE OF P-LLWDM008
              WHEN SORTORDER OF P-LLWDM008 < 0
                 MOVE N'08' TO RETURNCODE OF P-LLWDM008
                 MOVE N'02' TO REASONCODE OF P-LLWDM008
                 MOVE N'sortOrder: 0 or more' TO
                      INFOMESSAGE OF P-LLWDM008
              END-EVALUATE
           END-IF
           .
       R200-VALIDATE-END.
           EXIT.

      *===============================================================*
      * R300-INSERT: The new template, without JCL, last when         *
      * SORTORDER is 0                                                *
      *===============================================================*
       R300-INSERT SECTION.
           IF RETURNCODE OF P-LLWDM008 = N'00'
              EXEC SQL
                 SELECT COUNT(*),
                        COALESCE(MAX(SORTORDER), 0)
                   INTO :W-COUNT,
                        :DCLTBLWD008.SORTORDER
                   FROM TBLWD008
                  WHERE APPID = :W-APPID
                    AND TEMPLATESTATUS = :C-A
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT templates' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM008 = N'00'
           AND W-COUNT >= C-MAXTPLS
              MOVE N'08' TO RETURNCODE OF P-LLWDM008
              MOVE N'53' TO REASONCODE OF P-LLWDM008
              MOVE N'20 templates is the most there can be' TO
                   INFOMESSAGE OF P-LLWDM008
           END-IF

           IF RETURNCODE OF P-LLWDM008 = N'00'
              IF SORTORDER OF P-LLWDM008 = 0
                 COMPUTE SORTORDER OF P-LLWDM008 =
                         SORTORDER OF DCLTBLWD008 + 1
              END-IF
              EXEC SQL
                 SELECT TEMPLATEID
                   INTO :W-TEMPLATEID
                   FROM FINAL TABLE
                        (INSERT INTO TBLWD008
                              ( APPID, TEMPLATENAME, SORTORDER, MAXRC,
                                CURRENTREV, TEMPLATESTATUS,
                                CREATEDBY, CREATEDDATE,
                                UPDATEDBY, UPDATEDDATE )
                         VALUES ( :W-APPID,
                                  :P-LLWDM008.TEMPLATENAME,
                                  :P-LLWDM008.SORTORDER,
                                  :P-LLWDM008.MAXRC,
                                  0, :C-A,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  :W-USERID, CURRENT TIMESTAMP ))
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT template' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R300-INSERT-END.
           EXIT.

      *===============================================================*
      * R400-UPDATE: Name, order (0 keeps it) and highest RC          *
      *===============================================================*
       R400-UPDATE SECTION.
           IF RETURNCODE OF P-LLWDM008 = N'00'
              EXEC SQL
                 UPDATE TBLWD008
                    SET TEMPLATENAME = :P-LLWDM008.TEMPLATENAME,
                        SORTORDER    = CASE WHEN :P-LLWDM008.SORTORDER
                                                 = 0
                                            THEN SORTORDER
                                            ELSE :P-LLWDM008.SORTORDER
                                       END,
                        MAXRC        = :P-LLWDM008.MAXRC,
                        UPDATEDBY    = :W-USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE template' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R400-UPDATE-END.
           EXIT.

      *===============================================================*
      * R500-DELETE: Status D; the revisions and lines stay           *
      *===============================================================*
       R500-DELETE SECTION.
           IF RETURNCODE OF P-LLWDM008 = N'00'
              EXEC SQL
                 UPDATE TBLWD008
                    SET TEMPLATESTATUS = :C-D,
                        UPDATEDBY      = :W-USERID,
                        UPDATEDDATE    = CURRENT TIMESTAMP
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'UPDATE template status' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R500-DELETE-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The template as the response                     *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM008 = N'00'
              EXEC SQL
                 SELECT TEMPLATEID,
                        APPID,
                        TEMPLATENAME,
                        SORTORDER,
                        MAXRC,
                        CURRENTREV,
                        TEMPLATESTATUS,
                        CREATEDBY,
                        CHAR(CREATEDDATE),
                        UPDATEDBY,
                        CHAR(UPDATEDDATE)
                   INTO :DCLTBLWD008.TEMPLATEID,
                        :DCLTBLWD008.APPID,
                        :DCLTBLWD008.TEMPLATENAME,
                        :DCLTBLWD008.SORTORDER,
                        :DCLTBLWD008.MAXRC,
                        :DCLTBLWD008.CURRENTREV,
                        :DCLTBLWD008.TEMPLATESTATUS,
                        :DCLTBLWD008.CREATEDBY,
                        :W-CREATED,
                        :DCLTBLWD008.UPDATEDBY,
                        :W-UPDATED
                   FROM TBLWD008
                  WHERE TEMPLATEID = :W-TEMPLATEID
              END-EXEC

              IF SQLCODE = 0
                 MOVE TEMPLATEID OF DCLTBLWD008 TO
                      TEMPLATEID OF P-LLWDM008
                 MOVE APPID OF DCLTBLWD008 TO APPID OF P-LLWDM008
                 MOVE TEMPLATENAME OF DCLTBLWD008 TO
                      TEMPLATENAME OF P-LLWDM008
                 MOVE SORTORDER OF DCLTBLWD008 TO
                      SORTORDER OF P-LLWDM008
                 MOVE MAXRC OF DCLTBLWD008 TO MAXRC OF P-LLWDM008
                 MOVE CURRENTREV OF DCLTBLWD008 TO
                      CURRENTREV OF P-LLWDM008
                 MOVE TEMPLATESTATUS OF DCLTBLWD008 TO
                      TEMPLATESTATUS OF P-LLWDM008
                 MOVE CREATEDBY OF DCLTBLWD008 TO
                      CREATEDBY OF P-LLWDM008
                 MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                      CREATEDDATE OF P-LLWDM008
                 MOVE UPDATEDBY OF DCLTBLWD008 TO
                      UPDATEDBY OF P-LLWDM008
                 MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                      UPDATEDDATE OF P-LLWDM008
              ELSE
                 MOVE N'SELECT template' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R800-SELECT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM008==.

       END PROGRAM LWDM008.
