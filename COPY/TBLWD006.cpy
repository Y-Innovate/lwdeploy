      ******************************************************************
      * DCLGEN TABLE(TBLWD006)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD006 TABLE
           ( ENVID                          INTEGER NOT NULL,
             APPID                          INTEGER NOT NULL,
             ENVCODE                        GRAPHIC(8) NOT NULL,
             ENVNAME                        VARGRAPHIC(60) NOT NULL,
             DESCRIPTION                    VARGRAPHIC(1000),
             SORTORDER                      SMALLINT NOT NULL,
             PROMOGATE                      GRAPHIC(1) NOT NULL,
             DEPLOYUSER                     GRAPHIC(8),
             APPROVALREQ                    GRAPHIC(1) NOT NULL,
             APPROVERGROUP                  GRAPHIC(8),
             APPROVALCOUNT                  SMALLINT NOT NULL,
             DEPLOYERGROUP                  GRAPHIC(8),
             ACTIVEDEPLID                   INTEGER,
             CURRENTDEPLID                  INTEGER,
             CURRENTVERSIONID               INTEGER,
             ENVSTATE                       GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL,
             EXECNODE                       GRAPHIC(8)
           ) END-EXEC.
       01  DCLTBLWD006.
           10 ENVID                PIC S9(9) USAGE COMP-5.
           10 APPID                PIC S9(9) USAGE COMP-5.
           10 ENVCODE              PIC N(8).
           10 ENVNAME.
              49 ENVNAME-LEN PIC S9(4) USAGE COMP-5.
              49 ENVNAME-TEXT PIC N(60).
           10 DESCRIPTION.
              49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
              49 DESCRIPTION-TEXT PIC N(1000).
           10 DESCRIPTION-IND      PIC S9(4) USAGE COMP-5.
           10 SORTORDER            PIC S9(4) USAGE COMP-5.
           10 PROMOGATE            PIC N(1).
           10 DEPLOYUSER           PIC N(8).
           10 DEPLOYUSER-IND       PIC S9(4) USAGE COMP-5.
           10 APPROVALREQ          PIC N(1).
           10 APPROVERGROUP        PIC N(8).
           10 APPROVERGROUP-IND    PIC S9(4) USAGE COMP-5.
           10 APPROVALCOUNT        PIC S9(4) USAGE COMP-5.
           10 DEPLOYERGROUP        PIC N(8).
           10 DEPLOYERGROUP-IND    PIC S9(4) USAGE COMP-5.
           10 ACTIVEDEPLID         PIC S9(9) USAGE COMP-5.
           10 ACTIVEDEPLID-IND     PIC S9(4) USAGE COMP-5.
           10 CURRENTDEPLID        PIC S9(9) USAGE COMP-5.
           10 CURRENTDEPLID-IND    PIC S9(4) USAGE COMP-5.
           10 CURRENTVERSIONID     PIC S9(9) USAGE COMP-5.
           10 CURRENTVERSIONID-IND PIC S9(4) USAGE COMP-5.
           10 ENVSTATE             PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
           10 EXECNODE             PIC N(8).
           10 EXECNODE-IND         PIC S9(4) USAGE COMP-5.
