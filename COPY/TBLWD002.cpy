      ******************************************************************
      * DCLGEN TABLE(TBLWD002)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD002 TABLE
           ( USERID                         GRAPHIC(8) NOT NULL,
             EMAIL                          VARGRAPHIC(254),
             NOTIFYAPPROVE                  GRAPHIC(1) NOT NULL,
             NOTIFYOWN                      GRAPHIC(1) NOT NULL,
             NOTIFYAPP                      GRAPHIC(1) NOT NULL,
             GROUPSCHECKED                  TIMESTAMP,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD002.
           10 USERID               PIC N(8).
           10 EMAIL.
              49 EMAIL-LEN PIC S9(4) USAGE COMP-5.
              49 EMAIL-TEXT PIC N(254).
           10 EMAIL-IND            PIC S9(4) USAGE COMP-5.
           10 NOTIFYAPPROVE        PIC N(1).
           10 NOTIFYOWN            PIC N(1).
           10 NOTIFYAPP            PIC N(1).
           10 GROUPSCHECKED        PIC X(26).
           10 GROUPSCHECKED-IND    PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
