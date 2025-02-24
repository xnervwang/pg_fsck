# contrib/pg_fsck/Makefile

MODULE_big = pg_fsck
OBJS = \
	$(WIN32RES) \
	pg_fsck.o

EXTENSION = pg_fsck
DATA = pg_fsck--1.0.sql
PGFILEDESC = "pg_fsck - checking the integrity of database files, detecting missing or corrupted relfilenode files to ensure storage consistency"

REGRESS = pg_fsck

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/pg_fsck
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
