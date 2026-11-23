       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM002.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * PUT /me (U2), by OPCODE U (an LWW constant): the signed-in    *
      * user's own notification settings, each Y or N:                *
      *   NOTIFYAPPROVE: mail when an approval waits for me           *
      *   NOTIFYOWN:     mail when my deployment is decided or ends   *
      *   NOTIFYAPP:     mail when a deployment of an application I   *
      *                  own ends                                     *
      * The email address isn't changed here: the daily job LWDMAIL   *
      * copies it from RACF (docs/11-iteration-7.md). The answer is   *
      * GET /me, from LWDM302, which also creates the user row when   *
      * this is the user's first call.                                *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: a setting that isn't Y or N                    *
      * 08 32 = Error: SQL error in UPDATE                            *
      * And the codes of LWDM302 and LWDCTXP                          *
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

           COPY LWDCTXW.

       01 WORK.
          05 W-PGMNAME     PIC X(8).
          05 W-I           PIC S9(4) COMP-5.
          05 W-FIELD       PIC N(13).
          05 W-VALUE       PIC N.

      *   By name for SQL, as a table for the check
       01 W-SETTINGS.
          05 W-SET-APPROVE PIC N.
          05 W-SET-OWN     PIC N.
          05 W-SET-APP     PIC N.
       01 W-SET-TAB REDEFINES W-SETTINGS.
          05 W-SET         PIC N OCCURS 3.

       01 W-LLWDM302.
           COPY LLWDM302.

       LINKAGE SECTION.
       01 P-LLWDM002.
           COPY LLWDM002.

       PROCEDURE DIVISION USING P-LLWDM002.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF  RETURNCODE OF P-LLWDM002 = N'00'
           AND OPCODE OF P-LLWDM002 NOT = C-U
              MOVE N'08' TO RETURNCODE OF P-LLWDM002
              MOVE N'01' TO REASONCODE OF P-LLWDM002
              MOVE N'Invalid OPCODE' TO INFOMESSAGE OF P-LLWDM002
           END-IF

           PERFORM R200-VALIDATE
           PERFORM R300-ANSWER-FIRST
           PERFORM R400-UPDATE
           PERFORM R300-ANSWER-FIRST
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM002
           MOVE N'00' TO REASONCODE OF P-LLWDM002
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM002

           MOVE NOTIFYAPPROVE OF P-LLWDM002 TO W-SET-APPROVE
           MOVE NOTIFYOWN OF P-LLWDM002 TO W-SET-OWN
           MOVE NOTIFYAPP OF P-LLWDM002 TO W-SET-APP
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-VALIDATE: Each setting Y or N; a missing one arrives as  *
      * binary zeros and is refused too                               *
      *===============================================================*
       R200-VALIDATE SECTION.
           PERFORM VARYING W-I FROM 1 BY 1
                     UNTIL W-I > 3
                        OR RETURNCODE OF P-LLWDM002 NOT = N'00'
              MOVE FUNCTION UPPER-CASE(W-SET(W-I)) TO W-SET(W-I)
              IF W-SET(W-I) NOT = C-Y AND W-SET(W-I) NOT = C-N
                 EVALUATE W-I
                 WHEN 1
                    MOVE N'notifyApprove' TO W-FIELD
                 WHEN 2
                    MOVE N'notifyOwn' TO W-FIELD
                 WHEN OTHER
                    MOVE N'notifyApp' TO W-FIELD
                 END-EVALUATE
                 MOVE N'08' TO RETURNCODE OF P-LLWDM002
                 MOVE N'02' TO REASONCODE OF P-LLWDM002
                 STRING W-FIELD DELIMITED BY N' '
                        N': Y or N' DELIMITED BY SIZE
                   INTO INFOMESSAGE OF P-LLWDM002
              END-IF
           END-PERFORM
           .
       R200-VALIDATE-END.
           EXIT.

      *===============================================================*
      * R300-ANSWER-FIRST: GET /me (LWDM302). Before the update it    *
      * makes sure the user row exists; after it, it is the answer    *
      *===============================================================*
       R300-ANSWER-FIRST SECTION.
           IF RETURNCODE OF P-LLWDM002 = N'00'
              INITIALIZE W-LLWDM302
              MOVE 'LWDM302' TO W-PGMNAME
              CALL W-PGMNAME USING W-LLWDM302

              MOVE RETURNCODE OF W-LLWDM302 TO
                   RETURNCODE OF P-LLWDM002
              MOVE REASONCODE OF W-LLWDM302 TO
                   REASONCODE OF P-LLWDM002
              MOVE INFOMESSAGE OF W-LLWDM302 TO
                   INFOMESSAGE OF P-LLWDM002
              MOVE USERID OF W-LLWDM302 TO USERID OF P-LLWDM002
              MOVE EMAIL OF W-LLWDM302 TO EMAIL OF P-LLWDM002
              MOVE NOTIFYAPPROVE OF W-LLWDM302 TO
                   NOTIFYAPPROVE OF P-LLWDM002
              MOVE NOTIFYOWN OF W-LLWDM302 TO NOTIFYOWN OF P-LLWDM002
              MOVE NOTIFYAPP OF W-LLWDM302 TO NOTIFYAPP OF P-LLWDM002
              MOVE ISADMIN OF W-LLWDM302 TO ISADMIN OF P-LLWDM002
              MOVE APPROVALSWAITING OF W-LLWDM302 TO
                   APPROVALSWAITING OF P-LLWDM002
           END-IF
           .
       R300-ANSWER-FIRST-END.
           EXIT.

      *===============================================================*
      * R400-UPDATE: The three settings of the own row                *
      *===============================================================*
       R400-UPDATE SECTION.
           IF RETURNCODE OF P-LLWDM002 = N'00'
              EXEC SQL
                 UPDATE TBLWD002
                    SET NOTIFYAPPROVE = :W-SET-APPROVE,
                        NOTIFYOWN     = :W-SET-OWN,
                        NOTIFYAPP     = :W-SET-APP,
                        UPDATEDBY     = :W-USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE USERID = :W-USERID
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE N'UPDATE user' TO W-SQL-WHAT
                 MOVE N'32' TO W-SQL-REASON
                 PERFORM R890-SQL-ERROR
              END-IF
           END-IF
           .
       R400-UPDATE-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM002==.

       END PROGRAM LWDM002.
