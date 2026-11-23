-- Create jcllines table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create jcllines tablespace
   CREATE TABLESPACE {{JCLLINES_TBSNAME}}
                       IN {{DBNAME}}
                       USING STOGROUP {{STOGROUP}}
                       PRIQTY 7200 SECQTY 7200
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

-- Create jcllines table
   CREATE TABLE {{SCHEMA}}.{{JCLLINES_TBNAME}}
      (DEPLID      INTEGER NOT NULL,
       JOBNO       SMALLINT NOT NULL,
       LINENUM     SMALLINT NOT NULL,
       LINETEXT    VARGRAPHIC(80) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT JCLLINESKEY
       PRIMARY KEY (DEPLID,
                    JOBNO,
                    LINENUM))
      IN {{DBNAME}}.{{JCLLINES_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create jcllines index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{JCLLINES_IXNAME1}}
      ON {{SCHEMA}}.{{JCLLINES_TBNAME}}
      (DEPLID  ASC,
       JOBNO   ASC,
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

-- Create foreign key on DEPLID, JOBNO
   ALTER TABLE {{SCHEMA}}.{{JCLLINES_TBNAME}}
     FOREIGN KEY JCLLIN_FK1 (DEPLID, JOBNO)
     REFERENCES {{SCHEMA}}.{{DEPLJOBS_TBNAME}}
       (DEPLID, JOBNO)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;