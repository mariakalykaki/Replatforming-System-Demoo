-- Flyway baseline migration. Intentionally creates nothing business-specific;
-- it exists so `quarkus.flyway.migrate-at-start=true` has something to run
-- on a fresh database and the migration chain starts at V1.
-- Add V2__<description>.sql next to this file for your first real table.
select 1;
