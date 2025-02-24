## pg_fsck
An extension that provides checking of the integrity of database files, detecting missing or corrupted relfilenode files to ensure storage consistency.

## Installation
Build and install the extension.
```
$ make
$ make install
```

## Functions
* `pg_fsck_list_relfilenodes` - list all relfilenode files in current database, include the tables in the non-default table spaces.
* `pg_fsck_find_missing_relfilenodes` - list all relfilenode files, which exist in `pg_class` catalog but are missing in current database.
* `pg_fsck_get_my_database_id` - get the database ID of current connection.

## License
This software is provided under the BSD license. See LICENSE for details.
