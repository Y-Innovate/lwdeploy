      ******************************************************************
      * DCLGEN TABLE(TBLWD003)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD003 TABLE
           ( USERID                         GRAPHIC(8) NOT NULL,
             RACFGROUP                      GRAPHIC(8) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD003.
           10 USERID               PIC N(8).
           10 RACFGROUP            PIC N(8).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
