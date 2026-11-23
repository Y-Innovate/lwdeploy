-- Create deplevents table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create deplevents tablespace
   CREATE TABLESPACE {{DEPLEVENTS_TBSNAME}}
                       IN {{DBNAME}}
                       USING STOGROUP {{STOGROUP}}
                       PRIQTY 40 SECQTY 40
                       ERASE  NO
                       FREEPAGE 0 PCTFREE 5 FOR UPDATE 0
                       GBPCACHE CHANGED
                       TRACKMOD YES
                       MAXPARTITIONS 254
                       LOGGED
                       DSSIZE 4 G
                       SEGSIZE 4
                       BUFFERPOOL BP0
                       LOCKSIZE ANY
                       LOCKMAX SYSTEM
                       CLOSE YES
                       COMPRESS NO
                       CCSID      UNICODE
                       DEFINE YES
                       MAXROWS 255
                       INSERT ALGORITHM 0;

-- Create deplevents table
   CREATE TABLE {{SCHEMA}}.{{DEPLEVENTS_TBNAME}}
      (DEPLID      INTEGER NOT NULL,
       EVENTNO     SMALLINT NOT NULL,
       EVENTTYPE   GRAPHIC(1) NOT NULL,
       JOBNO       SMALLINT,
       COMMENTTEXT VARGRAPHIC(255),
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT DEPLEVENTSKEY
       PRIMARY KEY (DEPLID,
                    EVENTNO))
      IN {{DBNAME}}.{{DEPLEVENTS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create deplevents index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{DEPLEVENTS_IXNAME1}}
      ON {{SCHEMA}}.{{DEPLEVENTS_TBNAME}}
      (DEPLID  ASC,
       EVENTNO ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create foreign key on DEPLID
   ALTER TABLE {{SCHEMA}}.{{DEPLEVENTS_TBNAME}}
     FOREIGN KEY DEPLEV_FK1 (DEPLID)
     REFERENCES {{SCHEMA}}.{{DEPLOYMENTS_TBNAME}}
       (DEPLID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;