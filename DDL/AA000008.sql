-- Create versions table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create versions tablespace
   CREATE TABLESPACE {{VERSIONS_TBSNAME}}
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

-- Create versions table
   CREATE TABLE {{SCHEMA}}.{{VERSIONS_TBNAME}}
      (VERSIONID     INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       APPID         INTEGER NOT NULL,
       VERSIONNAME   VARGRAPHIC(30) NOT NULL,
       LOCTYPE       GRAPHIC(1) NOT NULL,
       LOCATION      VARGRAPHIC(255) NOT NULL,
       DESCRIPTION   VARGRAPHIC(1000),
       VERSIONSTATUS GRAPHIC(1) NOT NULL,
       CREATEDBY     GRAPHIC(8) NOT NULL,
       CREATEDDATE   TIMESTAMP NOT NULL,
       UPDATEDBY     GRAPHIC(8) NOT NULL,
       UPDATEDDATE   TIMESTAMP NOT NULL,
       CONSTRAINT VERSIONSKEY
       PRIMARY KEY (VERSIONID))
      IN {{DBNAME}}.{{VERSIONS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create versions index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{VERSIONS_IXNAME1}}
      ON {{SCHEMA}}.{{VERSIONS_TBNAME}}
      (VERSIONID ASC)
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

-- Create versions unique index on APPID, VERSIONNAME
   CREATE UNIQUE INDEX {{SCHEMA}}.{{VERSIONS_IXNAME2}}
      ON {{SCHEMA}}.{{VERSIONS_TBNAME}}
      (APPID       ASC,
       VERSIONNAME ASC)
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

-- Create versions index on APPID, CREATEDDATE
   CREATE INDEX {{SCHEMA}}.{{VERSIONS_IXNAME3}}
      ON {{SCHEMA}}.{{VERSIONS_TBNAME}}
      (APPID       ASC,
       CREATEDDATE ASC)
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

-- Create foreign key on APPID
   ALTER TABLE {{SCHEMA}}.{{VERSIONS_TBNAME}}
     FOREIGN KEY VERSIO_FK1 (APPID)
     REFERENCES {{SCHEMA}}.{{APPLICATIONS_TBNAME}}
       (APPID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;