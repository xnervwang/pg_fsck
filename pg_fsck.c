/*-------------------------------------------------------------------------
 *
 * pg_fsck.c
 *	  some utility functions
 *
 *	  contrib/pg_fsck/pg_fsck.c
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "fmgr.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

/*
 * Returns the the current database ID of this connectionl
 */
PG_FUNCTION_INFO_V1(pg_fsck_get_my_database_id);

Datum
pg_fsck_get_my_database_id(PG_FUNCTION_ARGS)
{
    PG_RETURN_OID(MyDatabaseId);
}
