      *===============================================================*
      * LWDCTXP: User context for the DB2 modules. Copy with          *
      *    COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDMnnn==.         *
      * Needs LWDCTXW. Every section does nothing when RETURNCODE is  *
      * not 00 already, so they can be performed one after the other. *
      * Whether a userid is in a group is decided by RACF: READ on    *
      * FACILITY <GRPPRFX>.<group> (M7), checked live with LWDA992.   *
      * USERGROUPS only caches that for lists (docs/03-data-model.md).*
      * Codes set here:                                               *
      * 04 01 = Application not found, or no role in it (R105)        *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 42 = Error: SQL error in DELETE                            *
      * 08 90 = Error: LWDA990, LWDA992 or a setting failed           *
      *===============================================================*

      *===============================================================*
      * R090-GET-USERID: The CICS userid of the user                  *
      *===============================================================*
       R090-GET-USERID SECTION.
           IF RETURNCODE OF :IO: = N'00'
              CALL W-CTX-PGM USING W-LLWDA990

              IF RETURNCODE OF W-LLWDA990 NOT = N'00'
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'90' TO REASONCODE OF :IO:
                 MOVE INFOMESSAGE OF W-LLWDA990 TO
                      INFOMESSAGE OF :IO:
              ELSE
                 MOVE USERID OF W-LLWDA990 TO W-USERID
              END-IF
           END-IF
           .
       R090-GET-USERID-END.
           EXIT.

      *===============================================================*
      * R091-GET-SETTING: W-SETVALUE of setting W-SETKEY              *
      *===============================================================*
       R091-GET-SETTING SECTION.
           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT TABVALUE
                   INTO :W-SETVALUE
                   FROM TBLWD001
                  WHERE TABLEID = :C-SETTINGS
                    AND TABKEY = :W-SETKEY
                    AND TABVALUE IS NOT NULL
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'90' TO REASONCODE OF :IO:
                 STRING N'Setting ' W-SETKEY N' is missing'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF :IO:
              WHEN OTHER
                 MOVE N'SELECT setting' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R091-GET-SETTING-END.
           EXIT.

      *===============================================================*
      * R092-SECURITY-SETTINGS: GRPPRFX, ADMINRES and GRPMINS, once   *
      *===============================================================*
       R092-SECURITY-SETTINGS SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-SEC-LOADED = 'N'
              MOVE C-GRPPRFX TO W-SETKEY
              PERFORM R091-GET-SETTING
              IF RETURNCODE OF :IO: = N'00'
                 MOVE SPACES TO W-GRPPRFX
                 COMPUTE W-GRPPRFX-LEN =
                         FUNCTION MIN(W-SETVALUE-LEN, 30)
                 MOVE W-SETVALUE-TEXT(1:W-GRPPRFX-LEN) TO W-GRPPRFX
              END-IF

              MOVE C-ADMINRES TO W-SETKEY
              PERFORM R091-GET-SETTING
              IF RETURNCODE OF :IO: = N'00'
                 MOVE SPACES TO W-ADMINRES
                 COMPUTE W-ADMINRES-LEN =
                         FUNCTION MIN(W-SETVALUE-LEN, 44)
                 MOVE W-SETVALUE-TEXT(1:W-ADMINRES-LEN) TO W-ADMINRES
              END-IF

              MOVE C-GRPMINS TO W-SETKEY
              PERFORM R091-GET-SETTING
              IF RETURNCODE OF :IO: = N'00'
                 COMPUTE W-GRPMINS = FUNCTION NUMVAL(FUNCTION
                    DISPLAY-OF(W-SETVALUE-TEXT(1:W-SETVALUE-LEN)))
                 MOVE 'Y' TO W-SEC-LOADED
              END-IF
           END-IF
           .
       R092-SECURITY-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R095-CHECK-ADMIN: W-IS-ADMIN = Y with READ on ADMINRES        *
      *===============================================================*
       R095-CHECK-ADMIN SECTION.
           MOVE 'N' TO W-IS-ADMIN
           PERFORM R092-SECURITY-SETTINGS

           IF RETURNCODE OF :IO: = N'00'
              MOVE W-ADMINRES TO W-RES-NAT
              MOVE W-ADMINRES-LEN TO W-RES-LEN
              PERFORM R097-CHECK-RESOURCE
              MOVE W-RES-READ TO W-IS-ADMIN
           END-IF
           .
       R095-CHECK-ADMIN-END.
           EXIT.

      *===============================================================*
      * R098-REQUIRE-ADMIN: 08 50 unless the user is an administrator *
      * (docs/10-iteration-6.md: every /admin module)                 *
      *===============================================================*
       R098-REQUIRE-ADMIN SECTION.
           PERFORM R095-CHECK-ADMIN

           IF  RETURNCODE OF :IO: = N'00'
           AND W-IS-ADMIN NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'50' TO REASONCODE OF :IO:
              MOVE N'Only an administrator may do this' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R098-REQUIRE-ADMIN-END.
           EXIT.

      *===============================================================*
      * R099-IN-LIST: W-IN-LIST = Y when W-LIST-KEY is an entry of    *
      * reference table W-LIST-TABLE (RACFGRP, DEPLUSER)              *
      *===============================================================*
       R099-IN-LIST SECTION.
           MOVE 'N' TO W-IN-LIST

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT 'Y'
                   INTO :W-IN-LIST
                   FROM TBLWD001
                  WHERE TABLEID = :W-LIST-TABLE
                    AND TABKEY = :W-LIST-KEY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE 'N' TO W-IN-LIST
              WHEN OTHER
                 MOVE N'SELECT allowlist' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R099-IN-LIST-END.
           EXIT.

      *===============================================================*
      * R096-CHECK-GROUP: W-IN-GROUP = Y with READ on the FACILITY    *
      * profile of group W-GROUP. An empty group is nobody's.         *
      *===============================================================*
       R096-CHECK-GROUP SECTION.
           MOVE 'N' TO W-IN-GROUP
           PERFORM R092-SECURITY-SETTINGS

           IF  RETURNCODE OF :IO: = N'00'
           AND W-GROUP NOT = SPACES
              MOVE SPACES TO W-RES-NAT
              MOVE 1 TO W-RES-PTR
              STRING W-GRPPRFX(1:W-GRPPRFX-LEN) DELIMITED BY SIZE
                     N'.' DELIMITED BY SIZE
                     W-GROUP DELIMITED BY N' '
                INTO W-RES-NAT
                WITH POINTER W-RES-PTR
              COMPUTE W-RES-LEN = W-RES-PTR - 1
              PERFORM R097-CHECK-RESOURCE
              MOVE W-RES-READ TO W-IN-GROUP
           END-IF
           .
       R096-CHECK-GROUP-END.
           EXIT.

      *===============================================================*
      * R097-CHECK-RESOURCE: W-RES-READ = Y with READ on FACILITY     *
      * W-RES-NAT(1:W-RES-LEN)                                        *
      *===============================================================*
       R097-CHECK-RESOURCE SECTION.
           MOVE 'N' TO W-RES-READ
           MOVE 'FACILITY' TO RESCLASS OF W-LLWDA992
           MOVE SPACES TO RESID OF W-LLWDA992
           MOVE FUNCTION DISPLAY-OF(W-RES-NAT(1:W-RES-LEN))
             TO RESID OF W-LLWDA992
           MOVE W-RES-LEN TO RESIDLEN OF W-LLWDA992

           CALL W-SEC-PGM USING W-LLWDA992

           IF RETURNCODE OF W-LLWDA992 NOT = N'00'
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'90' TO REASONCODE OF :IO:
              MOVE INFOMESSAGE OF W-LLWDA992 TO INFOMESSAGE OF :IO:
           ELSE
              IF CAN-READ OF W-LLWDA992
                 MOVE 'Y' TO W-RES-READ
              END-IF
           END-IF
           .
       R097-CHECK-RESOURCE-END.
           EXIT.

      *===============================================================*
      * R100-APP-ROLES: The roles of the user in application W-APPID. *
      * W-APP-FOUND, W-IS-MEMBER, W-IS-OWNER, W-IS-APPROVER (of any   *
      * environment), W-IS-ADMIN, and W-CAN-SEE when any of these.    *
      *===============================================================*
       R100-APP-ROLES SECTION.
           MOVE 'N' TO W-APP-FOUND
           MOVE 'N' TO W-IS-MEMBER
           MOVE 'N' TO W-IS-OWNER
           MOVE 'N' TO W-IS-APPROVER
           MOVE 'N' TO W-CAN-SEE

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT ACCESSGROUP,
                        OWNERGROUP
                   INTO :W-ACCESSGROUP,
                        :W-OWNERGROUP
                   FROM TBLWD004
                  WHERE APPID = :W-APPID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE 'Y' TO W-APP-FOUND
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE N'SELECT application' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND W-APP-FOUND = 'Y'
              MOVE W-ACCESSGROUP TO W-GROUP
              PERFORM R096-CHECK-GROUP
              MOVE W-IN-GROUP TO W-IS-MEMBER

              MOVE W-OWNERGROUP TO W-GROUP
              PERFORM R096-CHECK-GROUP
              MOVE W-IN-GROUP TO W-IS-OWNER

              PERFORM R095-CHECK-ADMIN

              PERFORM R101-CHECK-APPROVER
           END-IF

           IF  W-IS-MEMBER = 'Y' OR W-IS-OWNER = 'Y'
            OR W-IS-APPROVER = 'Y' OR W-IS-ADMIN = 'Y'
              MOVE 'Y' TO W-CAN-SEE
           END-IF
           .
       R100-APP-ROLES-END.
           EXIT.

      *===============================================================*
      * R101-CHECK-APPROVER: W-IS-APPROVER = Y when the user is in    *
      * the approver group of an environment of W-APPID               *
      *===============================================================*
       R101-CHECK-APPROVER SECTION.
           EXEC SQL
              DECLARE CTX1 CURSOR FOR
              SELECT DISTINCT APPROVERGROUP
                FROM TBLWD006
               WHERE APPID = :W-APPID
                 AND APPROVERGROUP IS NOT NULL
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN CTX1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'OPEN CURSOR CTX1' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           ELSE
              MOVE 'N' TO W-CTX-EOF
              PERFORM UNTIL W-CTX-EOF = 'Y'
                         OR W-IS-APPROVER = 'Y'
                         OR RETURNCODE OF :IO: NOT = N'00'
                 EXEC SQL
                    FETCH CTX1 INTO :W-RACFGROUP
                 END-EXEC
                 EVALUATE SQLCODE
                 WHEN 0
                    MOVE W-RACFGROUP TO W-GROUP
                    PERFORM R096-CHECK-GROUP
                    MOVE W-IN-GROUP TO W-IS-APPROVER
                 WHEN 100
                    MOVE 'Y' TO W-CTX-EOF
                 WHEN OTHER
                    MOVE N'FETCH CURSOR CTX1' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE CTX1
              END-EXEC
           END-IF
           .
       R101-CHECK-APPROVER-END.
           EXIT.

      *===============================================================*
      * R105-REQUIRE-SEE: 04 01 when the application doesn't exist or *
      * the user has no role in it, so its existence isn't revealed   *
      *===============================================================*
       R105-REQUIRE-SEE SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-CAN-SEE NOT = 'Y'
              MOVE N'04' TO RETURNCODE OF :IO:
              MOVE N'01' TO REASONCODE OF :IO:
              MOVE N'Application not found' TO INFOMESSAGE OF :IO:
           END-IF
           .
       R105-REQUIRE-SEE-END.
           EXIT.

      *===============================================================*
      * R106-REQUIRE-OWNER: 08 50 unless the user is in the owner     *
      * group of W-APPID; administrators too (docs/10-iteration-6.md: *
      * they change things only through /admin). After R105.          *
      *===============================================================*
       R106-REQUIRE-OWNER SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-IS-OWNER NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'50' TO REASONCODE OF :IO:
              MOVE N'Only an owner of the application may do this' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R106-REQUIRE-OWNER-END.
           EXIT.

      *===============================================================*
      * R110-ENSURE-USER: The user row exists (U1). W-GROUPS-FRESH =  *
      * Y when its USERGROUPS rows are younger than GRPMINS minutes   *
      *===============================================================*
       R110-ENSURE-USER SECTION.
           MOVE 'N' TO W-GROUPS-FRESH
           PERFORM R092-SECURITY-SETTINGS

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT CASE WHEN GROUPSCHECKED IS NOT NULL
                              AND GROUPSCHECKED >
                                  CURRENT TIMESTAMP - :W-GRPMINS MINUTES
                             THEN 'Y' ELSE 'N' END
                   INTO :W-GROUPS-FRESH
                   FROM TBLWD002
                  WHERE USERID = :W-USERID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 EXEC SQL
                    INSERT INTO TBLWD002
                         ( USERID, EMAIL, NOTIFYAPPROVE, NOTIFYOWN,
                           NOTIFYAPP, GROUPSCHECKED,
                           CREATEDBY, CREATEDDATE,
                           UPDATEDBY, UPDATEDDATE )
                    VALUES ( :W-USERID, NULL, :C-Y, :C-Y,
                             :C-N, NULL,
                             :W-USERID, CURRENT TIMESTAMP,
                             :W-USERID, CURRENT TIMESTAMP )
                 END-EXEC
      *          -803: a parallel request of the same user was first
                 IF SQLCODE NOT = 0 AND SQLCODE NOT = -803
                    MOVE N'INSERT user' TO W-SQL-WHAT
                    MOVE N'12' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-IF
              WHEN OTHER
                 MOVE N'SELECT user' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R110-ENSURE-USER-END.
           EXIT.

      *===============================================================*
      * R120-REFRESH-GROUPS: When not fresh, check every group of the *
      * RACFGRP allowlist and rewrite the user's USERGROUPS rows      *
      *===============================================================*
       R120-REFRESH-GROUPS SECTION.
           PERFORM R110-ENSURE-USER

           IF  RETURNCODE OF :IO: = N'00'
           AND W-GROUPS-FRESH = 'N'
              EXEC SQL
                 DELETE FROM TBLWD003
                  WHERE USERID = :W-USERID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE N'DELETE usergroups' TO W-SQL-WHAT
                 MOVE N'42' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND W-GROUPS-FRESH = 'N'
              EXEC SQL
                 DECLARE CTX2 CURSOR FOR
                 SELECT TABKEY
                   FROM TBLWD001
                  WHERE TABLEID = :C-RACFGRP
                    FOR FETCH ONLY
              END-EXEC

              EXEC SQL
                 OPEN CTX2
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'OPEN CURSOR CTX2' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE 'N' TO W-CTX-EOF
                 PERFORM UNTIL W-CTX-EOF = 'Y'
                            OR RETURNCODE OF :IO: NOT = N'00'
                    EXEC SQL
                       FETCH CTX2 INTO :W-RACFGROUP
                    END-EXEC
                    EVALUATE SQLCODE
                    WHEN 0
                       MOVE W-RACFGROUP TO W-GROUP
                       PERFORM R096-CHECK-GROUP
                       IF W-IN-GROUP = 'Y'
                          PERFORM R121-INSERT-GROUP
                       END-IF
                    WHEN 100
                       MOVE 'Y' TO W-CTX-EOF
                    WHEN OTHER
                       MOVE N'FETCH CURSOR CTX2' TO W-SQL-WHAT
                       MOVE N'21' TO W-SQL-REASON
                       PERFORM R890-SQL-ERROR
                    END-EVALUATE
                 END-PERFORM

                 EXEC SQL
                    CLOSE CTX2
                 END-EXEC
              END-IF
           END-IF

           IF  RETURNCODE OF :IO: = N'00'
           AND W-GROUPS-FRESH = 'N'
              EXEC SQL
                 UPDATE TBLWD002
                    SET GROUPSCHECKED = CURRENT TIMESTAMP,
                        UPDATEDBY     = :W-USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE USERID = :W-USERID
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'UPDATE user' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE 'Y' TO W-GROUPS-FRESH
              END-IF
           END-IF
           .
       R120-REFRESH-GROUPS-END.
           EXIT.

      *===============================================================*
      * R121-INSERT-GROUP: One USERGROUPS row for W-RACFGROUP         *
      *===============================================================*
       R121-INSERT-GROUP SECTION.
           EXEC SQL
              INSERT INTO TBLWD003
                   ( USERID, RACFGROUP,
                     CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
              VALUES ( :W-USERID, :W-RACFGROUP,
                       :W-USERID, CURRENT TIMESTAMP,
                       :W-USERID, CURRENT TIMESTAMP )
           END-EXEC

      *    -803: a parallel request of the same user was first
           IF SQLCODE NOT = 0 AND SQLCODE NOT = -803
              MOVE N'INSERT usergroup' TO W-SQL-WHAT
              MOVE N'12' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-IF
           .
       R121-INSERT-GROUP-END.
           EXIT.

      *===============================================================*
      * R890-SQL-ERROR: 08 W-SQL-REASON with W-SQL-WHAT and SQLCODE   *
      *===============================================================*
       R890-SQL-ERROR SECTION.
           MOVE SQLCODE TO W-SQLCODE
           MOVE N'08' TO RETURNCODE OF :IO:
           MOVE W-SQL-REASON TO REASONCODE OF :IO:
           MOVE SPACES TO INFOMESSAGE OF :IO:
           STRING W-SQL-WHAT DELIMITED BY N'  '
                  N' gave SQLCODE=' DELIMITED BY SIZE
                  FUNCTION NATIONAL-OF(W-SQLCODE) DELIMITED BY SIZE
              INTO INFOMESSAGE OF :IO:
           PERFORM R900-DSNTIAR
           .
       R890-SQL-ERROR-END.
           EXIT.

      *===============================================================*
      * R900-DSNTIAR: Format SQLCA information when error             *
      *===============================================================*
       R900-DSNTIAR SECTION.
           CALL 'DSNTIAR' USING SQLCA ERROR-MESSAGE ERROR-TEXT-LEN

           PERFORM VARYING ERROR-INDEX
              FROM 1 BY 1 UNTIL ERROR-INDEX = 10
                   DISPLAY ERROR-TEXT(ERROR-INDEX)
           END-PERFORM
           .
       R900-DSNTIAR-END.
           EXIT.
