-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Fri Apr 18 17:06:06 2014
-- 

;
BEGIN TRANSACTION;
--
-- Table: dbix_class_deploymenthandler_versions
--
DROP TABLE IF EXISTS dbix_class_deploymenthandler_versions;
CREATE TABLE dbix_class_deploymenthandler_versions (
  id INTEGER PRIMARY KEY NOT NULL,
  version varchar(50) NOT NULL,
  ddl text,
  upgrade_sql text
);
CREATE UNIQUE INDEX dbix_class_deploymenthandler_versions_version ON dbix_class_deploymenthandler_versions (version);
COMMIT;