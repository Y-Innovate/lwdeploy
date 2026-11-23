-- Create jobsteps table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create jobsteps tablespace
   CREATE TABLESPACE {{JOBSTEPS_TBSNAME}}
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

-- Create jobsteps table
   CREATE TABLE {{SCHEMA}}.{{JOBSTEPS_TBNAME}}
      (RUNID       INTEGER NOT NULL,
       STEPNO      SMALLINT NOT NULL,
       STEPNAME    GRAPHIC(8) NOT NULL,
       PROCSTEP    GRAPHIC(8),
       PGMNAME     GRAPHIC(8),
       STEPRC      SMALLINT,
       ABENDCODE   GRAPHIC(5),
       FLUSHED     GRAPHIC(1) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT JOBSTEPSKEY
       PRIMARY KEY (RUNID,
                    STEPNO))
      IN {{DBNAME}}.{{JOBSTEPS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create jobsteps index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{JOBSTEPS_IXNAME1}}
      ON {{SCHEMA}}.{{JOBSTEPS_TBNAME}}
      (RUNID  ASC,
       STEPNO ASC)
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

-- Create foreign key on RUNID
   ALTER TABLE {{SCHEMA}}.{{JOBSTEPS_TBNAME}}
     FOREIGN KEY JOBSTE_FK1 (RUNID)
     REFERENCES {{SCHEMA}}.{{JOBRUNS_TBNAME}}
       (RUNID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;