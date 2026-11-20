// Public SQLite C ABI, version-one prefix only. The Windows SDK header is
// not required by the cross build. SQLite dispatches according to iVersion.
// https://sqlite.org/c3ref/vfs.html and https://sqlite.org/c3ref/io_methods.html
#pragma once
#include <stdint.h>

struct sqlite3;
struct sqlite3_stmt;
struct sqlite3_io_methods;
struct sqlite3_file { const sqlite3_io_methods *pMethods; };
struct sqlite3_io_methods {
  int iVersion;
  int (*xClose)(sqlite3_file*);
  int (*xRead)(sqlite3_file*, void*, int, int64_t);
  int (*xWrite)(sqlite3_file*, const void*, int, int64_t);
  int (*xTruncate)(sqlite3_file*, int64_t);
  int (*xSync)(sqlite3_file*, int);
  int (*xFileSize)(sqlite3_file*, int64_t*);
  int (*xLock)(sqlite3_file*, int);
  int (*xUnlock)(sqlite3_file*, int);
  int (*xCheckReservedLock)(sqlite3_file*, int*);
  int (*xFileControl)(sqlite3_file*, int, void*);
  int (*xSectorSize)(sqlite3_file*);
  int (*xDeviceCharacteristics)(sqlite3_file*);
};
struct sqlite3_vfs {
  int iVersion, szOsFile, mxPathname;
  sqlite3_vfs *pNext;
  const char *zName;
  void *pAppData;
  int (*xOpen)(sqlite3_vfs*, const char*, sqlite3_file*, int, int*);
  int (*xDelete)(sqlite3_vfs*, const char*, int);
  int (*xAccess)(sqlite3_vfs*, const char*, int, int*);
  int (*xFullPathname)(sqlite3_vfs*, const char*, int, char*);
  void *(*xDlOpen)(sqlite3_vfs*, const char*);
  void (*xDlError)(sqlite3_vfs*, int, char*);
  void (*(*xDlSym)(sqlite3_vfs*, void*, const char*))(void);
  void (*xDlClose)(sqlite3_vfs*, void*);
  int (*xRandomness)(sqlite3_vfs*, int, char*);
  int (*xSleep)(sqlite3_vfs*, int);
  int (*xCurrentTime)(sqlite3_vfs*, double*);
  int (*xGetLastError)(sqlite3_vfs*, int, char*);
};
