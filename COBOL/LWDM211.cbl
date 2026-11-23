       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM211.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /deployments: deployments, newest first (M3), for the     *
      * web UI (docs/09-iteration-5.md). Which rows:                  *
      * APPID given: R100-APP-ROLES decides.                          *
      *   Member, owner or administrator: every deployment of the     *
      *   application.                                                *
      *   Only approver: the deployments this user decided on (an     *
      *   APPROVALS row); those still waiting come from GET           *
      *   /approvalRequests.                                          *
      *   No role: 04 01, as for the application itself.              *
      * APPID 0: only with REQUESTEDBY-FILTER = the user's own        *
      *   userid, the own requests in every application. Anything     *
      *   else is 08 01: "every application I have a role in" is a    *
      *   FACILITY check per group, which static SQL can't filter on. *
      * Filters, all optional: ENVID-FILTER, VERSIONID-FILTER,        *
      * DEPLSTATUS-FILTER, REQUESTEDBY-FILTER, DEPLID-FILTER (one     *
      * deployment), and APPCODE-, ENVCODE- and VERSIONNAME-FILTER:   *
      * the code or name contains the text, in any case (all three    *
      * are stored in upper case); % and _ in it are LIKE wildcards.  *
      * DEPLID-SINCE: paging, entries before this ID (0 = start).     *
      * ADMINVIEW = Y (an LWW constant of GET /admin/deployments, A4):*
      *   administrators only; every deployment, APPID (from          *
      *   appID_filter) only filters, 0 is every application.        *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no deployments           *
      * 04 01 = Application not found, or no role in it               *
      * 08 01 = Error: no application, and not the own requests       *
      * 08 03 = Error: deplStatus_filter is not a status              *
      * 08 50 = Error: ADMINVIEW, and not an administrator            *
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

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           EXEC SQL INCLUDE TBLWD018 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-SINCE       PIC S9(9) COMP-5.
          05 W-ENVID       PIC S9(9) COMP-5.
          05 W-VERSIONID   PIC S9(9) COMP-5.
          05 W-STATUS      PIC N.
          05 W-REQBY       PIC N(8).
          05 W-BLANK8      PIC N(8) VALUE SPACES.
          05 W-DEPLID      PIC S9(9) COMP-5.
      *   LIKE patterns, '%text%', or '%' without a filter
          05 W-APPPAT.
             49 W-APPPAT-LEN    PIC S9(4) COMP-5.
             49 W-APPPAT-TEXT   PIC N(32).
          05 W-ENVPAT.
             49 W-ENVPAT-LEN    PIC S9(4) COMP-5.
             49 W-ENVPAT-TEXT   PIC N(32).
          05 W-VERPAT.
             49 W-VERPAT-LEN    PIC S9(4) COMP-5.
             49 W-VERPAT-TEXT   PIC N(32).
      *   In and out of R020-PATTERN
          05 W-PAT-IN      PIC N(30).
          05 W-PAT-L       PIC S9(4) COMP-5.
          05 W-PAT.
             49 W-PAT-LEN       PIC S9(4) COMP-5.
             49 W-PAT-TEXT      PIC N(32).
      *   Y: every deployment of the application; N: only the ones
      *   this user decided on
          05 W-ALL         PIC X.
          05 W-EOF         PIC X.
          05 W-N           PIC S9(4) COMP-5.
          05 W-STARTAFTER  PIC X(26).
          05 W-REQUESTED   PIC X(26).
          05 W-ENDED       PIC X(26).
          05 W-ENDED-IND   PIC S9(4) COMP-5.

       LINKAGE SECTION.
       01 P-LLWDM211.
           COPY LLWDM211.

       PROCEDURE DIVISION USING P-LLWDM211.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID
           PERFORM R150-WHICH-ROWS

           IF RETURNCODE OF P-LLWDM211 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations and the filters            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM211
           MOVE N'00' TO REASONCODE OF P-LLWDM211
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM211

           MOVE 0 TO DEP-COUNT OF P-LLWDM211
           MOVE APPID OF P-LLWDM211 TO W-APPID
           MOVE DEPLID-SINCE OF P-LLWDM211 TO W-SINCE
           MOVE ENVID-FILTER OF P-LLWDM211 TO W-ENVID
           MOVE VERSIONID-FILTER OF P-LLWDM211 TO W-VERSIONID
           MOVE DEPLSTATUS-FILTER OF P-LLWDM211 TO W-STATUS
           MOVE REQUESTEDBY-FILTER OF P-LLWDM211 TO W-REQBY
           MOVE DEPLID-FILTER OF P-LLWDM211 TO W-DEPLID

           MOVE APPCODE-FILTER OF P-LLWDM211 TO W-PAT-IN
           PERFORM R020-PATTERN
           MOVE W-PAT TO W-APPPAT
           MOVE ENVCODE-FILTER OF P-LLWDM211 TO W-PAT-IN
           PERFORM R020-PATTERN
           MOVE W-PAT TO W-ENVPAT
           MOVE VERSIONNAME-FILTER OF P-LLWDM211 TO W-PAT-IN
           PERFORM R020-PATTERN
           MOVE W-PAT TO W-VERPAT

      *    A missing optional field arrives as binary zeros
           IF W-STATUS = NX'0000'
              MOVE SPACE TO W-STATUS
           END-IF
           IF W-REQBY(1:1) = NX'0000'
              MOVE SPACES TO W-REQBY
           END-IF
           MOVE FUNCTION UPPER-CASE(W-STATUS) TO W-STATUS
           MOVE FUNCTION UPPER-CASE(W-REQBY) TO W-REQBY

           IF  W-STATUS NOT = SPACE
           AND W-STATUS NOT = C-W AND W-STATUS NOT = C-J
           AND W-STATUS NOT = C-E AND W-STATUS NOT = C-Q
           AND W-STATUS NOT = C-U AND W-STATUS NOT = C-F
           AND W-STATUS NOT = C-S AND W-STATUS NOT = C-C
              MOVE N'08' TO RETURNCODE OF P-LLWDM211
              MOVE N'03' TO REASONCODE OF P-LLWDM211
              MOVE N'deplStatus_filter is not a deployment status' TO
                   INFOMESSAGE OF P-LLWDM211
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R020-PATTERN: W-PAT-IN, a filter text, into the LIKE pattern  *
      * W-PAT: '%TEXT%' in upper case, or '%' when it is empty        *
      *===============================================================*
       R020-PATTERN SECTION.
      *    A missing optional field arrives as binary zeros
           INSPECT W-PAT-IN REPLACING ALL NX'0000' BY SPACE
           MOVE FUNCTION UPPER-CASE(W-PAT-IN) TO W-PAT-IN

           MOVE 30 TO W-PAT-L
           PERFORM UNTIL W-PAT-L < 1
              IF W-PAT-IN(W-PAT-L:1) = SPACE
                 SUBTRACT 1 FROM W-PAT-L
              ELSE
                 EXIT PERFORM
              END-IF
           END-PERFORM

           MOVE SPACES TO W-PAT-TEXT
           IF W-PAT-L < 1
              MOVE N'%' TO W-PAT-TEXT
              MOVE 1 TO W-PAT-LEN
           ELSE
              STRING N'%' W-PAT-IN(1:W-PAT-L) N'%'
                     DELIMITED BY SIZE
                INTO W-PAT-TEXT
              COMPUTE W-PAT-LEN = W-PAT-L + 2
           END-IF
           .
       R020-PATTERN-END.
           EXIT.

      *===============================================================*
      * R150-WHICH-ROWS: W-ALL for an administrator's view, from the  *
      * roles in the application, or the own requests without one     *
      *===============================================================*
       R150-WHICH-ROWS SECTION.
           EVALUATE TRUE
           WHEN RETURNCODE OF P-LLWDM211 NOT = N'00'
              CONTINUE
           WHEN ADMINVIEW OF P-LLWDM211 = C-Y
              PERFORM R098-REQUIRE-ADMIN
              MOVE 'Y' TO W-ALL
           WHEN W-APPID > 0
              PERFORM R100-APP-ROLES
              PERFORM R105-REQUIRE-SEE
              IF  W-IS-MEMBER = 'Y' OR W-IS-OWNER = 'Y'
               OR W-IS-ADMIN = 'Y'
                 MOVE 'Y' TO W-ALL
              ELSE
                 MOVE 'N' TO W-ALL
              END-IF
           WHEN W-REQBY = W-USERID
              MOVE 'Y' TO W-ALL
           WHEN OTHER
              MOVE N'08' TO RETURNCODE OF P-LLWDM211
              MOVE N'01' TO REASONCODE OF P-LLWDM211
              MOVE N'Without appID only own requests are listed'
                TO INFOMESSAGE OF P-LLWDM211
           END-EVALUATE
           .
       R150-WHICH-ROWS-END.
           EXIT.

      *===============================================================*
      * R200-LIST: Up to 20 deployments, newest first                 *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT D.DEPLID,
                     D.APPID,
                     A.APPCODE,
                     D.ENVID,
                     E.ENVCODE,
                     D.VERSIONID,
                     V.VERSIONNAME,
                     D.DEPLSTATUS,
                     CHAR(D.STARTAFTER),
                     D.CREATEDBY,
                     CHAR(D.CREATEDDATE),
                     CHAR(D.ENDEDDATE)
                FROM TBLWD011 D
                JOIN TBLWD004 A
                  ON A.APPID = D.APPID
                JOIN TBLWD006 E
                  ON E.ENVID = D.ENVID
                JOIN TBLWD005 V
                  ON V.VERSIONID = D.VERSIONID
               WHERE (:W-APPID = 0 OR D.APPID = :W-APPID)
                 AND (:W-ALL = 'Y'
                  OR  EXISTS
                     (SELECT 1
                        FROM TBLWD018 X
                       WHERE X.DEPLID = D.DEPLID
                         AND X.USERID = :W-USERID))
                 AND (:W-SINCE = 0 OR D.DEPLID < :W-SINCE)
                 AND (:W-ENVID = 0 OR D.ENVID = :W-ENVID)
                 AND (:W-VERSIONID = 0 OR D.VERSIONID = :W-VERSIONID)
                 AND (:W-STATUS = :C-BLANK
                  OR  D.DEPLSTATUS = :W-STATUS)
                 AND (:W-REQBY = :W-BLANK8
                  OR  D.CREATEDBY = :W-REQBY)
                 AND (:W-DEPLID = 0 OR D.DEPLID = :W-DEPLID)
                 AND A.APPCODE LIKE :W-APPPAT
                 AND E.ENVCODE LIKE :W-ENVPAT
                 AND V.VERSIONNAME LIKE :W-VERPAT
               ORDER BY D.DEPLID DESC
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
                         OR RETURNCODE OF P-LLWDM211 NOT = N'00'
                         OR DEP-COUNT OF P-LLWDM211 >= 20
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
      * R210-FETCH: One deployment                                    *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD011.DEPLID,
                    :DCLTBLWD011.APPID,
                    :DCLTBLWD004.APPCODE,
                    :DCLTBLWD011.ENVID,
                    :DCLTBLWD006.ENVCODE,
                    :DCLTBLWD011.VERSIONID,
                    :DCLTBLWD005.VERSIONNAME,
                    :DCLTBLWD011.DEPLSTATUS,
                    :W-STARTAFTER,
                    :DCLTBLWD011.CREATEDBY,
                    :W-REQUESTED,
                    :W-ENDED :W-ENDED-IND
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO DEP-COUNT OF P-LLWDM211
              MOVE DEP-COUNT OF P-LLWDM211 TO W-N
              PERFORM R220-COPY
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

      *===============================================================*
      * R220-COPY: Copy the fetched deployment                        *
      *===============================================================*
       R220-COPY SECTION.
           MOVE DEPLID OF DCLTBLWD011 TO DEPLID OF P-LLWDM211(W-N)
           MOVE APPID OF DCLTBLWD011 TO DEP-APPID OF P-LLWDM211(W-N)
           MOVE APPCODE OF DCLTBLWD004 TO APPCODE OF P-LLWDM211(W-N)
           MOVE ENVID OF DCLTBLWD011 TO ENVID OF P-LLWDM211(W-N)
           MOVE ENVCODE OF DCLTBLWD006 TO ENVCODE OF P-LLWDM211(W-N)
           MOVE VERSIONID OF DCLTBLWD011 TO
                VERSIONID OF P-LLWDM211(W-N)
           MOVE VERSIONNAME OF DCLTBLWD005 TO
                VERSIONNAME OF P-LLWDM211(W-N)
           MOVE DEPLSTATUS OF DCLTBLWD011 TO
                DEPLSTATUS OF P-LLWDM211(W-N)
           MOVE FUNCTION NATIONAL-OF(W-STARTAFTER) TO
                STARTAFTER OF P-LLWDM211(W-N)
           MOVE CREATEDBY OF DCLTBLWD011 TO
                REQUESTEDBY OF P-LLWDM211(W-N)
           MOVE FUNCTION NATIONAL-OF(W-REQUESTED) TO
                REQUESTEDDATE OF P-LLWDM211(W-N)
           IF W-ENDED-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-ENDED) TO
                   ENDEDDATE OF P-LLWDM211(W-N)
           ELSE
              MOVE SPACES TO ENDEDDATE OF P-LLWDM211(W-N)
           END-IF
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM211==.

       END PROGRAM LWDM211.
