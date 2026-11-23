       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDM304.
      *===============================================================*
      * This program is a DB2 module of the LWD application.          *
      * GET /applications/{appID}: one application with the user's    *
      * roles in it (M1), for the application page of the web UI     *
      * (docs/09-iteration-5.md). Who may see it: a member, owner or  *
      * approver, or an administrator (R100-APP-ROLES); anyone else   *
      * gets 04 01, so the API doesn't reveal which applications      *
      * exist. ISAPPROVER: in the approver group of one of its        *
      * environments.                                                 *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Application not found, or no role in it               *
      * 08 21 = Error: SQL error in SELECT                            *
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

           COPY LWDCTXW.

       01 WORK.
          05 W-CREATED     PIC X(26).
          05 W-UPDATED     PIC X(26).

       LINKAGE SECTION.
       01 P-LLWDM304.
           COPY LLWDM304.

       PROCEDURE DIVISION USING P-LLWDM304.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R090-GET-USERID
           PERFORM R100-APP-ROLES
           PERFORM R105-REQUIRE-SEE

           IF RETURNCODE OF P-LLWDM304 = N'00'
              PERFORM R200-SELECT
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LLWDM304
           MOVE N'00' TO REASONCODE OF P-LLWDM304
           MOVE SPACES TO INFOMESSAGE OF P-LLWDM304

           MOVE APPID OF P-LLWDM304 TO W-APPID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R200-SELECT: The application                                  *
      *===============================================================*
       R200-SELECT SECTION.
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
              PERFORM R210-COPY
           WHEN 100
      *       Deleted between R100-APP-ROLES and here
              MOVE N'04' TO RETURNCODE OF P-LLWDM304
              MOVE N'01' TO REASONCODE OF P-LLWDM304
              MOVE N'Application not found' TO
                   INFOMESSAGE OF P-LLWDM304
           WHEN OTHER
              MOVE N'SELECT application' TO W-SQL-WHAT
              MOVE N'21' TO W-SQL-REASON
              PERFORM R890-SQL-ERROR
           END-EVALUATE
           .
       R200-SELECT-END.
           EXIT.

      *===============================================================*
      * R210-COPY: Copy the application and the roles                 *
      *===============================================================*
       R210-COPY SECTION.
           MOVE APPID OF DCLTBLWD004 TO APPID OF P-LLWDM304
           MOVE APPCODE OF DCLTBLWD004 TO APPCODE OF P-LLWDM304
           MOVE APPNAME OF DCLTBLWD004 TO APPNAME OF P-LLWDM304
           IF DESCRIPTION-IND OF DCLTBLWD004 >= 0
              MOVE DESCRIPTION OF DCLTBLWD004 TO
                   APPDESCRIPTION OF P-LLWDM304
           ELSE
              MOVE 0 TO APPDESCRIPTION-LEN OF P-LLWDM304
           END-IF
           MOVE ACCESSGROUP OF DCLTBLWD004 TO
                ACCESSGROUP OF P-LLWDM304
           MOVE OWNERGROUP OF DCLTBLWD004 TO OWNERGROUP OF P-LLWDM304
           MOVE FUNCTION NATIONAL-OF(W-IS-MEMBER) TO
                ISMEMBER OF P-LLWDM304
           MOVE FUNCTION NATIONAL-OF(W-IS-OWNER) TO
                ISOWNER OF P-LLWDM304
           MOVE FUNCTION NATIONAL-OF(W-IS-APPROVER) TO
                ISAPPROVER OF P-LLWDM304
           MOVE CREATEDBY OF DCLTBLWD004 TO CREATEDBY OF P-LLWDM304
           MOVE FUNCTION NATIONAL-OF(W-CREATED) TO
                CREATEDDATE OF P-LLWDM304
           MOVE UPDATEDBY OF DCLTBLWD004 TO UPDATEDBY OF P-LLWDM304
           MOVE FUNCTION NATIONAL-OF(W-UPDATED) TO
                UPDATEDDATE OF P-LLWDM304
           .
       R210-COPY-END.
           EXIT.

           COPY LWDCTXP REPLACING ==:IO:== BY ==P-LLWDM304==.

       END PROGRAM LWDM304.
