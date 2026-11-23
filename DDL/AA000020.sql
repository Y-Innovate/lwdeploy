-- Create spoollines table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create spoollines tablespace
   CREATE TABLESPACE {{SPOOLLINES_TBSNAME}}
                       IN {{DBNAME}}
                       USING STOGROUP {{STOGROUP}}
                       PRIQTY 72000 SECQTY 72000
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
                       COMPRESS YES
                       CCSID      UNICODE
                       DEFINE YES
                       MAXROWS 255
                       INSERT ALGORITHM 0;

-- Create spoollines table
   CREATE TABLE {{SCHEMA}}.{{SPOOLLINES_TBNAME}}
      (RUNID       INTEGER NOT NULL,
       FILENO      SMALLINT NOT NULL,
       LINENUM     INTEGER NOT NULL,
       LINETEXT    VARGRAPHIC(255) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT SPOOLLINESKEY
       PRIMARY KEY (RUNID,
                    FILENO,
                    LINENUM))
      IN {{DBNAME}}.{{SPOOLLINES_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create spoollines index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{SPOOLLINES_IXNAME1}}
      ON {{SCHEMA}}.{{SPOOLLINES_TBNAME}}
      (RUNID   ASC,
       FILENO  ASC,
       LINENUM ASC)
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

-- Create foreign key on RUNID, FILENO
   ALTER TABLE {{SCHEMA}}.{{SPOOLLINES_TBNAME}}
     FOREIGN KEY SPOOLL_FK1 (RUNID, FILENO)
     REFERENCES {{SCHEMA}}.{{SPOOLFILES_TBNAME}}
       (RUNID, FILENO)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;