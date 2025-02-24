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

For example,
```SQL
postgres=# CREATE EXTENSION pg_fsck;
CREATE EXTENSION

postgres=# SELECT pg_fsck_get_my_database_id();
 pg_fsck_get_my_database_id
----------------------------
                          5
(1 row)

postgres=# SELECT * FROM pg_fsck_list_relfilenodes();
                    relname                     | table_oid | relfilenode |                filepath
------------------------------------------------+-----------+-------------+-----------------------------------------
 t1                                             |     24576 |       24576 | base/5/24576
 test_table_in_ts_id_seq                        |     32770 |       32770 | base/5/32770
 pg_toast_32771                                 |     32776 |       32776 | pg_tblspc/32769/PG_18_202502212/5/32776
 pg_toast_32771_index                           |     32777 |       32777 | pg_tblspc/32769/PG_18_202502212/5/32777
 test_table_in_ts                               |     32771 |       32771 | pg_tblspc/32769/PG_18_202502212/5/32771
 test_table_in_ts_pkey                          |     32778 |       32778 | base/5/32778
 large_table_id_seq                             |     32781 |       32781 | base/5/32781
 pg_toast_32782                                 |     32787 |       32787 | base/5/32787
 pg_toast_32782_index                           |     32788 |       32788 | base/5/32788
 large_table                                    |     32782 |       32782 | base/5/32782
 large_table                                    |     32782 |       32782 | base/5/32782.1
 large_table                                    |     32782 |       32782 | base/5/32782.2
 large_table                                    |     32782 |       32782 | base/5/32782.3
 large_table_pkey                               |     32789 |       32789 | base/5/32789
 pg_statistic                                   |      2619 |        2619 | base/5/2619
...

-- The first scan, no file is missing.
postgres=# SELECT * from pg_fsck_find_missing_relfilenodes();
 relname | reloid | relfilenode | filepath
---------+--------+-------------+----------
(0 rows)

-- We removed 32771 and 32782.3, scan again.
postgres=# SELECT * from pg_fsck_find_missing_relfilenodes();
     relname      | reloid | relfilenode |                filepath
------------------+--------+-------------+-----------------------------------------
 test_table_in_ts |  32771 |       32771 | pg_tblspc/32769/PG_18_202502212/5/32771
 large_table      |  32782 |       32782 | base/5/32782.3
(2 rows)
```

## License
This software is provided under the BSD license. See LICENSE for details.
