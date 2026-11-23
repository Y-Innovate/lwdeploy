      ******************************************************************
      * DCLGEN TABLE(TBLWD011)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD011 TABLE
           ( DEPLID                         INTEGER NOT NULL,
             APPID                          INTEGER NOT NULL,
             ENVID                          INTEGER NOT NULL,
             VERSIONID                      INTEGER NOT NULL,
             DEPLSTATUS                     GRAPHIC(1) NOT NULL,
             STARTAFTER                     TIMESTAMP NOT NULL,
             REQUESTNOTE                    VARGRAPHIC(255),
             DEPLOYUSER                     GRAPHIC(8) NOT NULL,
             APPROVERGROUP                  GRAPHIC(8),
             APPROVALCOUNT                  SMALLINT NOT NULL,
             APPROVEDCOUNT                  SMALLINT NOT NULL,
             STARTEDDATE                    TIMESTAMP,
             ENDEDDATE                      TIMESTAMP,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD011.
           10 DEPLID               PIC S9(9) USAGE COMP-5.
           10 APPID                PIC S9(9) USAGE COMP-5.
           10 ENVID                PIC S9(9) USAGE COMP-5.
           10 VERSIONID            PIC S9(9) USAGE COMP-5.
           10 DEPLSTATUS           PIC N(1).
           10 STARTAFTER           PIC X(26).
           10 REQUESTNOTE.
              49 REQUESTNOTE-LEN PIC S9(4) USAGE COMP-5.
              49 REQUESTNOTE-TEXT PIC N(255).
           10 REQUESTNOTE-IND      PIC S9(4) USAGE COMP-5.
           10 DEPLOYUSER           PIC N(8).
           10 APPROVERGROUP        PIC N(8).
           10 APPROVERGROUP-IND    PIC S9(4) USAGE COMP-5.
           10 APPROVALCOUNT        PIC S9(4) USAGE COMP-5.
           10 APPROVEDCOUNT        PIC S9(4) USAGE COMP-5.
           10 STARTEDDATE          PIC X(26).
           10 STARTEDDATE-IND      PIC S9(4) USAGE COMP-5.
           10 ENDEDDATE            PIC X(26).
           10 ENDEDDATE-IND        PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
