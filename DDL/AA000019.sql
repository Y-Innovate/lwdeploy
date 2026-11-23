-- Create spoolfiles table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create spoolfiles tablespace
   CREATE TABLESPACE {{SPOOLFILES_TBSNAME}}
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

-- Create spoolfiles table
   CREATE TABLE {{SCHEMA}}.{{SPOOLFILES_TBNAME}}
      (RUNID       INTEGER NOT NULL,
       FILENO      SMALLINT NOT NULL,
       DDNAME      GRAPHIC(8) NOT NULL,
       STEPNAME    GRAPHIC(8),
       PROCSTEP    GRAPHIC(8),
       LINECOUNT   INTEGER NOT NULL,
       TRUNCATED   GRAPHIC(1) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT SPOOLFILESKEY
       PRIMARY KEY (RUNID,
                    FILENO))
      IN {{DBNAME}}.{{SPOOLFILES_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create spoolfiles index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{SPOOLFILES_IXNAME1}}
      ON {{SCHEMA}}.{{SPOOLFILES_TBNAME}}
      (RUNID  ASC,
       FILENO ASC)
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
   ALTER TABLE {{SCHEMA}}.{{SPOOLFILES_TBNAME}}
     FOREIGN KEY SPOOLF_FK1 (RUNID)
     REFERENCES {{SCHEMA}}.{{JOBRUNS_TBNAME}}
       (RUNID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;