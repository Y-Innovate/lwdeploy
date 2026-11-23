-- Every SETTINGS entry the programs read, from envs/<env>.yaml,
-- and the DEPLAPP entry of the deploy userid of envs/<env>.yaml.
-- Can be run again at any time, after AA000004: it deletes all
-- SETTINGS entries first, so values changed on the admin Settings
-- page (A5) go back to those of envs/<env>.yaml.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   DELETE FROM {{SCHEMA}}.{{REFTABLES_TBNAME}}
     WHERE TABLEID='SETTINGS';

-- ADMINRES: FACILITY resource that makes a userid an administrator
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','ADMINRES','{{ADMINRES}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- GRPPRFX: Prefix of the FACILITY profile per group: <prefix>.<group>
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','GRPPRFX','{{GROUPPREFIX}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- GRPMINS: Minutes a user's cached groups (USERGROUPS) stay valid
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','GRPMINS','{{GROUPMINUTES}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- JOBPRFX: First two characters of every deployment job name
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','JOBPRFX','{{JOBPREFIX}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- JOBCLASS: Job class of the deployment jobs
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','JOBCLASS','{{JOBCLASS}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- MSGCLASS: Message class of the deployment jobs
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','MSGCLASS','{{JOBMSGCLASS}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- EXECLIB: REXX library of the result step (LWDR916)
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','EXECLIB','{{EXECLIB}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- LWDURL: Where the result step finds LWW: https://host, or
-- http://host when AT-TLS adds TLS
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','LWDURL','{{LWDURL}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- LWDPORT: Port of LWW
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','LWDPORT','{{LWDPORT}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- LWDPATH: Path prefix of LWD's REST API
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','LWDPATH','{{LWDPATH}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- LWDRING: Key ring the result step trusts the certificates of LWW
-- and Entra with; *AUTH*/* is every CERTAUTH certificate
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','LWDRING','{{LWDKEYRING}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- TENANT: Entra tenant the result step gets its access token from
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','TENANT','{{ENTRATENANT}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- APISCOPE: Scope of LWD's API in Entra: <application ID>/.default
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','APISCOPE',
            '{{LWDAPISCOPE}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- JAVAHOME: Java of the result step (21 or later), for JWTSignerUtil
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','JAVAHOME','{{JAVAHOME}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- JWTJARS: Directory with the jars of JWTSignerUtil (jwt_signer)
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','JWTJARS','{{JWTJARS}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- SUBMUSR: Userid of the submit task, LWDC910
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','SUBMUSR','{{SUBMITUSER}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- SUBMTXN: Transaction of the submit task
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','SUBMTXN','{{CICSTXN_SUBMIT}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- SCHEDUSR: Userid of the scheduler, the only one that may call
-- POST /schedulerTicks (LWDM930). LWDM930 keeps LASTTICK itself.
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','SCHEDUSR','{{SCHEDUSER}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- APPRHRS: Hours a deployment may wait for approval before it expires
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','APPRHRS','{{APPROVALHOURS}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- JOBMINS: Minutes until a submitted job without a result is stuck
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','JOBMINS','{{JOBMINUTES}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- OUTDAYS: Days collected job output is kept
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','OUTDAYS','{{OUTPUTDAYS}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- OUTLINES: Most lines of output stored per run; the rest is cut off
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','OUTLINES','{{OUTPUTMAXLINES}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- MAILFROM: Sender address of notification mails
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','MAILFROM','{{MAILFROM}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- MAILURL: Base URL of the UI, for links in mails
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','MAILURL','{{MAILURL}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);

-- MAILWRTR: JES writer of CSSMTP; empty: no mail (S5)
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','MAILWRTR','{{MAILWRITER}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- MAILCLS: SYSOUT class of the mails for CSSMTP
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','MAILCLS','{{MAILCLASS}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);
-- MAILMAX: Most mails the tick sends at a time
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('SETTINGS','MAILMAX','{{MAILMAX}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);

-- DEPLAPP: Entra application (client ID) per deploy userid, which
-- LWW maps to that userid. The result step signs in with it
-- (LWDM920). Only this deploy userid's entry: insert one for each
-- other userid in DEPLUSER the same way.
   DELETE FROM {{SCHEMA}}.{{REFTABLES_TBNAME}}
     WHERE TABLEID='DEPLAPP' AND TABKEY='{{DEPLOYUSER}}';
   INSERT INTO {{SCHEMA}}.{{REFTABLES_TBNAME}}
     VALUES('DEPLAPP','{{DEPLOYUSER}}','{{DEPLOYAPPID}}',
            'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP);

   COMMIT;