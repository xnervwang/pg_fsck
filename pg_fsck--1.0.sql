-- Copyright (c) 2025, Xnerv Wang <xnervwang@gmail.com>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without 
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright 
--    notice, this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright 
--    notice, this list of conditions and the following disclaimer in the 
--    documentation and/or other materials provided with the distribution.
--
-- 3. Neither the name of the <organization> nor the names of its 
--    contributors may be used to endorse or promote products derived from 
--    this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
-- ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY 
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


/* pg_fsck/pg_fsck--1.0.sql */

-- TODO: To support query a specific table space, or schema.

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
-- pg_fsck_get_database_path()
--
-- Use OUT parameter instead of RETURNS to give the output column a name instead of
-- the function name.
--
CREATE FUNCTION pg_fsck_get_database_path(db_oid OID, spc_oid OID, OUT database_path TEXT)
AS 'MODULE_PATHNAME', 'pg_fsck_get_database_path'
LANGUAGE C STRICT PARALLEL SAFE;

--
-- pg_fsck_list_relfilenodes()
--
CREATE OR REPLACE FUNCTION pg_fsck_list_relfilenodes()
RETURNS TABLE (
    relname TEXT,
    reloid OID,
    relfilenode OID,
    spcname TEXT,
    filepath TEXT
) 
LANGUAGE SQL 
AS $$
WITH RECURSIVE tablespace_paths AS (
    SELECT
        oid AS tablespace_oid,
        spcname
    FROM pg_tablespace
),
-- Refer to pg_relation_filepath c code, some relations in pg_class,
-- like pg_class_tblspc_relfilenode_index, their relfilenode can be
-- 0, while they have disk file name by oid. The way to decide if this
-- oid has associated disk file is to check if pg_relation_filepath
-- returns IS NOT NULL.
table_files AS (
    SELECT * FROM (
        SELECT 
            c.oid AS reloid,
            c.relname,
            c.relkind,
            c.relfilenode,
            t.spcname,
            pg_relation_filepath(c.oid) AS base_filepath,
            pg_relation_size(c.oid, 'main') AS rel_size
        FROM pg_class c
        LEFT JOIN tablespace_paths t ON c.reltablespace = t.tablespace_oid
    ) f
    WHERE base_filepath IS NOT NULL
),
file_parts AS (
    SELECT 
        f.reloid,
        f.relname,
        f.relkind,
        f.relfilenode,
        f.spcname,
        n AS part,
        CASE WHEN n = 0 THEN f.base_filepath ELSE f.base_filepath || '.' || n END AS filepath
    FROM table_files f
    CROSS JOIN generate_series(0, (f.rel_size / 1024 / 1024 / 1024)::int) AS n
)
SELECT relname, reloid, relfilenode, spcname, filepath FROM file_parts
$$;

--
-- pg_fsck_find_missing_relfilenodes()
--
CREATE OR REPLACE FUNCTION pg_fsck_find_missing_relfilenodes()
RETURNS TABLE (
    relname TEXT,
    reloid OID,
    relfilenode OID,
    spcname TEXT,
    filepath TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT has_function_privilege(current_user, 'pg_stat_file(text, boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Permission denied: current user does not have EXECUTE privilege on pg_stat_file()';
    END IF;

    RETURN QUERY
    SELECT f.relname, f.reloid, f.relfilenode, f.spcname, f.filepath
    FROM pg_fsck_list_relfilenodes() f
    WHERE pg_stat_file(f.filepath, true) IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION pg_fsck_find_extra_relfilenodes()
RETURNS TABLE (
    filepath TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ensure the user has permission to execute pg_stat_file()
    IF NOT has_function_privilege(current_user, 'pg_stat_file(text, boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Permission denied: current user does not have EXECUTE privilege on pg_stat_file()';
    END IF;

    RETURN QUERY
    WITH tablespace_relative_paths AS (
        -- Compute absolute paths for all tablespaces
        SELECT pg_fsck_get_database_path(pg_database.oid, pg_tablespace.oid) AS relative_dirpath
        FROM pg_database, pg_tablespace
        WHERE pg_database.datname = current_database()
    ),
    tablespace_paths AS (
        -- Compute absolute paths for all tablespaces
        SELECT relative_dirpath, current_setting('data_directory') || '/' || relative_dirpath AS absolute_dirpath
        FROM tablespace_relative_paths
    ),
    valid_tablespace_paths AS (
        -- Use LEFT JOIN LATERAL to safely apply pg_stat_file() and extract its fields
        SELECT t.relative_dirpath, t.absolute_dirpath
        FROM tablespace_paths t
        LEFT JOIN LATERAL (
            SELECT * FROM pg_stat_file(t.absolute_dirpath, true)
        ) s ON true
        WHERE s.size IS NOT NULL  -- Ensure the file/dir exists
    ),
    all_files AS (
        -- List files only in existing tablespace directories
        SELECT
            relative_dirpath || '/' || filename AS relative_path,
            absolute_dirpath || '/' || filename AS absolute_path
        FROM valid_tablespace_paths, pg_ls_dir(absolute_dirpath) AS filename
    ),
    primary_files AS (
        -- Only retain files that are regular relfilenode files (not fork files)
        SELECT relative_path, absolute_path
        FROM all_files
        WHERE relative_path ~ '^base/\d+/\d+(\.\d+)?$'  -- Regular relfilenode file in base
            OR relative_path ~ '^global/\d+(\.\d+)?$'    -- Regular relfilenode file in global
            OR relative_path ~ '^\S+/\d+/(\d+(\.\d+)?)$' -- Tablespace file
    ),
    fork_files AS (
        -- Retain only fork files (_fsm, _vm, _init)
        SELECT relative_path, absolute_path
        FROM all_files
        WHERE relative_path ~ '^base/\d+/\d+(_fsm|_vm|_init)$'  -- Fork files in base
            OR relative_path ~ '^global/\d+(_fsm|_vm|_init)$'    -- Fork files in global (no dboid)
            OR relative_path ~ '^\S+/\d+/(\d+)(_fsm|_vm|_init)$' -- Fork files in tablespaces
    ),
    orphan_fork_files AS (
        -- Find fork files that do not have a corresponding base file
        SELECT f.relative_path
        FROM fork_files f
        LEFT JOIN primary_files p
        ON regexp_replace(f.relative_path, '(_fsm|_vm|_init|\.\d+)$', '') = regexp_replace(p.relative_path, '\.\d+$', '') -- Normalize both paths
        WHERE p.relative_path IS NULL  -- If there is no matching base file, keep the fork file
    )
    -- Find files that exist on disk but are NOT registered in pg_class
    SELECT relative_path FROM primary_files
    EXCEPT
    SELECT f.filepath FROM pg_fsck_list_relfilenodes() f

    UNION ALL

    -- Add orphan fork files that do not have a base file
    SELECT relative_path FROM orphan_fork_files;
END;
$$;
