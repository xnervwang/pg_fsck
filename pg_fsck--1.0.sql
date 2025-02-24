/* contrib/pg_fsck/pg_fsck--1.0.sql */

-- complain if script is sourced in psql, rather than via ALTER EXTENSION
\echo Use "ALTER EXTENSION pg_fsck" to load this file. \quit

--
-- pg_fsck_get_my_database_id()
--
CREATE FUNCTION pg_fsck_get_my_database_id()
RETURNS OID
AS 'MODULE_PATHNAME', 'pg_fsck_get_my_database_id'
LANGUAGE C STRICT PARALLEL SAFE;

--
-- pg_fsck_list_relfilenodes()
--
CREATE OR REPLACE FUNCTION pg_fsck_list_relfilenodes()
RETURNS TABLE (
    relname TEXT,
    reloid OID,
    relfilenode OID,
    filepath TEXT
) 
LANGUAGE SQL 
AS $$
WITH RECURSIVE tablespace_paths AS (
    SELECT
        oid AS tablespace_oid,
        spcname,
        pg_tablespace_location(oid) AS tablespace_location
    FROM pg_tablespace
),
table_files AS (
    SELECT 
        c.oid AS reloid,
        c.relname,
        c.relkind,
        c.relfilenode,
        pg_relation_filepath(c.oid) AS base_filepath,
        pg_relation_size(c.oid, 'main') AS rel_size
    FROM pg_class c
    LEFT JOIN tablespace_paths t ON c.reltablespace = t.tablespace_oid
    WHERE c.relfilenode IS NOT NULL AND c.relfilenode <> 0
),
file_parts AS (
    SELECT 
        f.reloid,
        f.relname,
        f.relkind,
        f.relfilenode,
        n AS part,
        CASE WHEN n = 0 THEN f.base_filepath ELSE f.base_filepath || '.' || n END AS filepath
    FROM table_files f
    CROSS JOIN generate_series(0, (f.rel_size / 1024 / 1024 / 1024)::int) AS n
)
SELECT relname, reloid, relfilenode, filepath
FROM file_parts
$$;

--
-- pg_fsck_find_missing_relfilenodes()
--
CREATE OR REPLACE FUNCTION pg_fsck_find_missing_relfilenodes()
RETURNS TABLE (
    relname TEXT,
    reloid OID,
    relfilenode OID,
    filepath TEXT
) 
LANGUAGE SQL 
AS $$
SELECT relname, reloid, relfilenode, filepath
FROM pg_fsck_list_relfilenodes()
WHERE pg_stat_file(filepath, true) IS NULL;
$$;