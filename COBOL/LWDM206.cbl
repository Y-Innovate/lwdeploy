       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM206.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /environments?appID=: the environments of an application  *
      * in order, with the inventory (M1, M2, O1). At most 20, so no  *
      * paging. CANDEPLOY and CANAPPROVE are checked live per         *
      * environment: they tell the UI what to show, D1 and AP2 check  *
      * again.                                                        *
      * CANDEPLOY = member, a deploy userid is set, and in the        *
      *             deployer group when the environment has one       *
      * CANAPPROVE = approval required and in the approver group      *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Application not found, or no role in it               *
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

           EXEC SQL INCLUDE TBLWD006 END-EXEC.

           EXEC SQL INCLUDE TBLWD005 END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           EXEC SQL INCLUDE TBLWD003 END-EXEC.

           EXEC SQL INCLUDE TBLWD004 END-EXEC.

           EXEC SQL INCLUDE TBLWD011 END-EXEC.

           COPY LWDCTXW.

       01 WORK.
          05 W-EOF          PIC X.
          05 W-N            PIC S9(4) COMP-5.
          05 W-DEPLOYEDDATE PIC X(26).
          05 W-DEPLOYEDDATE-IND PIC S9(4) COMP-5.
          05 W-VNAME-IND    PIC S9(4) COMP-5.
          05 W-FLAG         PIC X.

       LINKAGE SECTION.
       01 P-LLWDM206.
           COPY LLWDM206.

       PROCEDURE DIVISION USING P-LLWDM206.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           IF RETURNCODE OF P-LLWDM206 = N'00'
              PERFORM R200-LIST
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM206
           MOVE N'00' TO REASONCODE OF P-LLWDM206
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM206

           MOVE 0 TO ENV-COUNT OF P-LLWDM206
           MOVE APPID OF P-LLWDM206 TO W-APPID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-LIST: The environments with their current version        *
      *===============================================================*
       R200-LIST SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT E.ENVID,
                     E.ENVCODE,
                     E.ENVNAME,
                     E.SORTORDER,
                     E.PROMOGATE,
                     E.APPROVALREQ,
                     E.APPROVALCOUNT,
                     E.ENVSTATE,
                     COALESCE(E.CURRENTVERSIONID, 0),
                     V.VERSIONNAME,
                     COALESCE(E.CURRENTDEPLID, 0),
                     CHAR(D.ENDEDDATE),
                     COALESCE(E.ACTIVEDEPLID, 0),
                     E.DEPLOYUSER,
                     E.APPROVERGROUP,
                     E.DEPLOYERGROUP
                FROM TBLWD006 E
                LEFT JOIN TBLWD005 V
                  ON V.VERSIONID = E.CURRENTVERSIONID
                LEFT JOIN TBLWD011 D
                  ON D.DEPLID = E.CURRENTDEPLID
               WHERE E.APPID = :W-APPID
               ORDER BY E.SORTORDER, E.ENVID
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
                         OR RETURNCODE OF P-LLWDM206 NOT = N'00'
                         OR ENV-COUNT OF P-LLWDM206 >= 20
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
      * R210-FETCH: One environment                                   *
      *===============================================================*
       R210-FETCH SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBLWD006.ENVID,
                    :DCLTBLWD006.ENVCODE,
                    :DCLTBLWD006.ENVNAME,
                    :DCLTBLWD006.SORTORDER,
                    :DCLTBLWD006.PROMOGATE,
                    :DCLTBLWD006.APPROVALREQ,
                    :DCLTBLWD006.APPROVALCOUNT,
                    :DCLTBLWD006.ENVSTATE,
                    :DCLTBLWD006.CURRENTVERSIONID,
                    :DCLTBLWD005.VERSIONNAME :W-VNAME-IND,
                    :DCLTBLWD006.CURRENTDEPLID,
                    :W-DEPLOYEDDATE :W-DEPLOYEDDATE-IND,
                    :DCLTBLWD006.ACTIVEDEPLID,
                    :DCLTBLWD006.DEPLOYUSER
                       :DCLTBLWD006.DEPLOYUSER-IND,
                    :DCLTBLWD006.APPROVERGROUP
                       :DCLTBLWD006.APPROVERGROUP-IND,
                    :DCLTBLWD006.DEPLOYERGROUP
                       :DCLTBLWD006.DEPLOYERGROUP-IND
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO ENV-COUNT OF P-LLWDM206
              MOVE ENV-COUNT OF P-LLWDM206 TO W-N
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
      * R220-COPY: Copy the fetched environment and work out the      *
      * flags for the UI                                              *
      *===============================================================*
       R220-COPY SECTION.
           MOVE ENVID OF DCLTBLWD006 TO ENVID OF P-LLWDM206(W-N)
           MOVE ENVCODE OF DCLTBLWD006 TO ENVCODE OF P-LLWDM206(W-N)
           MOVE ENVNAME OF DCLTBLWD006 TO ENVNAME OF P-LLWDM206(W-N)
           MOVE SORTORDER OF DCLTBLWD006 TO
                SORTORDER OF P-LLWDM206(W-N)
           MOVE PROMOGATE OF DCLTBLWD006 TO
                PROMOGATE OF P-LLWDM206(W-N)
           MOVE APPROVALREQ OF DCLTBLWD006 TO
                APPROVALREQ OF P-LLWDM206(W-N)
           MOVE APPROVALCOUNT OF DCLTBLWD006 TO
                APPROVALCOUNT OF P-LLWDM206(W-N)
           MOVE ENVSTATE OF DCLTBLWD006 TO ENVSTATE OF P-LLWDM206(W-N)
           MOVE CURRENTVERSIONID OF DCLTBLWD006 TO
                CURRENTVERSIONID OF P-LLWDM206(W-N)
           IF W-VNAME-IND >= 0
              MOVE VERSIONNAME OF DCLTBLWD005 TO
                   CURRENTVERSIONNAME OF P-LLWDM206(W-N)
           ELSE
              MOVE 0 TO CURRENTVERSIONNAME-LEN OF P-LLWDM206(W-N)
           END-IF
           MOVE CURRENTDEPLID OF DCLTBLWD006 TO
                CURRENTDEPLID OF P-LLWDM206(W-N)
           IF W-DEPLOYEDDATE-IND >= 0
              MOVE FUNCTION NATIONAL-OF(W-DEPLOYEDDATE) TO
                   DEPLOYEDDATE OF P-LLWDM206(W-N)
           ELSE
              MOVE SPACES TO DEPLOYEDDATE OF P-LLWDM206(W-N)
           END-IF
           MOVE ACTIVEDEPLID OF DCLTBLWD006 TO
                ACTIVEDEPLID OF P-LLWDM206(W-N)

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
           MOVE FUNCTION NATIONAL-OF(W-FLAG) TO
                CANDEPLOY OF P-LLWDM206(W-N)

      *    Can approve: approval required and in the approver group
           MOVE 'N' TO W-FLAG
           IF  APPROVALREQ OF DCLTBLWD006 = C-Y
           AND APPROVERGROUP-IND OF DCLTBLWD006 >= 0
              MOVE APPROVERGROUP OF DCLTBLWD006 TO W-GROUP
              PERFORM R096-CHECK-GROUP
              MOVE W-IN-GROUP TO W-FLAG
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-FLAG) TO
                CANAPPROVE OF P-LLWDM206(W-N)
           .
       R220-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM206==.

       END PROGRAM LWDM206.
