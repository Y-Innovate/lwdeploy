-- Create usergroups table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create usergroups tablespace
   CREATE TABLESPACE {{USERGROUPS_TBSNAME}}
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

-- Create usergroups table
   CREATE TABLE {{SCHEMA}}.{{USERGROUPS_TBNAME}}
      (USERID      GRAPHIC(8) NOT NULL,
       RACFGROUP   GRAPHIC(8) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT USERGROUPSKEY
       PRIMARY KEY (USERID,
                    RACFGROUP))
      IN {{DBNAME}}.{{USERGROUPS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create usergroups index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{USERGROUPS_IXNAME1}}
      ON {{SCHEMA}}.{{USERGROUPS_TBNAME}}
      (USERID    ASC,
       RACFGROUP ASC)
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

-- Create usergroups index on RACFGROUP
   CREATE INDEX {{SCHEMA}}.{{USERGROUPS_IXNAME2}}
      ON {{SCHEMA}}.{{USERGROUPS_TBNAME}}
      (RACFGROUP ASC)
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

-- Create foreign key on USERID
   ALTER TABLE {{SCHEMA}}.{{USERGROUPS_TBNAME}}
     FOREIGN KEY USERGR_FK1 (USERID)
     REFERENCES {{SCHEMA}}.{{USERS_TBNAME}}
       (USERID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;