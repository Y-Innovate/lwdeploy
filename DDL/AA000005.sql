-- Create users table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create users tablespace
   CREATE TABLESPACE {{USERS_TBSNAME}}
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

-- Create users table
   CREATE TABLE {{SCHEMA}}.{{USERS_TBNAME}}
      (USERID        GRAPHIC(8) NOT NULL,
       EMAIL         VARGRAPHIC(254),
       NOTIFYAPPROVE GRAPHIC(1) NOT NULL,
       NOTIFYOWN     GRAPHIC(1) NOT NULL,
       NOTIFYAPP     GRAPHIC(1) NOT NULL,
       GROUPSCHECKED TIMESTAMP,
       CREATEDBY     GRAPHIC(8) NOT NULL,
       CREATEDDATE   TIMESTAMP NOT NULL,
       UPDATEDBY     GRAPHIC(8) NOT NULL,
       UPDATEDDATE   TIMESTAMP NOT NULL,
       CONSTRAINT USERSKEY
       PRIMARY KEY (USERID))
      IN {{DBNAME}}.{{USERS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create users index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{USERS_IXNAME1}}
      ON {{SCHEMA}}.{{USERS_TBNAME}}
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

   COMMIT;