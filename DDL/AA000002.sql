-- Create storage group for lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create storage group
   CREATE STOGROUP {{STOGROUP}}
                   VOLUMES('*')
                   VCAT {{STOGROUP_VCAT}}
                   STORCLAS {{STOGROUP_STORCLAS}};

   COMMIT;