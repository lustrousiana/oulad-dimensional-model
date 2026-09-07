-- Create catalog and schema if they don't exist
CREATE CATALOG IF NOT EXISTS `ftw-week-07`;
CREATE SCHEMA IF NOT EXISTS `ftw-week-07`.`01-raw`;
CREATE SCHEMA IF NOT EXISTS `ftw-week-07`.`02-clean`;
CREATE SCHEMA IF NOT EXISTS `ftw-week-07`.`03-mart`;