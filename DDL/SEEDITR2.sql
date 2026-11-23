-- Iteration 2, for an environment seeded in iteration 1 only: the
-- demo PRD needs two approvals, as SEEDDATA.sql now seeds it.
-- Deployments already waiting keep the N they were requested with.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   UPDATE {{SCHEMA}}.{{ENVIRONMENTS_TBNAME}}
      SET APPROVALCOUNT = 2,
          UPDATEDBY = 'SEED',
          UPDATEDDATE = CURRENT TIMESTAMP
    WHERE ENVCODE = 'PRD'
      AND APPID IN (SELECT APPID
                      FROM {{SCHEMA}}.{{APPLICATIONS_TBNAME}}
                     WHERE APPCODE = 'DEMO');

   COMMIT;
