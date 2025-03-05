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