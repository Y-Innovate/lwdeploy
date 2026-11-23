       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM006.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * One environment, by OPCODE (an LWW constant per path):        *
      * R GET /environments/{envID}: the environment with its         *
      *   controls (M2, O1, A2), for whoever may see its application. *
      *   CANDEPLOY and CANAPPROVE as LWDM206 works them out.         *
      * K PUT /admin/environmentControls/{envID} (A2), administrators *
      *   only: deploy userid (DEPLUSER allowlist), approval, approver*
      *   and deployer group (RACFGRP allowlist), number of approvals,*
      *   execution node. Approval Y needs an approver group and at   *
      *   least 1 approval; approval N stores 0 approvals. Deployments*
      *   already requested keep their own copy of the controls.      *
      * C POST /environments, U PUT and D DELETE /environments/{envID}*
      *   (O1), owners of the application only (administrators too).  *
      *   ENVCODE A-Z 0-9, unique within the application; ENVNAME     *
      *   required; PROMOGATE Y or N. C: at most 20 environments,     *
      *   SORTORDER 0 puts it last, and the protected defaults:       *
      *   approval Y with 1 approval, no approver group, no deploy    *
      *   userid, so it can't be deployed to before an administrator  *
      *   sets its controls. U: never the controls; SORTORDER 0 keeps *
      *   the order. D: only without deployments; its variables go    *
      *   with it.                                                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Environment not found, or no role in its application  *
      * 08 01 = Error: invalid OPCODE, or a required field is empty   *
      * 08 02 = Error: a field or control not valid, or not in its    *
      *         allowlist                                             *
      * 08 11 = Error: the application has this ENVCODE already       *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 31 = Error: update of a missing environment                *
      * 08 41 = Error: delete of a missing environment                *
      * 08 50 = Error: not an administrator (K), not an owner (C U D) *
      * 08 53 = Error: a 21st environment, or delete with deployments *
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

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 C-CODE        PIC N(36) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.
          05 C-MAXENVS     PIC S9(4) COMP-5 VALUE 20.
          05 W-COUNT       PIC S9(9) COMP-5.
          05 W-COUNT-ED    PIC Z(8)9.
          05 W-DESC-IND    PIC S9(4) COMP-5.
          05 C-FIRST       PIC N(29) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$@'.
          05 C-NAME        PIC N(39) VALUE
             N'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$@0123456789'.
          05 W-ENVID       PIC S9(9) COMP-5.
          05 W-I           PIC S9(4) COMP-5.
          05 W-T           PIC S9(4) COMP-5.
          05 W-END         PIC X.
          05 W-CH          PIC N.
          05 W-FLAG        PIC X.
          05 W-USER-IND    PIC S9(4) COMP-5.
          05 W-APRGRP-IND  PIC S9(4) COMP-5.
          05 W-DPLGRP-IND  PIC S9(4) COMP-5.
          05 W-NODE-IND    PIC S9(4) COMP-5.
          05 W-VNAME-IND   PIC S9(4) COMP-5.
          05 W-DEPLOYED    PIC X(26).
          05 W-DEPLOYED-IND PIC S9(4) COMP-5.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM006.
           COPY LLWDM006.

       PROCEDURE DIVISION USING P-LLWDM006.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LLWDM006 = N'00'
              EVALUATE OPCODE OF P-LLWDM006
              WHEN C-R
                 PERFORM R150-ENV-APP
                 PERFORM R100-APP-ROLES
                 PERFORM R105-REQUIRE-SEE
                 PERFORM R800-SELECT
              WHEN C-K
                 PERFORM R098-REQUIRE-ADMIN
                 PERFORM R150-ENV-APP
                 PERFORM R600-VALIDATE-CONTROLS
                 PERFORM R610-UPDATE-CONTROLS
                 PERFORM R100-APP-ROLES
                 PERFORM R800-SELECT
              WHEN C-C
                 MOVE APPID OF P-LLWDM006 TO W-APPID
                 PERFORM R100-APP-ROLES
                 PERFORM R105-REQUIRE-SEE
                 PERFORM R106-REQUIRE-OWNER
                 PERFORM R200-VALIDATE-ENV
                 PERFORM R300-INSERT-ENV
                 PERFORM R800-SELECT
              WHEN C-U
                 PERFORM R150-ENV-APP
                 PERFORM R100-APP-ROLES
                 PERFORM R105-REQUIRE-SEE
                 PERFORM R106-REQUIRE-OWNER
                 PERFORM R200-VALIDATE-ENV
                 PERFORM R400-UPDATE-ENV
                 PERFORM R800-SELECT
              WHEN C-D
                 PERFORM R150-ENV-APP
                 PERFORM R100-APP-ROLES
                 PERFORM R105-REQUIRE-SEE
                 PERFORM R106-REQUIRE-OWNER
                 PERFORM R500-DELETE-ENV
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LLWDM006
                 MOVE N'01' TO REASONCODE OF P-LLWDM006
                 MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM006
              END-EVALUATE
           END-IF

      *    Not the application: the environment is what was asked for
           IF  RETURNCODE OF P-LLWDM006 = N'04'
              MOVE N'Environment not found' TO
                   INFOMESSAGE OF P-LLWDM006
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM006
           MOVE N'00' TO REASONCODE OF P-LLWDM006
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM006

           MOVE ENVID OF P-LLWDM006 TO W-ENVID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R150-ENV-APP: W-APPID of environment W-ENVID; not found is    *
      * 04 01 for R, 08 41 for D and 08 31 for K and U                *
      *===============================================================*
       R150-ENV-APP SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 SELECT APPID
                   INTO :W-APPID
                   FROM TBLWD006
                  WHERE ENVID = :W-ENVID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 EVALUATE OPCODE OF P-LLWDM006
                 WHEN C-R
                    MOVE N'04' TO RETURNCODE OF P-LLWDM006
                    MOVE N'01' TO REASONCODE OF P-LLWDM006
                 WHEN C-D
                    MOVE N'08' TO RETURNCODE OF P-LLWDM006
                    MOVE N'41' TO REASONCODE OF P-LLWDM006
                 WHEN OTHER
                    MOVE N'08' TO RETURNCODE OF P-LLWDM006
                    MOVE N'31' TO REASONCODE OF P-LLWDM006
                 END-EVALUATE
                 MOVE N'Environment not found' TO
                      INFOMESSAGE OF P-LLWDM006
              WHEN OTHER
                 MOVE N'SELECT environment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R150-ENV-APP-END.
           EXIT.

      *===============================================================*
      * R200-VALIDATE-ENV: Code, name and gate of C and U             *
      *===============================================================*
       R200-VALIDATE-ENV SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
      *       A missing optional field arrives as binary zeros
              IF ENVCODE OF P-LLWDM006(1:1) = NX'0000'
                 MOVE SPACES TO ENVCODE OF P-LLWDM006
              END-IF
              IF PROMOGATE OF P-LLWDM006 = NX'0000'
              OR PROMOGATE OF P-LLWDM006 = SPACE
                 MOVE C-N TO PROMOGATE OF P-LLWDM006
              END-IF
              MOVE FUNCTION UPPER-CASE(ENVCODE OF P-LLWDM006) TO
                   ENVCODE OF P-LLWDM006
              MOVE FUNCTION UPPER-CASE(PROMOGATE OF P-LLWDM006) TO
                   PROMOGATE OF P-LLWDM006
              EVALUATE TRUE
              WHEN ENVCODE OF P-LLWDM006 = SPACES
                 MOVE N'envCode is required' TO
                      INFOMESSAGE OF P-LLWDM006
              WHEN ENVNAME-LEN OF P-LLWDM006 < 1
              WHEN ENVNAME-TEXT OF P-LLWDM006(1:ENVNAME-LEN OF
                   P-LLWDM006) = SPACES
                 MOVE N'envName is required' TO
                      INFOMESSAGE OF P-LLWDM006
              END-EVALUATE
              IF INFOMESSAGE OF P-LLWDM006 NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM006
                 MOVE N'01' TO REASONCODE OF P-LLWDM006
              END-IF
           END-IF

      *    A-Z 0-9 up to the first blank, and only blanks after it
           IF RETURNCODE OF P-LLWDM006 = N'00'
              MOVE 'N' TO W-END
              PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > 8
                 MOVE ENVCODE OF P-LLWDM006(W-I:1) TO W-CH
                 IF W-CH = SPACE
                    MOVE 'Y' TO W-END
                 ELSE
                    MOVE 0 TO W-T
                    INSPECT C-CODE TALLYING W-T FOR ALL W-CH
                    IF W-T = 0 OR W-END = 'Y'
                       MOVE N'08' TO RETURNCODE OF P-LLWDM006
                       MOVE N'02' TO REASONCODE OF P-LLWDM006
                       MOVE N'envCode: A-Z and 0-9 only, at most 8' TO
                            INFOMESSAGE OF P-LLWDM006
                    END-IF
                 END-IF
              END-PERFORM
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND PROMOGATE OF P-LLWDM006 NOT = C-Y
           AND PROMOGATE OF P-LLWDM006 NOT = C-N
              MOVE N'08' TO RETURNCODE OF P-LLWDM006
              MOVE N'02' TO REASONCODE OF P-LLWDM006
              MOVE N'promoGate: Y or N' TO INFOMESSAGE OF P-LLWDM006
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND SORTORDER OF P-LLWDM006 < 0
              MOVE N'08' TO RETURNCODE OF P-LLWDM006
              MOVE N'02' TO REASONCODE OF P-LLWDM006
              MOVE N'sortOrder: 0 or more' TO INFOMESSAGE OF P-LLWDM006
           END-IF

           IF RETURNCODE OF P-LLWDM006 = N'00'
              IF ENVDESCRIPTION-LEN OF P-LLWDM006 > 0
                 MOVE 0 TO W-DESC-IND
              ELSE
                 MOVE -1 TO W-DESC-IND
                 MOVE 0 TO ENVDESCRIPTION-LEN OF P-LLWDM006
              END-IF
           END-IF
           .
       R200-VALIDATE-ENV-END.
           EXIT.

      *===============================================================*
      * R300-INSERT-ENV: The new environment, last when SORTORDER is  *
      * 0, with the protected defaults                                *
      *===============================================================*
       R300-INSERT-ENV SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 SELECT COUNT(*),
                        COALESCE(MAX(SORTORDER), 0)
                   INTO :W-COUNT,
                        :DCLTBLWD006.SORTORDER
                   FROM TBLWD006
                  WHERE APPID = :W-APPID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT environments' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND W-COUNT >= C-MAXENVS
              MOVE N'08' TO RETURNCODE OF P-LLWDM006
              MOVE N'53' TO REASONCODE OF P-LLWDM006
              MOVE N'20 environments is the most there can be' TO
                   INFOMESSAGE OF P-LLWDM006
           END-IF

           IF RETURNCODE OF P-LLWDM006 = N'00'
              IF SORTORDER OF P-LLWDM006 = 0
                 COMPUTE SORTORDER OF P-LLWDM006 =
                         SORTORDER OF DCLTBLWD006 + 1
              END-IF
              EXEC SQL
                 SELECT ENVID
                   INTO :W-ENVID
                   FROM FINAL TABLE
                        (INSERT INTO TBLWD006
                              ( APPID, ENVCODE, ENVNAME, DESCRIPTION,
                                SORTORDER, PROMOGATE, DEPLOYUSER,
                                APPROVALREQ, APPROVERGROUP,
                                APPROVALCOUNT, DEPLOYERGROUP,
                                ACTIVEDEPLID, CURRENTDEPLID,
                                CURRENTVERSIONID, ENVSTATE,
                                CREATEDBY, CREATEDDATE,
                                UPDATEDBY, UPDATEDDATE, EXECNODE )
                         VALUES ( :W-APPID,
                                  :P-LLWDM006.ENVCODE,
                                  :P-LLWDM006.ENVNAME,
                                  :P-LLWDM006.ENVDESCRIPTION
                                     :W-DESC-IND,
                                  :P-LLWDM006.SORTORDER,
                                  :P-LLWDM006.PROMOGATE,
                                  NULL, :C-Y, NULL, 1, NULL,
                                  NULL, NULL, NULL, :C-N,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  NULL ))
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 PERFORM R310-TAKEN
              WHEN OTHER
                 MOVE N'INSERT environment' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R300-INSERT-ENV-END.
           EXIT.

      *===============================================================*
      * R310-TAKEN: 08 11, another environment has the code           *
      *===============================================================*
       R310-TAKEN SECTION.
           MOVE N'08' TO RETURNCODE OF P-LLWDM006
           MOVE N'11' TO REASONCODE OF P-LLWDM006
           STRING N'The application has an environment '
                     DELIMITED BY SIZE
                  ENVCODE OF P-LLWDM006 DELIMITED BY N' '
                  N' already' DELIMITED BY SIZE
             INTO INFOMESSAGE OF P-LLWDM006
           .
       R310-TAKEN-END.
           EXIT.

      *===============================================================*
      * R400-UPDATE-ENV: Code, name, description, order and gate      *
      *===============================================================*
       R400-UPDATE-ENV SECTION.
           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND SORTORDER OF P-LLWDM006 = 0
              EXEC SQL
                 SELECT SORTORDER
                   INTO :P-LLWDM006.SORTORDER
                   FROM TBLWD006
                  WHERE ENVID = :W-ENVID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT environment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 UPDATE TBLWD006
                    SET ENVCODE     = :P-LLWDM006.ENVCODE,
                        ENVNAME     = :P-LLWDM006.ENVNAME,
                        DESCRIPTION = :P-LLWDM006.ENVDESCRIPTION
                                         :W-DESC-IND,
                        SORTORDER   = :P-LLWDM006.SORTORDER,
                        PROMOGATE   = :P-LLWDM006.PROMOGATE,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE ENVID = :W-ENVID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -803
                 PERFORM R310-TAKEN
              WHEN OTHER
                 MOVE N'UPDATE environment' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R400-UPDATE-ENV-END.
           EXIT.

      *===============================================================*
      * R500-DELETE-ENV: Refused with deployments; otherwise its      *
      * variables, then the environment                               *
      *===============================================================*
       R500-DELETE-ENV SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 SELECT COUNT(*)
                   INTO :W-COUNT
                   FROM TBLWD011
                  WHERE ENVID = :W-ENVID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT deployments' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND W-COUNT > 0
              MOVE W-COUNT TO W-COUNT-ED
              MOVE N'08' TO RETURNCODE OF P-LLWDM006
              MOVE N'53' TO REASONCODE OF P-LLWDM006
              STRING N'The environment has ' DELIMITED BY SIZE
                     FUNCTION NATIONAL-OF(FUNCTION TRIM(W-COUNT-ED))
                        DELIMITED BY SIZE
                     N' deployments: it can''t be deleted'
                        DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM006
           END-IF

           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD007
                  WHERE ENVID = :W-ENVID
              END-EXEC
              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'DELETE variables' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 DELETE FROM TBLWD006
                  WHERE ENVID = :W-ENVID
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'DELETE environment' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R500-DELETE-ENV-END.
           EXIT.

      *===============================================================*
      * R600-VALIDATE-CONTROLS: The controls of A2 and their          *
      * indicators: an empty field is NULL                            *
      *===============================================================*
       R600-VALIDATE-CONTROLS SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
      *       A missing optional field arrives as binary zeros
              IF DEPLOYUSER OF P-LLWDM006(1:1) = NX'0000'
                 MOVE SPACES TO DEPLOYUSER OF P-LLWDM006
              END-IF
              IF APPROVALREQ OF P-LLWDM006 = NX'0000'
                 MOVE C-N TO APPROVALREQ OF P-LLWDM006
              END-IF
              IF APPROVERGROUP OF P-LLWDM006(1:1) = NX'0000'
                 MOVE SPACES TO APPROVERGROUP OF P-LLWDM006
              END-IF
              IF DEPLOYERGROUP OF P-LLWDM006(1:1) = NX'0000'
                 MOVE SPACES TO DEPLOYERGROUP OF P-LLWDM006
              END-IF
              IF EXECNODE OF P-LLWDM006(1:1) = NX'0000'
                 MOVE SPACES TO EXECNODE OF P-LLWDM006
              END-IF
              MOVE FUNCTION UPPER-CASE(DEPLOYUSER OF P-LLWDM006) TO
                   DEPLOYUSER OF P-LLWDM006
              MOVE FUNCTION UPPER-CASE(APPROVALREQ OF P-LLWDM006) TO
                   APPROVALREQ OF P-LLWDM006
              MOVE FUNCTION UPPER-CASE(APPROVERGROUP OF P-LLWDM006)
                TO APPROVERGROUP OF P-LLWDM006
              MOVE FUNCTION UPPER-CASE(DEPLOYERGROUP OF P-LLWDM006)
                TO DEPLOYERGROUP OF P-LLWDM006
              MOVE FUNCTION UPPER-CASE(EXECNODE OF P-LLWDM006) TO
                   EXECNODE OF P-LLWDM006

              IF  APPROVALREQ OF P-LLWDM006 NOT = C-Y
              AND APPROVALREQ OF P-LLWDM006 NOT = C-N
                 MOVE N'08' TO RETURNCODE OF P-LLWDM006
                 MOVE N'02' TO REASONCODE OF P-LLWDM006
                 MOVE N'approvalReq: Y or N' TO
                      INFOMESSAGE OF P-LLWDM006
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND DEPLOYUSER OF P-LLWDM006 NOT = SPACES
              MOVE C-DEPLUSER TO W-LIST-TABLE
              MOVE DEPLOYUSER OF P-LLWDM006 TO W-LIST-KEY
              PERFORM R099-IN-LIST
              IF  RETURNCODE OF P-LLWDM006 = N'00'
              AND W-IN-LIST NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM006
                 MOVE N'02' TO REASONCODE OF P-LLWDM006
                 STRING W-LIST-KEY DELIMITED BY N' '
                        N' is not in the allowlist of deploy userids'
                           DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM006
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND APPROVERGROUP OF P-LLWDM006 NOT = SPACES
              MOVE APPROVERGROUP OF P-LLWDM006 TO W-LIST-KEY
              PERFORM R620-GROUP-IN-LIST
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND DEPLOYERGROUP OF P-LLWDM006 NOT = SPACES
              MOVE DEPLOYERGROUP OF P-LLWDM006 TO W-LIST-KEY
              PERFORM R620-GROUP-IN-LIST
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND APPROVALREQ OF P-LLWDM006 = C-Y
              EVALUATE TRUE
              WHEN APPROVERGROUP OF P-LLWDM006 = SPACES
                 MOVE N'Approval needs an approver group' TO
                      INFOMESSAGE OF P-LLWDM006
              WHEN APPROVALCOUNT OF P-LLWDM006 < 1
                 MOVE N'Approval needs at least 1 approval' TO
                      INFOMESSAGE OF P-LLWDM006
              END-EVALUATE
              IF INFOMESSAGE OF P-LLWDM006 NOT = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LLWDM006
                 MOVE N'02' TO REASONCODE OF P-LLWDM006
              END-IF
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND APPROVALREQ OF P-LLWDM006 = C-N
              MOVE 0 TO APPROVALCOUNT OF P-LLWDM006
           END-IF

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND EXECNODE OF P-LLWDM006 NOT = SPACES
              PERFORM R630-CHECK-NODE
           END-IF

           IF RETURNCODE OF P-LLWDM006 = N'00'
              MOVE 0 TO W-USER-IND W-APRGRP-IND W-DPLGRP-IND
                        W-NODE-IND
              IF DEPLOYUSER OF P-LLWDM006 = SPACES
                 MOVE -1 TO W-USER-IND
              END-IF
              IF APPROVERGROUP OF P-LLWDM006 = SPACES
                 MOVE -1 TO W-APRGRP-IND
              END-IF
              IF DEPLOYERGROUP OF P-LLWDM006 = SPACES
                 MOVE -1 TO W-DPLGRP-IND
              END-IF
              IF EXECNODE OF P-LLWDM006 = SPACES
                 MOVE -1 TO W-NODE-IND
              END-IF
           END-IF
           .
       R600-VALIDATE-CONTROLS-END.
           EXIT.

      *===============================================================*
      * R610-UPDATE-CONTROLS: Only the controls; name, order and gate *
      * are the owners'                                               *
      *===============================================================*
       R610-UPDATE-CONTROLS SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 UPDATE TBLWD006
                    SET DEPLOYUSER    = :P-LLWDM006.DEPLOYUSER
                                           :W-USER-IND,
                        APPROVALREQ   = :P-LLWDM006.APPROVALREQ,
                        APPROVERGROUP = :P-LLWDM006.APPROVERGROUP
                                           :W-APRGRP-IND,
                        APPROVALCOUNT = :P-LLWDM006.APPROVALCOUNT,
                        DEPLOYERGROUP = :P-LLWDM006.DEPLOYERGROUP
                                           :W-DPLGRP-IND,
                        EXECNODE      = :P-LLWDM006.EXECNODE
                                           :W-NODE-IND,
                        UPDATEDBY     = :W-USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE ENVID = :W-ENVID
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'UPDATE environment controls' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R610-UPDATE-CONTROLS-END.
           EXIT.

      *===============================================================*
      * R620-GROUP-IN-LIST: 08 02 when W-LIST-KEY isn't in RACFGRP    *
      *===============================================================*
       R620-GROUP-IN-LIST SECTION.
           MOVE C-RACFGRP TO W-LIST-TABLE
           PERFORM R099-IN-LIST

           IF  RETURNCODE OF P-LLWDM006 = N'00'
           AND W-IN-LIST NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LLWDM006
              MOVE N'02' TO REASONCODE OF P-LLWDM006
              STRING W-LIST-KEY DELIMITED BY N' '
                     N' is not in the allowlist of RACF groups'
                        DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM006
           END-IF
           .
       R620-GROUP-IN-LIST-END.
           EXIT.

      *===============================================================*
      * R630-CHECK-NODE: A JES2 node name: A-Z # $ @ first, then also *
      * 0-9, no blank inside                                          *
      *===============================================================*
       R630-CHECK-NODE SECTION.
           MOVE 'N' TO W-END
           PERFORM VARYING W-I FROM 1 BY 1 UNTIL W-I > 8
              MOVE EXECNODE OF P-LLWDM006(W-I:1) TO W-CH
              IF W-CH = SPACE
                 MOVE 'Y' TO W-END
              ELSE
                 MOVE 0 TO W-T
                 IF W-I = 1
                    INSPECT C-FIRST TALLYING W-T FOR ALL W-CH
                 ELSE
                    INSPECT C-NAME TALLYING W-T FOR ALL W-CH
                 END-IF
                 IF W-T = 0 OR W-END = 'Y'
                    MOVE N'08' TO RETURNCODE OF P-LLWDM006
                    MOVE N'02' TO REASONCODE OF P-LLWDM006
                    MOVE N'execNode: a JES2 node name of 1 to 8'
                      TO INFOMESSAGE OF P-LLWDM006
                 END-IF
              END-IF
           END-PERFORM
           .
       R630-CHECK-NODE-END.
           EXIT.

      *===============================================================*
      * R800-SELECT: The environment as the response                  *
      *===============================================================*
       R800-SELECT SECTION.
           IF RETURNCODE OF P-LLWDM006 = N'00'
              EXEC SQL
                 SELECT E.ENVID,
                        E.APPID,
                        E.ENVCODE,
                        E.ENVNAME,
                        E.DESCRIPTION,
                        E.SORTORDER,
                        E.PROMOGATE,
                        E.DEPLOYUSER,
                        E.APPROVALREQ,
                        E.APPROVERGROUP,
                        E.APPROVALCOUNT,
                        E.DEPLOYERGROUP,
                        E.EXECNODE,
                        E.ENVSTATE,
                        COALESCE(E.CURRENTVERSIONID, 0),
                        V.VERSIONNAME,
                        COALESCE(E.CURRENTDEPLID, 0),
                        CHAR(D.ENDEDDATE),
                        COALESCE(E.ACTIVEDEPLID, 0),
                        E.CREATEDBY,
                        CHAR(E.CREATEDDATE),
                        E.UPDATEDBY,
                        CHAR(E.UPDATEDDATE)
                   INTO :DCLTBLWD006.ENVID,
                        :DCLTBLWD006.APPID,
                        :DCLTBLWD006.ENVCODE,
                        :DCLTBLWD006.ENVNAME,
                        :DCLTBLWD006.DESCRIPTION
                           :DCLTBLWD006.DESCRIPTION-IND,
                        :DCLTBLWD006.SORTORDER,
                        :DCLTBLWD006.PROMOGATE,
                        :DCLTBLWD006.DEPLOYUSER
                           :DCLTBLWD006.DEPLOYUSER-IND,
                        :DCLTBLWD006.APPROVALREQ,
                        :DCLTBLWD006.APPROVERGROUP
                           :DCLTBLWD006.APPROVERGROUP-IND,
                        :DCLTBLWD006.APPROVALCOUNT,
                        :DCLTBLWD006.DEPLOYERGROUP
                           :DCLTBLWD006.DEPLOYERGROUP-IND,
                        :DCLTBLWD006.EXECNODE
                           :DCLTBLWD006.EXECNODE-IND,
                        :DCLTBLWD006.ENVSTATE,
                        :DCLTBLWD006.CURRENTVERSIONID,
                        :DCLTBLWD005.VERSIONNAME :W-VNAME-IND,
                        :DCLTBLWD006.CURRENTDEPLID,
                        :W-DEPLOYED :W-DEPLOYED-IND,
                        :DCLTBLWD006.ACTIVEDEPLID,
                        :DCLTBLWD006.CREATEDBY,
                        :W-CREATED,
                        :DCLTBLWD006.UPDATEDBY,
                        :W-UPDATED
                   FROM TBLWD006 E
                   LEFT JOIN TBLWD005 V
                     ON V.VERSIONID = E.CURRENTVERSIONID
                   LEFT JOIN TBLWD011 D
                     ON D.DEPLID = E.CURRENTDEPLID
                  WHERE E.ENVID = :W-ENVID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R810-COPY
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM006
                 MOVE N'01' TO REASONCODE OF P-LLWDM006
              WHEN OTHER
                 MOVE N'SELECT environment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R800-SELECT-END.
           EXIT.

      *===============================================================*
      * R810-COPY: Copy the environment and work out the flags for    *
      * the UI, as LWDM206 R220-COPY does                             *
      *===============================================================*
       R810-COPY SECTION.
           MOVE ENVID OF DCLTBLWD006 TO ENVID OF P-LLWDM006
           MOVE APPID OF DCLTBLWD006 TO APPID OF P-LLWDM006
           MOVE ENVCODE OF DCLTBLWD006 TO ENVCODE OF P-LLWDM006
           MOVE ENVNAME OF DCLTBLWD006 TO ENVNAME OF P-LLWDM006
           IF DESCRIPTION-IND OF DCLTBLWD006 >= 0
              MOVE DESCRIPTION OF DCLTBLWD006 TO
                   ENVDESCRIPTION OF P-LLWDM006
           ELSE
              MOVE 0 TO ENVDESCRIPTION-LEN OF P-LLWDM006
           END-IF
           MOVE SORTORDER OF DCLTBLWD006 TO SORTORDER OF P-LLWDM006
           MOVE PROMOGATE OF DCLTBLWD006 TO PROMOGATE OF P-LLWDM006
           MOVE SPACES TO DEPLOYUSER OF P-LLWDM006
           IF DEPLOYUSER-IND OF DCLTBLWD006 >= 0
              MOVE DEPLOYUSER OF DCLTBLWD006 TO
                   DEPLOYUSER OF P-LLWDM006
           END-IF
           MOVE APPROVALREQ OF DCLTBLWD006 TO
                APPROVALREQ OF P-LLWDM006
           MOVE SPACES TO APPROVERGROUP OF P-LLWDM006
           IF APPROVERGROUP-IND OF DCLTBLWD006 >= 0
              MOVE APPROVERGROUP OF DCLTBLWD006 TO
                   APPROVERGROUP OF P-LLWDM006
           END-IF
           MOVE APPROVALCOUNT OF DCLTBLWD006 TO
                APPROVALCOUNT OF P-LLWDM006
           MOVE SPACES TO DEPLOYERGROUP OF P-LLWDM006
           IF DEPLOYERGROUP-IND OF DCLTBLWD006 >= 0
              MOVE DEPLOYERGROUP OF DCLTBLWD006 TO
                   DEPLOYERGROUP OF P-LLWDM006
           END-IF
           MOVE SPACES TO EXECNODE OF P-LLWDM006
           IF EXECNODE-IND OF DCLTBLWD006 >= 0
              MOVE EXECNODE OF DCLTBLWD006 TO EXECNODE OF P-LLWDM006
           END-IF
           MOVE ENVSTATE OF DCLTBLWD006 TO ENVSTATE OF P-LLWDM006
           MOVE CURRENTVERSIONID OF DCLTBLWD006 TO
                CURRENTVERSIONID OF P-LLWDM006
           IF W-VNAME-IND >= 0
              MOVE VERSIONNAME OF DCLTBLWD005 TO
                   CURRENTVERSIONNAME OF P-LLWDM006
           ELSE
              MOVE 0 TO CURRENTVERSIONNAME-LEN OF P-LLWDM006
           END-IF
           MOVE CURRENTDEPLID OF DCLTBLWD006 TO
                CURRENTDEPLID OF P-LLWDM006
           IF W-DEPLOYED-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-DEPLOYED) TO
                   DEPLOYEDDATE OF P-LLWDM006
           ELSE
              MOVE SPACES TO DEPLOYEDDATE OF P-LLWDM006
           END-IF
           MOVE ACTIVEDEPLID OF DCLTBLWD006 TO
                ACTIVEDEPLID OF P-LLWDM006
           MOVE CREATEDBY OF DCLTBLWD006 TO CREATEDBY OF P-LLWDM006
           MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                CREATEDDATE OF P-LLWDM006
           MOVE UPDATEDBY OF DCLTBLWD006 TO UPDATEDBY OF P-LLWDM006
           MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                UPDATEDDATE OF P-LLWDM006

      *    Can deploy: member, deploy userid set, deployer group if any
           MOVE 'N' TO W-FLAG
           IF  W-IS-MEMBER = 'Y'
           AND DEPLOYUSER-IND OF DCLTBLWD006 >= 0
              IF DEPLOYERGROUP-IND OF DCLTBLWD006 < 0
                 MOVE 'Y' TO W-FLAG
              ELSE
                 MOVE DEPLOYERGROUP OF DCLTBLWD006 TO W-GROUP
                 PERFORM R096-CHECK-GROUP
                 MOVE W-IN-GROUP TO W-FLAG
              END-IF
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-FLAG) TO CANDEPLOY OF P-LLWDM006

      *    Can approve: approval required and in the approver group
           MOVE 'N' TO W-FLAG
           IF  APPROVALREQ OF DCLTBLWD006 = C-Y
           AND APPROVERGROUP-IND OF DCLTBLWD006 >= 0
              MOVE APPROVERGROUP OF DCLTBLWD006 TO W-GROUP
              PERFORM R096-CHECK-GROUP
              MOVE W-IN-GROUP TO W-FLAG
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-FLAG) TO
                CANAPPROVE OF P-LLWDM006
           .
       R810-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM006==.

       END PROGRAM LWDM006.
