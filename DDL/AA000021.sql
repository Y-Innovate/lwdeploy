-- Create approvals table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create approvals tablespace
   CREATE TABLESPACE {{APPROVALS_TBSNAME}}
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

-- Create approvals table
   CREATE TABLE {{SCHEMA}}.{{APPROVALS_TBNAME}}
      (DEPLID      INTEGER NOT NULL,
       USERID      GRAPHIC(8) NOT NULL,
       DECISION    GRAPHIC(1) NOT NULL,
       COMMENTTEXT VARGRAPHIC(255),
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT APPROVALSKEY
       PRIMARY KEY (DEPLID,
                    USERID))
      IN {{DBNAME}}.{{APPROVALS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create approvals index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{APPROVALS_IXNAME1}}
      ON {{SCHEMA}}.{{APPROVALS_TBNAME}}
      (DEPLID ASC,
       USERID ASC)
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

-- Create approvals index on USERID
   CREATE INDEX {{SCHEMA}}.{{APPROVALS_IXNAME2}}
      ON {{SCHEMA}}.{{APPROVALS_TBNAME}}
      (USERID ASC)
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
   ALTER TABLE {{SCHEMA}}.{{APPROVALS_TBNAME}}
     FOREIGN KEY APPROV_FK1 (DEPLID)
     REFERENCES {{SCHEMA}}.{{DEPLOYMENTS_TBNAME}}
       (DEPLID)
     ON DELETE RESTRICT ENFORCED;

-- Create foreign key on USERID
   ALTER TABLE {{SCHEMA}}.{{APPROVALS_TBNAME}}
     FOREIGN KEY APPROV_FK2 (USERID)
     REFERENCES {{SCHEMA}}.{{USERS_TBNAME}}
       (USERID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;