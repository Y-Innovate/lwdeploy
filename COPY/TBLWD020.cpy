      ******************************************************************
      * DCLGEN TABLE(TBLWD020)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD020 TABLE
           ( MAILID                         INTEGER NOT NULL,
             USERID                         GRAPHIC(8) NOT NULL,
             EMAIL                          VARGRAPHIC(254) NOT NULL,
             DEPLID                         INTEGER,
             MAILTYPE                       GRAPHIC(1) NOT NULL,
             SUBJECT                        VARGRAPHIC(100) NOT NULL,
             BODY                           VARGRAPHIC(1000) NOT NULL,
             MAILSTATUS                     GRAPHIC(1) NOT NULL,
             ATTEMPTS                       SMALLINT NOT NULL,
             SENTDATE                       TIMESTAMP,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD020.
           10 MAILID               PIC S9(9) USAGE COMP-5.
           10 USERID               PIC N(8).
           10 EMAIL.
              49 EMAIL-LEN PIC S9(4) USAGE COMP-5.
              49 EMAIL-TEXT PIC N(254).
           10 DEPLID               PIC S9(9) USAGE COMP-5.
           10 DEPLID-IND           PIC S9(4) USAGE COMP-5.
           10 MAILTYPE             PIC N(1).
           10 SUBJECT.
              49 SUBJECT-LEN PIC S9(4) USAGE COMP-5.
              49 SUBJECT-TEXT PIC N(100).
           10 BODY.
              49 BODY-LEN PIC S9(4) USAGE COMP-5.
              49 BODY-TEXT PIC N(1000).
           10 MAILSTATUS           PIC N(1).
           10 ATTEMPTS             PIC S9(4) USAGE COMP-5.
           10 SENTDATE             PIC X(26).
           10 SENTDATE-IND         PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
