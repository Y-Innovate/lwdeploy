-- Create templatelines table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create templatelines tablespace
   CREATE TABLESPACE {{TEMPLATELINES_TBSNAME}}
                       IN {{DBNAME}}
                       USING STOGROUP {{STOGROUP}}
                       PRIQTY 720 SECQTY 720
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

-- Create templatelines table
   CREATE TABLE {{SCHEMA}}.{{TEMPLATELINES_TBNAME}}
      (TEMPLATEID  INTEGER NOT NULL,
       REVISION    SMALLINT NOT NULL,
       LINENUM     SMALLINT NOT NULL,
       LINETEXT    VARGRAPHIC(80) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT TEMPLATELINESKEY
       PRIMARY KEY (TEMPLATEID,
                    REVISION,
                    LINENUM))
      IN {{DBNAME}}.{{TEMPLATELINES_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create templatelines index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{TEMPLATELINES_IXNAME1}}
      ON {{SCHEMA}}.{{TEMPLATELINES_TBNAME}}
      (TEMPLATEID ASC,
       REVISION   ASC,
       LINENUM    ASC)
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

-- Create foreign key on TEMPLATEID, REVISION
   ALTER TABLE {{SCHEMA}}.{{TEMPLATELINES_TBNAME}}
     FOREIGN KEY TEMPLA_FK1 (TEMPLATEID, REVISION)
     REFERENCES {{SCHEMA}}.{{TEMPLATEREVS_TBNAME}}
       (TEMPLATEID, REVISION)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;