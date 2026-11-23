-- Iteration 4, for an environments table created before it: the JES2
-- node the jobs of an environment run on (LWDM920 writes /*XEQ). A new
-- table has the column already (AA000009). Empty = the local node.
-- Set it by hand until the admin API exists, for example:
--   UPDATE {{SCHEMA}}.{{ENVIRONMENTS_TBNAME}}
--      SET EXECNODE = 'N2'
--    WHERE ENVID = 3;

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   ALTER TABLE {{SCHEMA}}.{{ENVIRONMENTS_TBNAME}}
     ADD EXECNODE GRAPHIC(8);

   COMMIT;
