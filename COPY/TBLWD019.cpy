      ******************************************************************
      * DCLGEN TABLE(TBLWD019)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBLWD019 TABLE
           ( DEPLID                         INTEGER NOT NULL,
             EVENTNO                        SMALLINT NOT NULL,
             EVENTTYPE                      GRAPHIC(1) NOT NULL,
             JOBNO                          SMALLINT,
             COMMENTTEXT                    VARGRAPHIC(255),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBLWD019.
           10 DEPLID               PIC S9(9) USAGE COMP-5.
           10 EVENTNO              PIC S9(4) USAGE COMP-5.
           10 EVENTTYPE            PIC N(1).
           10 JOBNO                PIC S9(4) USAGE COMP-5.
           10 JOBNO-IND            PIC S9(4) USAGE COMP-5.
           10 COMMENTTEXT.
              49 COMMENTTEXT-LEN PIC S9(4) USAGE COMP-5.
              49 COMMENTTEXT-TEXT PIC N(255).
           10 COMMENTTEXT-IND      PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
