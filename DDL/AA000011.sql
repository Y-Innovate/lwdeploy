-- Create templates table in lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create templates tablespace
   CREATE TABLESPACE {{TEMPLATES_TBSNAME}}
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

-- Create templates table
   CREATE TABLE {{SCHEMA}}.{{TEMPLATES_TBNAME}}
      (TEMPLATEID     INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       APPID          INTEGER NOT NULL,
       TEMPLATENAME   VARGRAPHIC(60) NOT NULL,
       SORTORDER      SMALLINT NOT NULL,
       MAXRC          SMALLINT NOT NULL,
       CURRENTREV     SMALLINT NOT NULL,
       TEMPLATESTATUS GRAPHIC(1) NOT NULL,
       CREATEDBY      GRAPHIC(8) NOT NULL,
       CREATEDDATE    TIMESTAMP NOT NULL,
       UPDATEDBY      GRAPHIC(8) NOT NULL,
       UPDATEDDATE    TIMESTAMP NOT NULL,
       CONSTRAINT TEMPLATESKEY
       PRIMARY KEY (TEMPLATEID))
      IN {{DBNAME}}.{{TEMPLATES_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create templates index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{TEMPLATES_IXNAME1}}
      ON {{SCHEMA}}.{{TEMPLATES_TBNAME}}
      (TEMPLATEID ASC)
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

-- Create templates index on APPID, SORTORDER
   CREATE INDEX {{SCHEMA}}.{{TEMPLATES_IXNAME2}}
      ON {{SCHEMA}}.{{TEMPLATES_TBNAME}}
      (APPID     ASC,
       SORTORDER ASC)
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
   ALTER TABLE {{SCHEMA}}.{{TEMPLATES_TBNAME}}
     FOREIGN KEY TEMPLA_FK1 (APPID)
     REFERENCES {{SCHEMA}}.{{APPLICATIONS_TBNAME}}
       (APPID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;