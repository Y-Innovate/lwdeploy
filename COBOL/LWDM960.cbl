       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM960.
      *===============================================================*
      * This program is a DB2 batch program of the LWD application:   *
      * steps MAILLIST and MAILLOAD of JCL/LWDMAIL, the daily refresh *
      * of the email addresses from RACF (S4 step 5, M8,              *
      * docs/11-iteration-7.md). REXX LWDR961 runs between the two.   *
      * PARM LIST: every userid of USERS to DD USERLIST.              *
      * PARM LOAD: the addresses of DD USERMAIL into USERS.EMAIL, a   *
      *   row only updated when its address changed, a commit every   *
      *   100 rows. Status F: the address (one without @ or with a    *
      *   blank counts as none); N: none in RACF, EMAIL becomes NULL; *
      *   X: LWDR961 couldn't read it, EMAIL stays as it is.          *
      * Static SQL, so the userid only needs the plan. Linked with    *
      * DSNELI: run it with DSN RUN under IKJEFT1B, PARMS('LIST') or  *
      * PARMS('LOAD'): no slash before them, as for COBOL LE takes    *
      * what comes before a slash as the program's argument.          *
      * ------------------------------------------------------------- *
      * DD USERLIST: RECFM=FB,LRECL=80, col 1-8 userid                *
      * DD USERMAIL: RECFM=FB,LRECL=300, col 1-8 userid, col 10       *
      *   status F, N or X, col 12-265 the address                    *
      * RETURN-CODE:                                                  *
      *  0 = Done                                                     *
      *  8 = Invalid PARM or input, or an error, see SYSOUT; LOAD     *
      *      keeps what it committed before                           *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT USERLIST ASSIGN TO USERLIST
                  FILE STATUS IS W-FS.
           SELECT USERMAIL ASSIGN TO USERMAIL
                  FILE STATUS IS W-FS.

       DATA DIVISION.
       FILE SECTION.
       FD USERLIST
           RECORDING MODE F.
       01 USERLIST-REC    PIC X(80).
       FD USERMAIL
           RECORDING MODE F.
       01 USERMAIL-REC.
          05 UM-USERID    PIC X(8).
          05 FILLER       PIC X.
          05 UM-STATUS    PIC X.
          05 FILLER       PIC X.
          05 UM-EMAIL     PIC X(254).
          05 FILLER       PIC X(35).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBLWD001 END-EXEC.

           EXEC SQL INCLUDE TBLWD002 END-EXEC.

           COPY LWDCTXW.

       01 W-IO.
          05 RETURNCODE      PIC N(02).
          05 REASONCODE      PIC N(02).
          05 INFOMESSAGE     PIC N(72).

       01 WORK.
          05 C-COMMIT        PIC S9(4) COMP-5 VALUE 100.
          05 W-FS            PIC XX.
          05 W-RC            PIC S9(4) COMP-5 VALUE 0.
          05 W-MODE          PIC X(4).
          05 W-EOF           PIC X.
          05 W-UID           PIC N(8).
          05 W-LEN           PIC S9(4) COMP-5.
          05 W-T             PIC S9(4) COMP-5.
          05 W-SINCE-COMMIT  PIC S9(4) COMP-5 VALUE 0.
          05 W-LISTED        PIC S9(9) COMP-5 VALUE 0.
          05 W-READ          PIC S9(9) COMP-5 VALUE 0.
          05 W-CHANGED       PIC S9(9) COMP-5 VALUE 0.
          05 W-SKIPPED       PIC S9(9) COMP-5 VALUE 0.
          05 W-CNT-ED        PIC Z(8)9.
          05 W-OUT.
             10 W-OUT-USERID PIC X(8).
             10 FILLER       PIC X(72) VALUE SPACES.
          05 W-EMAIL.
             49 W-EMAIL-LEN  PIC S9(4) COMP-5.
             49 W-EMAIL-TEXT PIC N(254).

       LINKAGE SECTION.
       01 P-PARM.
          05 P-PARM-LEN      PIC S9(4) COMP.
          05 P-PARM-TEXT     PIC X(8).

       PROCEDURE DIVISION USING P-PARM.
       MAIN SECTION.
           MOVE N'00' TO RETURNCODE OF W-IO
           MOVE N'00' TO REASONCODE OF W-IO
           MOVE SPACES TO INFOMESSAGE OF W-IO

           MOVE SPACES TO W-MODE
           IF P-PARM-LEN >= 4
              MOVE P-PARM-TEXT(1:4) TO W-MODE
           END-IF

           PERFORM R090-GET-USERID

           IF RETURNCODE OF W-IO = N'00'
              EVALUATE W-MODE
              WHEN 'LIST'
                 PERFORM R100-LIST
              WHEN 'LOAD'
                 PERFORM R200-LOAD
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF W-IO
                 MOVE N'01' TO REASONCODE OF W-IO
                 MOVE N'PARM must be LIST or LOAD' TO
                      INFOMESSAGE OF W-IO
              END-EVALUATE
           END-IF

           IF RETURNCODE OF W-IO NOT = N'00'
              DISPLAY 'LWDM960 '
                      FUNCTION DISPLAY-OF(RETURNCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(REASONCODE OF W-IO) ' '
                      FUNCTION DISPLAY-OF(INFOMESSAGE OF W-IO)
              MOVE 8 TO W-RC
              EXEC SQL ROLLBACK END-EXEC
           ELSE
              EXEC SQL COMMIT END-EXEC
           END-IF

           IF W-MODE = 'LIST'
              MOVE W-LISTED TO W-CNT-ED
              DISPLAY 'LWDM960 USERIDS LISTED:     ' W-CNT-ED
           ELSE
              MOVE W-READ TO W-CNT-ED
              DISPLAY 'LWDM960 USERIDS READ:       ' W-CNT-ED
              MOVE W-CHANGED TO W-CNT-ED
              DISPLAY 'LWDM960 ADDRESSES CHANGED:  ' W-CNT-ED
              MOVE W-SKIPPED TO W-CNT-ED
              DISPLAY 'LWDM960 NOT READ FROM RACF: ' W-CNT-ED
           END-IF

           MOVE W-RC TO RETURN-CODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R100-LIST: Every userid of USERS to USERLIST                  *
      *===============================================================*
       R100-LIST SECTION.
           OPEN OUTPUT USERLIST
           IF W-FS NOT = '00'
              DISPLAY 'LWDM960 OPEN USERLIST FILE STATUS ' W-FS
              MOVE N'08' TO RETURNCODE OF W-IO
              MOVE N'90' TO REASONCODE OF W-IO
              MOVE N'OPEN USERLIST failed' TO INFOMESSAGE OF W-IO
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              EXEC SQL
                 DECLARE C1 CURSOR FOR
                 SELECT USERID
                   FROM TBLWD002
                  ORDER BY USERID
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
                            OR RETURNCODE OF W-IO NOT = N'00'
                    EXEC SQL
                       FETCH C1 INTO :W-UID
                    END-EXEC
                    EVALUATE SQLCODE
                    WHEN 0
                       MOVE FUNCTION DISPLAY-OF(W-UID) TO W-OUT-USERID
                       WRITE USERLIST-REC FROM W-OUT
                       IF W-FS NOT = '00'
                          DISPLAY 'LWDM960 WRITE USERLIST FILE STATUS '
                                  W-FS
                          MOVE N'08' TO RETURNCODE OF W-IO
                          MOVE N'90' TO REASONCODE OF W-IO
                          MOVE N'WRITE USERLIST failed' TO
                               INFOMESSAGE OF W-IO
                       ELSE
                          ADD 1 TO W-LISTED
                       END-IF
                    WHEN 100
                       MOVE 'Y' TO W-EOF
                    WHEN OTHER
                       MOVE N'FETCH CURSOR' TO W-SQL-WHAT
                       MOVE N'21' TO W-SQL-REASON
                       PERFORM R890-SQL-ERROR
                    END-EVALUATE
                 END-PERFORM

                 EXEC SQL
                    CLOSE C1
                 END-EXEC
              END-IF
              CLOSE USERLIST
           END-IF
           .
       R100-LIST-END.
           EXIT.

      *===============================================================*
      * R200-LOAD: The addresses of USERMAIL into USERS               *
      *===============================================================*
       R200-LOAD SECTION.
           OPEN INPUT USERMAIL
           IF W-FS NOT = '00'
              DISPLAY 'LWDM960 OPEN USERMAIL FILE STATUS ' W-FS
              MOVE N'08' TO RETURNCODE OF W-IO
              MOVE N'90' TO REASONCODE OF W-IO
              MOVE N'OPEN USERMAIL failed' TO INFOMESSAGE OF W-IO
           END-IF

           IF RETURNCODE OF W-IO = N'00'
              MOVE 'N' TO W-EOF
              PERFORM UNTIL W-EOF = 'Y'
                         OR RETURNCODE OF W-IO NOT = N'00'
                 READ USERMAIL
                 EVALUATE W-FS
                 WHEN '00'
                    ADD 1 TO W-READ
                    PERFORM R210-ONE-USER
                 WHEN '10'
                    MOVE 'Y' TO W-EOF
                 WHEN OTHER
                    DISPLAY 'LWDM960 READ USERMAIL FILE STATUS ' W-FS
                    MOVE N'08' TO RETURNCODE OF W-IO
                    MOVE N'90' TO REASONCODE OF W-IO
                    MOVE N'READ USERMAIL failed' TO
                         INFOMESSAGE OF W-IO
                 END-EVALUATE
              END-PERFORM
              CLOSE USERMAIL
           END-IF
           .
       R200-LOAD-END.
           EXIT.

      *===============================================================*
      * R210-ONE-USER: One record; X leaves the address alone         *
      *===============================================================*
       R210-ONE-USER SECTION.
           MOVE FUNCTION NATIONAL-OF(UM-USERID) TO W-UID

      *    The address without trailing blanks; one without @ or with
      *    a blank inside counts as none
           IF UM-STATUS = 'F'
              MOVE 254 TO W-LEN
              MOVE 0 TO W-T
              PERFORM UNTIL W-LEN = 0
                 IF UM-EMAIL(W-LEN:1) = SPACE
                    SUBTRACT 1 FROM W-LEN
                 ELSE
                    MOVE W-LEN TO W-T
                    MOVE 0 TO W-LEN
                 END-IF
              END-PERFORM
              MOVE W-T TO W-LEN
              MOVE 0 TO W-T
              IF W-LEN > 0
                 INSPECT UM-EMAIL(1:W-LEN) TALLYING W-T FOR ALL '@'
              END-IF
              IF W-LEN = 0 OR W-T = 0
                 MOVE 'N' TO UM-STATUS
              ELSE
                 MOVE 0 TO W-T
                 INSPECT UM-EMAIL(1:W-LEN) TALLYING W-T FOR ALL SPACE
                 IF W-T > 0
                    DISPLAY 'LWDM960 ' UM-USERID ' ADDRESS WITH A BLANK'
                    MOVE 'N' TO UM-STATUS
                 END-IF
              END-IF
           END-IF

           EVALUATE UM-STATUS
           WHEN 'F'
              MOVE FUNCTION NATIONAL-OF(UM-EMAIL(1:W-LEN)) TO
                   W-EMAIL-TEXT
              MOVE W-LEN TO W-EMAIL-LEN
              EXEC SQL
                 UPDATE TBLWD002
                    SET EMAIL       = :W-EMAIL,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE USERID = :W-UID
                    AND (EMAIL IS NULL OR EMAIL <> :W-EMAIL)
              END-EXEC
              PERFORM R220-COUNT
           WHEN 'N'
              EXEC SQL
                 UPDATE TBLWD002
                    SET EMAIL       = NULL,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE USERID = :W-UID
                    AND EMAIL IS NOT NULL
              END-EXEC
              PERFORM R220-COUNT
           WHEN OTHER
              ADD 1 TO W-SKIPPED
           END-EVALUATE
           .
       R210-ONE-USER-END.
           EXIT.

      *===============================================================*
      * R220-COUNT: After an UPDATE; a commit every 100 changes       *
      *===============================================================*
       R220-COUNT SECTION.
           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO W-CHANGED
              ADD 1 TO W-SINCE-COMMIT
              IF W-SINCE-COMMIT >= C-COMMIT
                 EXEC SQL COMMIT END-EXEC
                 MOVE 0 TO W-SINCE-COMMIT
              END-IF
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE N'UPDATE user' TO W-SQL-WHAT
              MOVE N'32' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R220-COUNT-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==W-IO==.

       END PROGRAM LWDM960.
