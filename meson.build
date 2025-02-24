# Copyright (c) 2022-2025, PostgreSQL Global Development Group

pg_fsck_sources = files(
  'pg_fsck.c',
)

if host_system == 'windows'
  pg_fsck_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'pg_fsck',
    '--FILEDESC', 'pg_fsck - checking the integrity of database files, detecting missing or corrupted relfilenode files to ensure storage consistency',])
endif

pg_fsck = shared_module('pg_fsck',
  pg_fsck_sources,
  kwargs: contrib_mod_args,
)
contrib_targets += pg_fsck

install_data(
  'pg_fsck--1.0.sql',
  'pg_fsck.control',
  kwargs: contrib_data_args,
)

tests += {
  'name': 'pg_fsck',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'regress': {
    'sql': [
      'pg_fsck',
    ],
  },
}
