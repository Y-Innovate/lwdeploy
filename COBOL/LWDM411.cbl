       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM411.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * POST /deployments: request a deployment (D1).                 *
      * 1. Checks: the user is a deployer (member, and in the         *
      *    deployer group if the environment has one); the version is *
      *    active; the environment is ready (deploy userid, approver  *
      *    group when approval is required, templates with JCL); the  *
      *    promotion gate.                                            *
      * 2. Stores the deployment as W (approval) or Q, with the       *
      *    deploy userid and approval rules copied from the           *
      *    environment.                                               *
      * 3. Freezes the JCL: every active template, in order, with     *
      *    ${NAME} replaced by its value: built-in, version,          *
      *    environment, application. The JOB statement and the result *
      *    step are added at submission (LWDM920), not here.          *
      * 4. A Q deployment whose time has come takes the environment   *
      *    if it is free (ACTIVEDEPLID), becomes U and gets a run of  *
      *    job 1 with a token (LWDSTRP). The wrapper commits and      *
      *    starts the submit task with LLWDC910. Otherwise it stays   *
      *    Q, and the scheduler (LWDM930) starts it later.            *
      * The answer is GET /deployments/{deplID}, from LWDM311.        *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Application, environment or version not found         *
      * 08 04 = Error: startAfter is not a valid timestamp            *
      * 08 50 = Error: not a deployer for this environment            *
      * 08 53 = Error: the version is retired                         *
      * 08 54 = Error: the promotion gate is not passed               *
      * 08 56 = Error: a JCL line is longer than 80 characters        *
      * 08 57 = Error: a variable has no value                        *
      * 08 59 = Error: the environment or application is not ready    *
      * 08 90 = Error: too many variables, or a routine failed        *
      * And the codes of LWDCTXP and LWDM311                          *
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

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD007 END-EXEC.

           EXEC SQL INCLUDE TBLWD008 END-EXEC.

           EXEC SQL INCLUDE TBLWD010 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD012 END-EXEC.

           EXEC SQL INCLUDE TBLWD013 END-EXEC.

           EXEC SQL INCLUDE TBLWD014 END-EXEC.

           EXEC SQL INCLUDE TBLWD019 END-EXEC.

           COPY LWDCTXW.
           COPY LWDSECW.
           COPY LWDDEPW.
           COPY LWDMALW.
           COPY LWDSTRW.

       01 WORK.
          05 W-PGMNAME       PIC X(8).
          05 W-ENVID         PIC S9(9) COMP-5.
          05 W-VERSIONID     PIC S9(9) COMP-5.
          05 W-DEPLID        PIC S9(9) COMP-5.
          05 W-APPCODE       PIC N(8).
          05 W-PREV-ENVID    PIC S9(9) COMP-5.
          05 W-PREV-ENVCODE  PIC N(8).
          05 W-PASSED        PIC X.
          05 W-STARTX        PIC X(26).
          05 W-STARTAFTER    PIC X(26).
          05 W-DUE           PIC X.
          05 W-STATUS        PIC N.
          05 W-COUNT         PIC S9(9) COMP-5.
          05 W-NOJCL         PIC S9(9) COMP-5.
          05 W-NOTE-IND      PIC S9(4) COMP-5.
          05 W-GROUP-IND     PIC S9(4) COMP-5.
          05 W-EOF           PIC X.
          05 W-T             PIC S9(4) COMP-5.
          05 W-K             PIC S9(4) COMP-5.
          05 W-L             PIC S9(4) COMP-5.
          05 W-E             PIC S9(4) COMP-5.
          05 W-NUM-ED        PIC Z(8)9.
          05 W-LINE-ED       PIC ZZ9.
          05 W-JOB-ED        PIC Z9.
      *   Templates of the application, in order
          05 W-TPL-COUNT     PIC S9(4) COMP-5.
          05 W-TPL OCCURS 20 TIMES.
             10 W-TPL-ID     PIC S9(9) COMP-5.
             10 W-TPL-REV    PIC S9(4) COMP-5.
             10 W-TPL-MAXRC  PIC S9(4) COMP-5.
             10 W-TPL-NAME.
                49 W-TPL-NAME-LEN  PIC S9(4) COMP-5.
                49 W-TPL-NAME-TEXT PIC N(60).
      *   Variables: built-in first, then by level, the first one wins
          05 W-VAR-COUNT     PIC S9(4) COMP-5.
          05 W-VAR OCCURS 200 TIMES.
             10 W-VAR-NAME   PIC N(16).
             10 W-VAR-NLEN   PIC S9(4) COMP-5.
             10 W-VAR-VALUE  PIC N(255).
             10 W-VAR-VLEN   PIC S9(4) COMP-5.
      *   Host variables of one template (no subscripts in SQL)
          05 W-CUR-ID        PIC S9(9) COMP-5.
          05 W-CUR-REV       PIC S9(4) COMP-5.
          05 W-CUR-MAXRC     PIC S9(4) COMP-5.
          05 W-CUR-NAME.
             49 W-CUR-NAME-LEN  PIC S9(4) COMP-5.
             49 W-CUR-NAME-TEXT PIC N(60).
          05 W-ADD-NAME      PIC N(16).
          05 W-ADD-NLEN      PIC S9(4) COMP-5.
          05 W-ADD-VALUE     PIC N(255).
          05 W-ADD-VLEN      PIC S9(4) COMP-5.
          05 W-FOUND         PIC S9(4) COMP-5.
      *   Fetched variable and template line
          05 W-VARNAME.
             49 W-VARNAME-LEN  PIC S9(4) COMP-5.
             49 W-VARNAME-TEXT PIC N(16).
          05 W-VARVALUE.
             49 W-VARVALUE-LEN  PIC S9(4) COMP-5.
             49 W-VARVALUE-TEXT PIC N(255).
          05 W-LINENUM       PIC S9(4) COMP-5.
          05 W-SRC.
             49 W-SRC-LEN    PIC S9(4) COMP-5.
             49 W-SRC-TEXT   PIC N(80).
      *   Resolved lines of one job
          05 W-OUT           PIC N(400).
          05 W-OPOS          PIC S9(4) COMP-5.
          05 W-SPOS          PIC S9(4) COMP-5.
          05 W-NAME          PIC N(16).
          05 W-NLEN          PIC S9(4) COMP-5.
          05 W-LINE-COUNT    PIC S9(4) COMP-5.
          05 W-LINE OCCURS 300 TIMES.
             10 W-LINE-TEXT.
                49 W-LINE-LEN  PIC S9(4) COMP-5.
                49 W-LINE-DATA PIC N(80).
          05 W-JL.
             49 W-JL-LEN     PIC S9(4) COMP-5.
             49 W-JL-TEXT    PIC N(80).

       01 W-LLWDM311.
           COPY LLWDM311.

       LINKAGE SECTION.
       01 P-LLWDM411.
           COPY LLWDM411.
       01 P-LLWDC910.
           COPY LLWDC910.

       PROCEDURE DIVISION USING P-LLWDM411 P-LLWDC910.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           PERFORM R200-READ-ENVIRONMENT
           PERFORM R210-READ-VERSION
           PERFORM R220-CHECK-DEPLOYER
           PERFORM R230-CHECK-READY
           PERFORM R240-CHECK-GATE
           PERFORM R250-START-TIME

           PERFORM R300-INSERT-DEPLOYMENT
           PERFORM R310-LOAD-VARIABLES
           PERFORM R320-FREEZE-JOBS

           IF  RETURNCODE OF P-LLWDM411 = N'00'
           AND W-STATUS = C-Q
           AND W-DUE = 'Y'
              MOVE W-DEPLID TO W-ST-DEPLID
              MOVE W-ENVID TO W-ST-ENVID
              PERFORM R700-START-DEPLOYMENT
              IF W-ST-STARTED = 'N'
                 MOVE 'N' TO W-DUE
              END-IF
           END-IF

           PERFORM R500-ANSWER
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM411
           MOVE N'00' TO REASONCODE OF P-LLWDM411
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM411

           INITIALIZE P-LLWDC910
           MOVE '00' TO C910-RC OF P-LLWDC910
           MOVE 0 TO RUNID OF P-LLWDC910

           MOVE APPID OF P-LLWDM411 TO W-APPID
           MOVE ENVID OF P-LLWDM411 TO W-ENVID
           MOVE VERSIONID OF P-LLWDM411 TO W-VERSIONID
           MOVE 0 TO W-DEPLID
           MOVE 'N' TO W-DUE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-READ-ENVIRONMENT: The environment, in this application   *
      *===============================================================*
       R200-READ-ENVIRONMENT SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              EXEC SQL
                 SELECT E.ENVCODE,
                        E.SORTORDER,
                        E.PROMOGATE,
                        E.DEPLOYUSER,
                        E.APPROVALREQ,
                        E.APPROVERGROUP,
                        E.APPROVALCOUNT,
                        E.DEPLOYERGROUP,
                        A.APPCODE
                   INTO :DCLTBLWD006.ENVCODE,
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
                        :W-APPCODE
                   FROM TBLWD006 E
                   JOIN TBLWD004 A
                     ON A.APPID = E.APPID
                  WHERE E.ENVID = :W-ENVID
                    AND E.APPID = :W-APPID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM411
                 MOVE N'01' TO REASONCODE OF P-LLWDM411
                 MOVE N'Environment not found' TO
                      INFOMESSAGE OF P-LLWDM411
              WHEN OTHER
                 MOVE N'SELECT environment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R200-READ-ENVIRONMENT-END.
           EXIT.

      *===============================================================*
      * R210-READ-VERSION: The version, in this application, active   *
      *===============================================================*
       R210-READ-VERSION SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              EXEC SQL
                 SELECT VERSIONNAME,
                        LOCATION,
                        VERSIONSTATUS
                   INTO :DCLTBLWD005.VERSIONNAME,
                        :DCLTBLWD005.LOCATION,
                        :DCLTBLWD005.VERSIONSTATUS
                   FROM TBLWD005
                  WHERE VERSIONID = :W-VERSIONID
                    AND APPID = :W-APPID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 IF VERSIONSTATUS OF DCLTBLWD005 NOT = C-A
                    MOVE N'08' TO RETURNCODE OF P-LLWDM411
                    MOVE N'53' TO REASONCODE OF P-LLWDM411
                    MOVE N'The version is retired' TO
                         INFOMESSAGE OF P-LLWDM411
                 END-IF
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF P-LLWDM411
                 MOVE N'01' TO REASONCODE OF P-LLWDM411
                 MOVE N'Version not found' TO INFOMESSAGE OF P-LLWDM411
              WHEN OTHER
                 MOVE N'SELECT version' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R210-READ-VERSION-END.
           EXIT.

      *===============================================================*
      * R220-CHECK-DEPLOYER: Member, and in the deployer group if the *
      * environment has one                                           *
      *===============================================================*
       R220-CHECK-DEPLOYER SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              IF W-IS-MEMBER NOT = 'Y'
                 MOVE 'N' TO W-IN-GROUP
              ELSE
                 MOVE 'Y' TO W-IN-GROUP
                 IF DEPLOYERGROUP-IND OF DCLTBLWD006 >= 0
                    MOVE DEPLOYERGROUP OF DCLTBLWD006 TO W-GROUP
                    PERFORM R096-CHECK-GROUP
                 END-IF
              END-IF

              IF  RETURNCODE OF P-LLWDM411 = N'00'
              AND W-IN-GROUP NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LLWDM411
                 MOVE N'50' TO REASONCODE OF P-LLWDM411
                 MOVE N'You may not deploy to this environment' TO
                      INFOMESSAGE OF P-LLWDM411
              END-IF
           END-IF
           .
       R220-CHECK-DEPLOYER-END.
           EXIT.

      *===============================================================*
      * R230-CHECK-READY: Deploy userid, approver group if needed,    *
      * and at least one template, each with JCL                      *
      *===============================================================*
       R230-CHECK-READY SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              EVALUATE TRUE
              WHEN DEPLOYUSER-IND OF DCLTBLWD006 < 0
                 MOVE N'The environment has no deploy userid yet' TO
                      INFOMESSAGE OF P-LLWDM411
              WHEN APPROVALREQ OF DCLTBLWD006 = C-Y
               AND (APPROVERGROUP-IND OF DCLTBLWD006 < 0
                OR  APPROVALCOUNT OF DCLTBLWD006 < 1)
                 MOVE N'The environment has no approver group yet' TO
                      INFOMESSAGE OF P-LLWDM411
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF P-LLWDM411 = N'00'
           AND INFOMESSAGE OF P-LLWDM411 = SPACES
              EXEC SQL
                 SELECT COUNT(*),
                        COALESCE(SUM(CASE WHEN CURRENTREV = 0
                                          THEN 1 ELSE 0 END), 0)
                   INTO :W-COUNT,
                        :W-NOJCL
                   FROM TBLWD008
                  WHERE APPID = :W-APPID
                    AND TEMPLATESTATUS = :C-A
              END-EXEC

              EVALUATE TRUE
              WHEN SQLCODE NOT = 0
                 MOVE N'SELECT templates' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              WHEN W-COUNT = 0
                 MOVE N'The application has no job templates' TO
                      INFOMESSAGE OF P-LLWDM411
              WHEN W-COUNT > 20
                 MOVE N'The application has more than 20 templates' TO
                      INFOMESSAGE OF P-LLWDM411
              WHEN W-NOJCL > 0
                 MOVE N'A job template has no JCL yet' TO
                      INFOMESSAGE OF P-LLWDM411
              END-EVALUATE
           END-IF

           IF  RETURNCODE OF P-LLWDM411 = N'00'
           AND INFOMESSAGE OF P-LLWDM411 NOT = SPACES
              MOVE N'08' TO RETURNCODE OF P-LLWDM411
              MOVE N'59' TO REASONCODE OF P-LLWDM411
           END-IF
           .
       R230-CHECK-READY-END.
           EXIT.

      *===============================================================*
      * R240-CHECK-GATE: With PROMOGATE Y, the version must have      *
      * succeeded in the environment just before this one             *
      *===============================================================*
       R240-CHECK-GATE SECTION.
           IF  RETURNCODE OF P-LLWDM411 = N'00'
           AND PROMOGATE OF DCLTBLWD006 = C-Y
              EXEC SQL
                 SELECT ENVID,
                        ENVCODE
                   INTO :W-PREV-ENVID,
                        :W-PREV-ENVCODE
                   FROM TBLWD006
                  WHERE APPID = :W-APPID
                    AND (SORTORDER < :DCLTBLWD006.SORTORDER
                     OR (SORTORDER = :DCLTBLWD006.SORTORDER
                    AND  ENVID < :W-ENVID))
                  ORDER BY SORTORDER DESC, ENVID DESC
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R241-SUCCEEDED-BEFORE
              WHEN 100
      *          The first environment has nothing before it
                 CONTINUE
              WHEN OTHER
                 MOVE N'SELECT previous environment' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF
           .
       R240-CHECK-GATE-END.
           EXIT.

      *===============================================================*
      * R241-SUCCEEDED-BEFORE: A succeeded deployment of the version  *
      * into the previous environment                                 *
      *===============================================================*
       R241-SUCCEEDED-BEFORE SECTION.
           EXEC SQL
              SELECT CASE WHEN EXISTS
                          (SELECT 1 FROM TBLWD011 D
                            WHERE D.VERSIONID = :W-VERSIONID
                              AND D.ENVID = :W-PREV-ENVID
                              AND D.DEPLSTATUS = :C-S)
                          THEN 'Y' ELSE 'N' END
                INTO :W-PASSED
                FROM SYSIBM.SYSDUMMY1
           END-EXEC

           EVALUATE TRUE
           WHEN SQLCODE NOT = 0
              MOVE N'SELECT gate' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           WHEN W-PASSED = 'N'
              MOVE N'08' TO RETURNCODE OF P-LLWDM411
              MOVE N'54' TO REASONCODE OF P-LLWDM411
              STRING N'The version did not succeed in '
                     DELIMITED BY SIZE
                     W-PREV-ENVCODE DELIMITED BY N' '
                     N' yet' DELIMITED BY SIZE
                INTO INFOMESSAGE OF P-LLWDM411
           END-EVALUATE
           .
       R241-SUCCEEDED-BEFORE-END.
           EXIT.

      *===============================================================*
      * R250-START-TIME: W-STARTAFTER from startAfter; empty or in    *
      * the past means now. W-DUE = Y when it may start now           *
      *===============================================================*
       R250-START-TIME SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              IF STARTAFTER OF P-LLWDM411 = SPACES
              OR STARTAFTER OF P-LLWDM411(1:1) = NX'0000'
                 MOVE SPACES TO W-STARTX
              ELSE
                 MOVE FUNCTION DISPLAY-OF(STARTAFTER OF P-LLWDM411)
                   TO W-STARTX
              END-IF

              IF W-STARTX = SPACES
                 EXEC SQL
                    SELECT CHAR(CURRENT TIMESTAMP)
                      INTO :W-STARTAFTER
                      FROM SYSIBM.SYSDUMMY1
                 END-EXEC
              ELSE
                 EXEC SQL
                    SELECT CHAR(CASE WHEN TIMESTAMP(:W-STARTX)
                                          < CURRENT TIMESTAMP
                                     THEN CURRENT TIMESTAMP
                                     ELSE TIMESTAMP(:W-STARTX) END)
                      INTO :W-STARTAFTER
                      FROM SYSIBM.SYSDUMMY1
                 END-EXEC
              END-IF

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -180
              WHEN -181
                 MOVE N'08' TO RETURNCODE OF P-LLWDM411
                 MOVE N'04' TO REASONCODE OF P-LLWDM411
                 MOVE N'startAfter is not a valid timestamp' TO
                      INFOMESSAGE OF P-LLWDM411
              WHEN OTHER
                 MOVE N'SELECT start time' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LLWDM411 = N'00'
              EXEC SQL
                 SELECT CASE WHEN TIMESTAMP(:W-STARTAFTER)
                                  <= CURRENT TIMESTAMP
                             THEN 'Y' ELSE 'N' END
                   INTO :W-DUE
                   FROM SYSIBM.SYSDUMMY1
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'SELECT due' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R250-START-TIME-END.
           EXIT.

      *===============================================================*
      * R300-INSERT-DEPLOYMENT: W with approval, Q without, and the   *
      * R event                                                       *
      *===============================================================*
       R300-INSERT-DEPLOYMENT SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              IF APPROVALREQ OF DCLTBLWD006 = C-Y
                 MOVE C-W TO W-STATUS
                 MOVE 0 TO W-GROUP-IND
              ELSE
                 MOVE C-Q TO W-STATUS
                 MOVE -1 TO W-GROUP-IND
                 MOVE 0 TO APPROVALCOUNT OF DCLTBLWD006
              END-IF
              IF REQUESTNOTE-LEN OF P-LLWDM411 > 0
                 MOVE 0 TO W-NOTE-IND
              ELSE
                 MOVE -1 TO W-NOTE-IND
                 MOVE 0 TO REQUESTNOTE-LEN OF P-LLWDM411
              END-IF

              EXEC SQL
                 SELECT DEPLID
                   INTO :W-DEPLID
                   FROM FINAL TABLE
                        (INSERT INTO TBLWD011
                              ( APPID, ENVID, VERSIONID, DEPLSTATUS,
                                STARTAFTER, REQUESTNOTE, DEPLOYUSER,
                                APPROVERGROUP, APPROVALCOUNT,
                                APPROVEDCOUNT, STARTEDDATE, ENDEDDATE,
                                CREATEDBY, CREATEDDATE,
                                UPDATEDBY, UPDATEDDATE )
                         VALUES ( :W-APPID, :W-ENVID, :W-VERSIONID,
                                  :W-STATUS,
                                  TIMESTAMP(:W-STARTAFTER),
                                  :P-LLWDM411.REQUESTNOTE :W-NOTE-IND,
                                  :DCLTBLWD006.DEPLOYUSER,
                                  :DCLTBLWD006.APPROVERGROUP
                                     :W-GROUP-IND,
                                  :DCLTBLWD006.APPROVALCOUNT,
                                  0, NULL, NULL,
                                  :W-USERID, CURRENT TIMESTAMP,
                                  :W-USERID, CURRENT TIMESTAMP ))
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'INSERT deployment' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE W-DEPLID TO W-EV-DEPLID
                 MOVE C-R TO W-EV-TYPE
                 IF W-NOTE-IND = 0
                    MOVE REQUESTNOTE OF P-LLWDM411 TO W-EV-COMMENT
                    MOVE 0 TO W-EV-COMMENT-IND
                 END-IF
                 PERFORM R650-ADD-EVENT
              END-IF
           END-IF
           .
       R300-INSERT-DEPLOYMENT-END.
           EXIT.

      *===============================================================*
      * R310-LOAD-VARIABLES: Built-in variables first, then those of  *
      * the version, environment and application, in that order: the  *
      * first value of a name wins                                    *
      *===============================================================*
       R310-LOAD-VARIABLES SECTION.
           MOVE 0 TO W-VAR-COUNT

           IF RETURNCODE OF P-LLWDM411 = N'00'
              MOVE N'LWDAPP' TO W-ADD-NAME
              MOVE W-APPCODE TO W-ADD-VALUE
              PERFORM R710-ADD-TRIMMED

              MOVE N'LWDENV' TO W-ADD-NAME
              MOVE ENVCODE OF DCLTBLWD006 TO W-ADD-VALUE
              PERFORM R710-ADD-TRIMMED

              MOVE N'LWDVER' TO W-ADD-NAME
              MOVE SPACES TO W-ADD-VALUE
              MOVE VERSIONNAME-TEXT OF DCLTBLWD005
                   (1:VERSIONNAME-LEN OF DCLTBLWD005) TO W-ADD-VALUE
              PERFORM R710-ADD-TRIMMED

              MOVE N'LWDLOC' TO W-ADD-NAME
              MOVE SPACES TO W-ADD-VALUE
              MOVE LOCATION-TEXT OF DCLTBLWD005
                   (1:LOCATION-LEN OF DCLTBLWD005) TO W-ADD-VALUE
              PERFORM R710-ADD-TRIMMED

              MOVE N'LWDDEPL' TO W-ADD-NAME
              MOVE W-DEPLID TO W-NUM-ED
              MOVE FUNCTION NATIONAL-OF(FUNCTION TRIM(W-NUM-ED))
                TO W-ADD-VALUE
              PERFORM R710-ADD-TRIMMED

              EXEC SQL
                 DECLARE C2 CURSOR FOR
                 SELECT VARNAME,
                        VARVALUE,
                        CASE WHEN VERSIONID IS NOT NULL THEN 1
                             WHEN ENVID IS NOT NULL THEN 2
                             ELSE 3 END AS LVL
                   FROM TBLWD007
                  WHERE APPID = :W-APPID
                    AND ((ENVID IS NULL AND VERSIONID IS NULL)
                     OR  (ENVID = :W-ENVID AND VERSIONID IS NULL)
                     OR  (ENVID IS NULL AND VERSIONID = :W-VERSIONID))
                  ORDER BY LVL
                    FOR FETCH ONLY
              END-EXEC

              EXEC SQL
                 OPEN C2
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'OPEN CURSOR C2' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE 'N' TO W-EOF
                 PERFORM UNTIL W-EOF = 'Y'
                            OR RETURNCODE OF P-LLWDM411 NOT = N'00'
                    EXEC SQL
                       FETCH C2 INTO :W-VARNAME, :W-VARVALUE, :W-K
                    END-EXEC
                    EVALUATE SQLCODE
                    WHEN 0
                       MOVE SPACES TO W-ADD-NAME W-ADD-VALUE
                       MOVE W-VARNAME-TEXT(1:W-VARNAME-LEN) TO
                            W-ADD-NAME
                       MOVE W-VARNAME-LEN TO W-ADD-NLEN
                       IF W-VARVALUE-LEN > 0
                          MOVE W-VARVALUE-TEXT(1:W-VARVALUE-LEN) TO
                               W-ADD-VALUE
                       END-IF
                       MOVE W-VARVALUE-LEN TO W-ADD-VLEN
                       PERFORM R700-ADD-VAR
                    WHEN 100
                       MOVE 'Y' TO W-EOF
                    WHEN OTHER
                       MOVE N'FETCH CURSOR C2' TO W-SQL-WHAT
                       MOVE N'21' TO W-SQL-REASON
                       PERFORM R890-SQL-ERROR
                    END-EVALUATE
                 END-PERFORM

                 EXEC SQL
                    CLOSE C2
                 END-EXEC
              END-IF
           END-IF
           .
       R310-LOAD-VARIABLES-END.
           EXIT.

      *===============================================================*
      * R320-FREEZE-JOBS: One DEPLJOBS row and its JCLLINES per       *
      * active template, in order                                     *
      *===============================================================*
       R320-FREEZE-JOBS SECTION.
           MOVE 0 TO W-TPL-COUNT

           IF RETURNCODE OF P-LLWDM411 = N'00'
              EXEC SQL
                 DECLARE C3 CURSOR FOR
                 SELECT TEMPLATEID,
                        CURRENTREV,
                        MAXRC,
                        TEMPLATENAME
                   FROM TBLWD008
                  WHERE APPID = :W-APPID
                    AND TEMPLATESTATUS = :C-A
                  ORDER BY SORTORDER, TEMPLATEID
                  FETCH FIRST 20 ROWS ONLY
                    FOR FETCH ONLY
              END-EXEC

              EXEC SQL
                 OPEN C3
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'OPEN CURSOR C3' TO W-SQL-WHAT
                 MOVE N'21' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              ELSE
                 MOVE 'N' TO W-EOF
                 PERFORM UNTIL W-EOF = 'Y'
                            OR RETURNCODE OF P-LLWDM411 NOT = N'00'
                            OR W-TPL-COUNT >= 20
                    EXEC SQL
                       FETCH C3
                        INTO :W-CUR-ID,
                             :W-CUR-REV,
                             :W-CUR-MAXRC,
                             :W-CUR-NAME
                    END-EXEC
                    EVALUATE SQLCODE
                    WHEN 0
                       ADD 1 TO W-TPL-COUNT
                       MOVE W-CUR-ID TO W-TPL-ID(W-TPL-COUNT)
                       MOVE W-CUR-REV TO W-TPL-REV(W-TPL-COUNT)
                       MOVE W-CUR-MAXRC TO W-TPL-MAXRC(W-TPL-COUNT)
                       MOVE W-CUR-NAME TO W-TPL-NAME(W-TPL-COUNT)
                    WHEN 100
                       MOVE 'Y' TO W-EOF
                    WHEN OTHER
                       MOVE N'FETCH CURSOR C3' TO W-SQL-WHAT
                       MOVE N'21' TO W-SQL-REASON
                       PERFORM R890-SQL-ERROR
                    END-EVALUATE
                 END-PERFORM

                 EXEC SQL
                    CLOSE C3
                 END-EXEC
              END-IF
           END-IF

           PERFORM VARYING W-T FROM 1 BY 1
                     UNTIL W-T > W-TPL-COUNT
                        OR RETURNCODE OF P-LLWDM411 NOT = N'00'
              MOVE W-TPL-ID(W-T) TO W-CUR-ID
              MOVE W-TPL-REV(W-T) TO W-CUR-REV
              MOVE W-TPL-MAXRC(W-T) TO W-CUR-MAXRC
              MOVE W-TPL-NAME(W-T) TO W-CUR-NAME
              PERFORM R330-RESOLVE-JOB
              PERFORM R340-INSERT-JOB
           END-PERFORM
           .
       R320-FREEZE-JOBS-END.
           EXIT.

      *===============================================================*
      * R330-RESOLVE-JOB: Read the lines of template W-T and resolve  *
      * them into W-LINE                                              *
      *===============================================================*
       R330-RESOLVE-JOB SECTION.
           MOVE 0 TO W-LINE-COUNT

           EXEC SQL
              DECLARE C4 CURSOR FOR
              SELECT LINENUM,
                     LINETEXT
                FROM TBLWD010
               WHERE TEMPLATEID = :W-CUR-ID
                 AND REVISION = :W-CUR-REV
               ORDER BY LINENUM
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C4
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE N'OPEN CURSOR C4' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           ELSE
              MOVE 'N' TO W-EOF
              PERFORM UNTIL W-EOF = 'Y'
                         OR RETURNCODE OF P-LLWDM411 NOT = N'00'
                 EXEC SQL
                    FETCH C4 INTO :W-LINENUM, :W-SRC
                 END-EXEC
                 EVALUATE SQLCODE
                 WHEN 0
                    IF W-LINE-COUNT >= 300
                       MOVE N'08' TO RETURNCODE OF P-LLWDM411
                       MOVE N'56' TO REASONCODE OF P-LLWDM411
                       MOVE N'A template has more than 300 lines' TO
                            INFOMESSAGE OF P-LLWDM411
                    ELSE
                       ADD 1 TO W-LINE-COUNT
                       PERFORM R335-RESOLVE-LINE
                    END-IF
                 WHEN 100
                    MOVE 'Y' TO W-EOF
                 WHEN OTHER
                    MOVE N'FETCH CURSOR C4' TO W-SQL-WHAT
                    MOVE N'21' TO W-SQL-REASON
                    PERFORM R890-SQL-ERROR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE C4
              END-EXEC
           END-IF
           .
       R330-RESOLVE-JOB-END.
           EXIT.

      *===============================================================*
      * R335-RESOLVE-LINE: W-SRC with every ${NAME} replaced, into    *
      * W-LINE(W-LINE-COUNT), without trailing spaces. A ${ without a *
      * closing } is kept as it is.                                   *
      *===============================================================*
       R335-RESOLVE-LINE SECTION.
           MOVE SPACES TO W-OUT
           MOVE 0 TO W-OPOS
           MOVE 1 TO W-SPOS

           PERFORM UNTIL W-SPOS > W-SRC-LEN
                      OR RETURNCODE OF P-LLWDM411 NOT = N'00'
              MOVE 0 TO W-E
              IF  W-SPOS < W-SRC-LEN
              AND W-SRC-TEXT(W-SPOS:2) = N'${'
                 PERFORM VARYING W-E FROM W-SPOS BY 1
                           UNTIL W-E > W-SRC-LEN
                              OR W-SRC-TEXT(W-E:1) = N'}'
                    CONTINUE
                 END-PERFORM
                 IF W-E > W-SRC-LEN
                    MOVE 0 TO W-E
                 END-IF
              END-IF

              IF W-E = 0
                 ADD 1 TO W-OPOS
                 MOVE W-SRC-TEXT(W-SPOS:1) TO W-OUT(W-OPOS:1)
                 ADD 1 TO W-SPOS
              ELSE
                 COMPUTE W-NLEN = W-E - W-SPOS - 2
                 MOVE SPACES TO W-NAME
                 IF W-NLEN > 0 AND W-NLEN <= 16
                    MOVE W-SRC-TEXT(W-SPOS + 2:W-NLEN) TO W-NAME
                 END-IF
                 PERFORM R720-FIND-VAR
                 IF W-FOUND = 0
                    PERFORM R336-MISSING-VAR
                 ELSE
                    IF W-VAR-VLEN(W-FOUND) > 0
                       MOVE W-VAR-VALUE(W-FOUND)
                            (1:W-VAR-VLEN(W-FOUND))
                         TO W-OUT(W-OPOS + 1:W-VAR-VLEN(W-FOUND))
                       ADD W-VAR-VLEN(W-FOUND) TO W-OPOS
                    END-IF
                    COMPUTE W-SPOS = W-E + 1
                 END-IF
              END-IF

              IF W-OPOS > 80
                 MOVE N'08' TO RETURNCODE OF P-LLWDM411
                 MOVE N'56' TO REASONCODE OF P-LLWDM411
                 MOVE W-T TO W-JOB-ED
                 MOVE W-LINENUM TO W-LINE-ED
                 STRING N'Job ' FUNCTION NATIONAL-OF(W-JOB-ED)
                        N' line ' FUNCTION NATIONAL-OF(W-LINE-ED)
                        N' is longer than 80 characters'
                        DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM411
              END-IF
           END-PERFORM

           IF RETURNCODE OF P-LLWDM411 = N'00'
              PERFORM UNTIL W-OPOS = 0
                         OR W-OUT(W-OPOS:1) NOT = SPACE
                 SUBTRACT 1 FROM W-OPOS
              END-PERFORM
              MOVE SPACES TO W-LINE-DATA(W-LINE-COUNT)
              MOVE W-OPOS TO W-LINE-LEN(W-LINE-COUNT)
              IF W-OPOS > 0
                 MOVE W-OUT(1:W-OPOS) TO W-LINE-DATA(W-LINE-COUNT)
              END-IF
           END-IF
           .
       R335-RESOLVE-LINE-END.
           EXIT.

      *===============================================================*
      * R336-MISSING-VAR: 08 57, naming the variable and the place    *
      *===============================================================*
       R336-MISSING-VAR SECTION.
           MOVE N'08' TO RETURNCODE OF P-LLWDM411
           MOVE N'57' TO REASONCODE OF P-LLWDM411
           MOVE W-T TO W-JOB-ED
           MOVE W-LINENUM TO W-LINE-ED
           STRING N'No value for ${' DELIMITED BY SIZE
                  W-NAME DELIMITED BY N' '
                  N'} in job ' FUNCTION NATIONAL-OF(W-JOB-ED)
                  N' line ' FUNCTION NATIONAL-OF(W-LINE-ED)
                  DELIMITED BY SIZE
             INTO INFOMESSAGE OF P-LLWDM411
           .
       R336-MISSING-VAR-END.
           EXIT.

      *===============================================================*
      * R340-INSERT-JOB: DEPLJOBS row W and its frozen JCL            *
      *===============================================================*
       R340-INSERT-JOB SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              EXEC SQL
                 INSERT INTO TBLWD012
                      ( DEPLID, JOBNO, TEMPLATEID, TEMPLATEREV,
                        JOBTITLE, MAXRC, JOBSTATUS, LINECOUNT,
                        LASTRUNID, SKIPREASON,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-DEPLID, :W-T, :W-CUR-ID,
                          :W-CUR-REV, :W-CUR-NAME,
                          :W-CUR-MAXRC, :C-W, :W-LINE-COUNT,
                          NULL, NULL,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT job' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF

           PERFORM VARYING W-L FROM 1 BY 1
                     UNTIL W-L > W-LINE-COUNT
                        OR RETURNCODE OF P-LLWDM411 NOT = N'00'
              MOVE W-LINE-TEXT(W-L) TO W-JL
              EXEC SQL
                 INSERT INTO TBLWD013
                      ( DEPLID, JOBNO, LINENUM, LINETEXT,
                        CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE )
                 VALUES ( :W-DEPLID, :W-T, :W-L, :W-JL,
                          :W-USERID, CURRENT TIMESTAMP,
                          :W-USERID, CURRENT TIMESTAMP )
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE N'INSERT JCL line' TO W-SQL-WHAT
                 MOVE N'12' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-PERFORM
           .
       R340-INSERT-JOB-END.
           EXIT.

      *===============================================================*
      * R500-ANSWER: The deployment as GET /deployments/{deplID}      *
      * returns it                                                    *
      *===============================================================*
       R500-ANSWER SECTION.
           IF RETURNCODE OF P-LLWDM411 = N'00'
              INITIALIZE W-LLWDM311
              MOVE W-DEPLID TO DEPLID OF W-LLWDM311
              MOVE 'LWDM311' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDM311

              MOVE CORRESPONDING LLWDM311 OF W-LLWDM311
                TO LLWDM411 OF P-LLWDM411

              IF  RETURNCODE OF P-LLWDM411 = N'00'
              AND W-STATUS = C-Q
              AND W-DUE = 'N'
                 MOVE N'Queued until its time and a free environment'
                   TO INFOMESSAGE OF P-LLWDM411
              END-IF
           END-IF
           .
       R500-ANSWER-END.
           EXIT.

      *===============================================================*
      * R700-ADD-VAR: Add W-ADD-NAME = W-ADD-VALUE unless the name is *
      * there already                                                 *
      *===============================================================*
       R700-ADD-VAR SECTION.
           MOVE W-ADD-NAME TO W-NAME
           PERFORM R720-FIND-VAR

           IF W-FOUND = 0
              IF W-VAR-COUNT >= 200
                 MOVE N'08' TO RETURNCODE OF P-LLWDM411
                 MOVE N'90' TO REASONCODE OF P-LLWDM411
                 MOVE N'More than 200 variables' TO
                      INFOMESSAGE OF P-LLWDM411
              ELSE
                 ADD 1 TO W-VAR-COUNT
                 MOVE W-ADD-NAME TO W-VAR-NAME(W-VAR-COUNT)
                 MOVE W-ADD-NLEN TO W-VAR-NLEN(W-VAR-COUNT)
                 MOVE W-ADD-VALUE TO W-VAR-VALUE(W-VAR-COUNT)
                 MOVE W-ADD-VLEN TO W-VAR-VLEN(W-VAR-COUNT)
              END-IF
           END-IF
           .
       R700-ADD-VAR-END.
           EXIT.

      *===============================================================*
      * R710-ADD-TRIMMED: R700-ADD-VAR, with the lengths of W-ADD-NAME*
      * and W-ADD-VALUE taken without trailing spaces                 *
      *===============================================================*
       R710-ADD-TRIMMED SECTION.
           MOVE 16 TO W-ADD-NLEN
           PERFORM UNTIL W-ADD-NLEN = 0
                      OR W-ADD-NAME(W-ADD-NLEN:1) NOT = SPACE
              SUBTRACT 1 FROM W-ADD-NLEN
           END-PERFORM

           MOVE 255 TO W-ADD-VLEN
           PERFORM UNTIL W-ADD-VLEN = 0
                      OR W-ADD-VALUE(W-ADD-VLEN:1) NOT = SPACE
              SUBTRACT 1 FROM W-ADD-VLEN
           END-PERFORM

           PERFORM R700-ADD-VAR
           .
       R710-ADD-TRIMMED-END.
           EXIT.

      *===============================================================*
      * R720-FIND-VAR: W-FOUND = index of W-NAME, 0 if not there      *
      *===============================================================*
       R720-FIND-VAR SECTION.
           MOVE 0 TO W-FOUND
           IF W-NAME NOT = SPACES
              PERFORM VARYING W-K FROM 1 BY 1
                        UNTIL W-K > W-VAR-COUNT OR W-FOUND > 0
                 IF W-VAR-NAME(W-K) = W-NAME
                    MOVE W-K TO W-FOUND
                 END-IF
              END-PERFORM
           END-IF
           .
       R720-FIND-VAR-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM411==.

           COPY LWDSECP.

           COPY LWDDEPP REPLACING ==:IO:== BY ==P-LLWDM411==.

           COPY LWDMALP REPLACING ==:IO:== BY ==P-LLWDM411==.

           COPY LWDSTRP REPLACING ==:IO:== BY ==P-LLWDM411==.

       END PROGRAM LWDM411.
