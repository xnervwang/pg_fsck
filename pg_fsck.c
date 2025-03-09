/*-------------------------------------------------------------------------
 *
 * pg_fsck.c
 *    some utility functions
 *
 *    pg_fsck/pg_fsck.c
 *
 * Copyright (c) 2025, Xnerv Wang <xnervwang@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the <organization> nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"
#include "common/relpath.h"
#include "utils/builtins.h"

#include "fmgr.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

/*
 * Returns the the current database ID of this connectionl
 */
PG_FUNCTION_INFO_V1(pg_fsck_get_my_database_id);

/*
 * Returns the the current database directory path. If it's
 * non-default tablespace, the symbolic path "pg_tblspc/..."
 * will be returned rather than the actual physical path.
 */
PG_FUNCTION_INFO_V1(pg_fsck_get_database_path);

Datum
pg_fsck_get_my_database_id(PG_FUNCTION_ARGS)
{
    PG_RETURN_OID(MyDatabaseId);
}

Datum
pg_fsck_get_database_path(PG_FUNCTION_ARGS)
{
    Oid dbOid = PG_GETARG_OID(0);
    Oid spcOid = PG_GETARG_OID(1);

    PG_RETURN_TEXT_P(cstring_to_text(GetDatabasePath(dbOid, spcOid)));
}

