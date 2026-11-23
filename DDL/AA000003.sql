-- Create lwd database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create lwd database
   CREATE DATABASE {{DBNAME}}
                     BUFFERPOOL BP0
                     INDEXBP    BP3
                     CCSID      UNICODE
                     STOGROUP   {{STOGROUP}};

   COMMIT;