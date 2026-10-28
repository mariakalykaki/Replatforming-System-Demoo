-- Runs once, on first container start only (mounted into
-- /docker-entrypoint-initdb.d/). Creates the second database + role that
-- Temporal's own schema lives in, alongside the app's own "appdb".
-- The app's domain data and Temporal's workflow history are deliberately
-- kept in separate databases even though they share one Postgres instance
-- locally, so the separation of ownership (Temporal = orchestration state,
-- Postgres/appdb = domain + regulatory state) still holds if they're split
-- onto separate servers later.

CREATE DATABASE temporal;
CREATE DATABASE temporal_visibility;
