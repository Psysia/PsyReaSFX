// Read Soundminer catalogs directly with the Windows system SQLite engine.
// SQLite sees only a private token through this non-default, immutable VFS.
// Each operation borrows one fully shared, read-only disk handle. Neither the
// SQLite pager nor FTS can open an actual filename, journal, WAL or temp file.
#include "sqlite_vfs_v1.h"
#include "reader.h"
#include <windows.h>
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace {
constexpr int OK = 0, READONLY = 8, INTERRUPT = 9, IOERR = 10, NOTFOUND = 12;
constexpr int CANTOPEN = 14, SHORT_READ = IOERR | (2 << 8), ROW = 100, DONE = 101;
constexpr size_t MAX_RECORD = 16 * 1024 * 1024, TARGET_BATCH = 128 * 1024;
constexpr size_t MAX_REPLY = 2 * MAX_RECORD + TARGET_BATCH + 65536;

struct Sqlite {
  HMODULE library;
  int (*open_v2)(const char*, sqlite3**, int, const char*);
  int (*close)(sqlite3*);
  int (*prepare_v3)(sqlite3*, const char*, int, unsigned, sqlite3_stmt**, const char**);
  int (*finalize)(sqlite3_stmt*);
  int (*step)(sqlite3_stmt*);
  int (*bind_text)(sqlite3_stmt*, int, const char*, int, void(*)(void*));
  int (*bind_int64)(sqlite3_stmt*, int, int64_t);
  int (*column_type)(sqlite3_stmt*, int);
  int (*column_count)(sqlite3_stmt*);
  int (*column_bytes)(sqlite3_stmt*, int);
  int64_t (*column_int64)(sqlite3_stmt*, int);
  double (*column_double)(sqlite3_stmt*, int);
  const unsigned char *(*column_text)(sqlite3_stmt*, int);
  const void *(*column_blob)(sqlite3_stmt*, int);
  int (*db_config)(sqlite3*, int, ...);
  int (*set_authorizer)(sqlite3*, int(*)(void*,int,const char*,const char*,const char*,const char*), void*);
  void (*progress_handler)(sqlite3*, int, int(*)(void*), void*);
  int (*limit)(sqlite3*, int, int);
  sqlite3_vfs *(*vfs_find)(const char*);
  int (*vfs_register)(sqlite3_vfs*, int);
  int (*vfs_unregister)(sqlite3_vfs*);
} sql;

struct Stamp {
  uint64_t size, modified, changed;
  DWORD volume, high, low;
  unsigned char header[100];
};
struct Reply {
  char *data;
  size_t used, capacity;
  bool reserve(size_t bytes) {
    if (bytes > MAX_REPLY - used) return false;
    size_t needed = used + bytes + 1;
    if (needed <= capacity) return true;
    size_t next = capacity ? capacity * 2 : 8192;
    if (next < needed) next = needed;
    if (next > MAX_REPLY + 1) next = MAX_REPLY + 1;
    char *resized = static_cast<char*>(realloc(data, next));
    if (!resized) return false;
    data = resized; capacity = next;
    return true;
  }
  bool append(const void *bytes, size_t length) {
    if (!reserve(length)) return false;
    if (length) memcpy(data + used, bytes, length);
    used += length; data[used] = 0;
    return true;
  }
};
struct Source {
  int id;
  wchar_t *path, *wal, *journal;
  char alias[40];
  sqlite3 *db;
  HANDLE active;
  Stamp baseline;
  Reply reply;
  bool changed, searching;
  int fts; // 0 = unexamined, positive = compatible, negative = unsupported
  LARGE_INTEGER deadline;
};
struct PageFile { sqlite3_file base; Source *source; };
Source sources[32];
unsigned serial;
sqlite3_vfs vfs;
char vfs_name[64];

Source *source_for(int id) {
  if (id > 0) for (auto &s : sources) if (s.id == id) return &s;
  return nullptr;
}
HANDLE open_shared(const wchar_t *path) {
  return CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
    nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
}
bool read_at(HANDLE file, void *output, DWORD bytes, int64_t offset, DWORD *actual) {
  LARGE_INTEGER position;
  position.QuadPart = offset;
  return SetFilePointerEx(file, position, nullptr, FILE_BEGIN) && ReadFile(file, output, bytes, actual, nullptr);
}
uint64_t ticks(FILETIME value) { return ((uint64_t)value.dwHighDateTime << 32) | value.dwLowDateTime; }
bool stamp(HANDLE file, Stamp &out) {
  BY_HANDLE_FILE_INFORMATION info{};
  FILE_BASIC_INFO basic{};
  DWORD count = 0;
  if (file == INVALID_HANDLE_VALUE || GetFileType(file) != FILE_TYPE_DISK ||
      !GetFileInformationByHandle(file, &info) || (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ||
      !GetFileInformationByHandleEx(file, FileBasicInfo, &basic, sizeof(basic)) ||
      !read_at(file, out.header, sizeof(out.header), 0, &count) || count != sizeof(out.header)) return false;
  out.size = ((uint64_t)info.nFileSizeHigh << 32) | info.nFileSizeLow;
  out.modified = ticks(info.ftLastWriteTime);
  out.changed = basic.ChangeTime.QuadPart;
  out.volume = info.dwVolumeSerialNumber;
  out.high = info.nFileIndexHigh;
  out.low = info.nFileIndexLow;
  return out.size <= INT64_MAX && memcmp(out.header, "SQLite format 3\0", 16) == 0;
}
bool same(const Stamp &a, const Stamp &b) {
  return a.size == b.size && a.modified == b.modified && a.changed == b.changed &&
    a.volume == b.volume && a.high == b.high && a.low == b.low &&
    memcmp(a.header, b.header, sizeof(a.header)) == 0;
}
bool clear_sidecar(const wchar_t *path, bool wal) {
  HANDLE file = open_shared(path);
  if (file == INVALID_HANDLE_VALUE) {
    DWORD error = GetLastError();
    return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND;
  }
  LARGE_INTEGER size;
  bool ok = GetFileType(file) == FILE_TYPE_DISK && GetFileSizeEx(file, &size);
  if (ok && size.QuadPart != 0) {
    unsigned char header[28]{}, zeros[28]{};
    DWORD count = 0;
    DWORD wanted = size.QuadPart < 28 ? (DWORD)size.QuadPart : 28;
    // In PERSIST journal mode SQLite clears the journal header on commit.
    ok = !wal && read_at(file, header, wanted, 0, &count) && count == wanted &&
      memcmp(header, zeros, wanted) == 0;
  }
  CloseHandle(file);
  return ok;
}
bool valid(Source &s) {
  if (s.changed) return false;
  HANDLE fresh = open_shared(s.path);
  Stamp observed{};
  bool ok = stamp(fresh, observed) && same(s.baseline, observed) &&
    clear_sidecar(s.wal, true) && clear_sidecar(s.journal, false);
  if (fresh != INVALID_HANDLE_VALUE) CloseHandle(fresh);
  if (!ok) s.changed = true;
  return ok;
}
bool begin_read(Source &s, bool first) {
  if (s.changed || s.active) return false;
  HANDLE file = open_shared(s.path);
  Stamp observed{};
  if (!stamp(file, observed) || (!first && !same(s.baseline, observed)) ||
      !clear_sidecar(s.wal, true) || !clear_sidecar(s.journal, false)) {
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    s.changed = true;
    return false;
  }
  if (first) s.baseline = observed;
  s.active = file;
  return true;
}
bool end_read(Source &s) {
  if (s.active) CloseHandle(s.active);
  s.active = nullptr;
  return valid(s);
}

int page_read(sqlite3_file *file, void *out, int bytes, int64_t offset) {
  Source *s = reinterpret_cast<PageFile*>(file)->source;
  DWORD actual = 0;
  if (!s || !s->active || bytes < 0 || offset < 0 ||
      !read_at(s->active, out, (DWORD)bytes, offset, &actual)) return IOERR;
  if (actual == (DWORD)bytes) return OK;
  memset(static_cast<char*>(out) + actual, 0, bytes - actual);
  return SHORT_READ;
}
const sqlite3_io_methods io = {
  1, [](sqlite3_file*) { return OK; }, page_read,
  [](sqlite3_file*, const void*, int, int64_t) { return READONLY; },
  [](sqlite3_file*, int64_t) { return READONLY; }, [](sqlite3_file*, int) { return READONLY; },
  [](sqlite3_file *f, int64_t *size) { *size = reinterpret_cast<PageFile*>(f)->source->baseline.size; return OK; },
  [](sqlite3_file*, int level) { return level <= 1 ? OK : READONLY; },
  [](sqlite3_file*, int) { return OK; }, [](sqlite3_file*, int *locked) { *locked = 0; return OK; },
  [](sqlite3_file*, int, void*) { return NOTFOUND; }, [](sqlite3_file*) { return 4096; },
  [](sqlite3_file*) { return 0x2000; } // SQLITE_IOCAP_IMMUTABLE within a checked operation
};
int vfs_open(sqlite3_vfs*, const char *name, sqlite3_file *file, int flags, int *opened) {
  file->pMethods = nullptr;
  if (!name || (flags & (0x100 | 1 | 2 | 4 | 8)) != (0x100 | 1)) return CANTOPEN; // main + readonly
  for (auto &s : sources) if (s.id && s.active && strcmp(s.alias, name) == 0) {
    reinterpret_cast<PageFile*>(file)->source = &s;
    file->pMethods = &io;
    if (opened) *opened = 1;
    return OK;
  }
  return CANTOPEN;
}
bool resolve() {
  if (sql.library) return true;
  HMODULE library = LoadLibraryExW(L"winsqlite3.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!library) return false;
  sqlite3_vfs *system = nullptr;
#define BIND(n) sql.n = reinterpret_cast<decltype(sql.n)>(GetProcAddress(library, "sqlite3_" #n)); if (!sql.n) goto fail
  BIND(open_v2); BIND(close); BIND(prepare_v3); BIND(step); BIND(finalize); BIND(bind_text); BIND(bind_int64);
  BIND(column_type); BIND(column_count); BIND(column_bytes); BIND(column_int64); BIND(column_double);
  BIND(column_text); BIND(column_blob); BIND(db_config); BIND(set_authorizer); BIND(limit); BIND(progress_handler);
  BIND(vfs_find); BIND(vfs_register); BIND(vfs_unregister);
#undef BIND
  system = sql.vfs_find(nullptr);
  if (!system) goto fail;
  snprintf(vfs_name, sizeof(vfs_name), "PsyReaSFX-Soundminer-%p", (void*)&vfs);
  vfs.iVersion = 1; vfs.szOsFile = sizeof(PageFile); vfs.mxPathname = 64; vfs.zName = vfs_name;
  vfs.xOpen = vfs_open;
  vfs.xDelete = [](sqlite3_vfs*, const char*, int) { return READONLY; };
  vfs.xAccess = [](sqlite3_vfs*, const char*, int, int *exists) { *exists = 0; return OK; };
  vfs.xFullPathname = [](sqlite3_vfs*, const char *name, int max, char *out) {
    if (!name || strlen(name) >= (size_t)max) return CANTOPEN;
    strcpy(out, name); return OK;
  };
  // Delegate clock and randomness only. File operations are never delegated.
  vfs.pAppData = system;
  vfs.xRandomness = [](sqlite3_vfs *v, int n, char *b) { auto *p = (sqlite3_vfs*)v->pAppData; return p->xRandomness(p,n,b); };
  vfs.xSleep = [](sqlite3_vfs *v, int n) { auto *p = (sqlite3_vfs*)v->pAppData; return p->xSleep(p,n); };
  vfs.xCurrentTime = [](sqlite3_vfs *v, double *d) { auto *p = (sqlite3_vfs*)v->pAppData; return p->xCurrentTime(p,d); };
  if (sql.vfs_register(&vfs, 0) != OK) goto fail;
  sql.library = library;
  return true;
fail:
  FreeLibrary(library); sql = {}; return false;
}
wchar_t *suffix(const wchar_t *path, const wchar_t *extra) {
  size_t length = wcslen(path) + wcslen(extra) + 1;
  wchar_t *result = (wchar_t*)malloc(length * sizeof(wchar_t));
  if (result) { wcscpy(result, path); wcscat(result, extra); }
  return result;
}
void release(Source &s) {
  if (s.db) sql.close(s.db);
  if (s.active) CloseHandle(s.active);
  free(s.reply.data); free(s.path); free(s.wal); free(s.journal);
  s = {};
}
bool eq(const char *s, const char *v) { return s && strcmp(s,v) == 0; }
int authorize(void *user, int action, const char *table, const char *column, const char *db, const char *context) {
  constexpr int DENY = 1, SELECT = 21, READ = 20, FUNCTION = 31, PRAGMA = 19;
  if (context || (db && !eq(db, "main"))) return DENY;
  if (action == SELECT) return OK;
  if (action == READ && eq(table,"justinmetadata")) return OK;
  if (!static_cast<Source*>(user)->searching)
    return action == READ && (eq(table,"waveform") || eq(table,"overviews")) ? OK : DENY;
  if (action == READ && (eq(table,"sqlite_master") || eq(table,"sqlite_schema") || eq(table,"fulltext") ||
      eq(table,"fulltext_segdir") || eq(table,"fulltext_segments") || eq(table,"fulltext_docsize") ||
      eq(table,"fulltext_stat"))) return OK;
  if (action == FUNCTION && eq(column, "match")) return OK;
  if (action == PRAGMA && eq(table, "data_version") && !column) return OK;
  return DENY;
}
bool number(const char *value, int64_t &result) {
  if (!value || !*value || strlen(value) > 20) return false;
  char *end;
  errno = 0; result = _strtoi64(value, &end, 10);
  return !*end && errno != ERANGE;
}
int progress(void *user) {
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  return now.QuadPart >= static_cast<Source*>(user)->deadline.QuadPart;
}
void time_limit(Source &s, int milliseconds) {
  LARGE_INTEGER frequency;
  QueryPerformanceFrequency(&frequency); QueryPerformanceCounter(&s.deadline);
  s.deadline.QuadPart += (frequency.QuadPart * milliseconds) / 1000;
  sql.progress_handler(s.db, 256, progress, &s);
}

bool field(Reply &r, int column, char type, const void *bytes, size_t count, bool hex) {
  size_t length = hex ? count * 2 : count;
  char head[48];
  int n = snprintf(head, sizeof(head), "%d%c%zu:", column, type, length);
  if (count > MAX_RECORD || n <= 0 || !r.append(head, n)) return false;
  if (!hex) return r.append(bytes, length);
  if (!r.reserve(length)) return false;
  const unsigned char *in = static_cast<const unsigned char*>(bytes);
  const char digits[] = "0123456789abcdef";
  for (size_t i = 0; i < count; ++i) {
    r.data[r.used++] = digits[in[i] >> 4]; r.data[r.used++] = digits[in[i] & 15];
  }
  r.data[r.used] = 0;
  return true;
}
bool row(Reply &r, sqlite3_stmt *stmt) {
  for (int i = 0, count = sql.column_count(stmt); i < count; ++i) {
    int kind = sql.column_type(stmt, i);
    if (kind == 5) continue; // absent Lua key for SQL NULL
    if (kind == 1) {
      char value[32];
      int n = snprintf(value, sizeof(value), "%lld", (long long)sql.column_int64(stmt,i));
      if (!field(r,i,'i',value,n,false)) return false;
    } else if (kind == 2) {
      double value = sql.column_double(stmt,i);
      if (!isfinite(value) || !field(r,i,'d',&value,sizeof(value),true)) return false;
    } else {
      const void *bytes = kind == 3 ? (const void*)sql.column_text(stmt,i) : sql.column_blob(stmt,i);
      int n = sql.column_bytes(stmt,i);
      if (n < 0 || (n && !bytes) || (kind == 3 && !bytes)) return false;
      bool hex = kind == 4 || (n && memchr(bytes,0,n));
      if (!field(r,i,hex?'x':'s',bytes,n,hex)) return false;
    }
  }
  return true;
}
bool quoted_identifier(const char *input, char *out, size_t space) {
  if (!input || !*input || strlen(input) > 512) return false;
  size_t n = 0; out[n++] = '"';
  for (; *input; ++input) {
    if ((unsigned char)*input < 32 || n + 4 >= space) return false;
    if (*input == '"') out[n++] = '"';
    out[n++] = *input;
  }
  out[n++] = '"'; out[n] = 0;
  return true;
}
const char *query(Source &s, const char *op, const char *key, const char *index, int limit) {
  if (!op || !key || strlen(key) > 32768 || limit < 1 || limit > 128) return "!argument";
  const bool paths = eq(op,"paths"), scan = paths || eq(op,"rows");
  const bool by_id = eq(op,"metadata_id") || eq(op,"wave_id");
  const bool hash = eq(op,"cache_hash"), path = eq(op,"cache_path");
  char statement[1400];
  int64_t id = INT64_MIN;
  if (scan || by_id) {
    if ((!scan || *key) && !number(key,id)) return "!argument";
    if (scan && *key) {
      if (id == INT64_MAX) return "+";
      ++id;
    }
    char projection[64] = "*";
    if (paths) {
      if (!index || index[0] < '1' || index[0] > '7' || index[1]) return "!argument";
      const int mask = *index - '0';
      snprintf(projection,sizeof(projection),"%s,%s,%s",mask&1?"FilePath":"NULL",
        mask&2?"Pathname":"NULL",mask&4?"Filename":"NULL");
    }
    snprintf(statement, sizeof(statement), "SELECT _rowid_,%s FROM main.%s WHERE _rowid_ %s ?1 ORDER BY _rowid_ LIMIT ?2",
      projection, eq(op,"wave_id") ? "waveform" : "justinmetadata", scan ? ">=" : "=");
  } else if (hash || path) {
    char escaped[1050];
    if (!quoted_identifier(index, escaped, sizeof(escaped))) return "!argument";
    snprintf(statement,sizeof(statement),"SELECT _rowid_,* FROM main.overviews INDEXED BY %s WHERE %s COLLATE BINARY=?1 LIMIT ?2",
      escaped, hash ? "filepathhash" : "filepath");
  } else return "!argument";
  sqlite3_stmt *stmt = nullptr;
  // SQLITE_PREPARE_NO_VTAB: a virtual table impersonating metadata/cache
  // cannot run a module. Only the separately checked FTS query permits one.
  int status = sql.prepare_v3(s.db,statement,-1,4,&stmt,nullptr);
  if (status == OK) status = scan || by_id ? sql.bind_int64(stmt,1,id) : sql.bind_text(stmt,1,key,-1,nullptr);
  if (status == OK) status = sql.bind_int64(stmt,2,scan ? limit : 1);
  s.reply.used = 0;
  bool ok = s.reply.append("+",1);
  if (status == OK && ok) {
    if (!scan) time_limit(s,25);
    while ((status = sql.step(stmt)) == ROW) {
      if (!(ok = row(s.reply,stmt)) || s.reply.used >= TARGET_BATCH) break;
    }
    if (!scan) sql.progress_handler(s.db,0,nullptr,nullptr);
  }
  if (stmt) sql.finalize(stmt);
  if (!ok) return "!record";
  return status == ROW || status == DONE ? s.reply.data : "!query";
}

// Accept the external-content declaration used by Soundminer. Tokenize the
// stored declaration as data. Only SQLite's built-in tokenizers are eligible.
struct SchemaTokens {
  const char *p;
  char word[256];
  bool next() {
    p += strspn(p," \t\r\n"); word[0] = 0;
    if (!*p) return false;
    char quote = strchr("'\"\x60[",*p) ? *p++ : 0;
    if (quote == '[') quote = ']';
    size_t n = 0;
    if (!quote && strchr("(),=;",*p)) word[n++] = *p++;
    else while (*p) {
      if (quote && *p == quote) {
        ++p;
        if (*p != quote) { word[n] = 0; return n > 0; }
      } else if (!quote && strchr(" \t\r\n(),=;",*p)) break;
      if (n + 1 >= sizeof(word)) return false;
      word[n++] = *p++;
    }
    word[n] = 0;
    return n > 0 && !quote;
  }
  bool take(const char *expected) { return next() && !_stricmp(word,expected); }
};
bool supported_fts(const char *decl) {
  if (!decl || strlen(decl) > 65536) return false;
  SchemaTokens t{decl};
  if (!t.take("create") || !t.take("virtual") || !t.take("table") || !t.take("fulltext") ||
      !t.take("using") || !t.next() || (_stricmp(t.word,"fts4") && _stricmp(t.word,"fts3")) || !t.take("(")) return false;
  bool content = false;
  for (;;) {
    if (!t.next()) return false;
    bool external = !_stricmp(t.word,"content"), tokenizer = !_stricmp(t.word,"tokenize");
    if (!t.next()) return false;
    if (eq(t.word,"=")) {
      if (external) {
        if (content || !t.take("justinmetadata")) return false;
        content = true;
      } else if (tokenizer) {
        if (!t.next() || (_stricmp(t.word,"unicode61") && _stricmp(t.word,"simple") && _stricmp(t.word,"porter"))) return false;
      } else return false;
      if (!t.next()) return false;
      if (tokenizer && !strncmp(t.word,"remove_diacritics=",18) && strlen(t.word)==19 &&
          t.word[18]>='0' && t.word[18]<='2') {
        if (!t.next()) return false;
      }
    }
    if (eq(t.word,")")) return content && t.p[strspn(t.p," \t\r\n;")] == '\0';
    if (!eq(t.word,",")) return false;
  }
}
bool has_fts(Source &s) {
  if (s.fts) return s.fts > 0;
  sqlite3_stmt *stmt = nullptr;
  const char *lookup = "SELECT name,type,rootpage,sql FROM main.sqlite_master WHERE name IN "
    "('fulltext','justinmetadata','fulltext_segments','fulltext_segdir','fulltext_docsize','fulltext_stat')";
  int status = sql.prepare_v3(s.db,lookup,-1,4,&stmt,nullptr);
  bool content = false, segments = false, segdir = false, declared = false;
  if (status == OK) while ((status = sql.step(stmt)) == ROW) {
    const char *name = (const char*)sql.column_text(stmt,0);
    if (!eq((const char*)sql.column_text(stmt,1),"table")) break;
    int64_t root = sql.column_int64(stmt,2);
    if (eq(name,"fulltext")) {
      if (root != 0 || !supported_fts((const char*)sql.column_text(stmt,3))) break;
      declared = true;
    } else {
      // FTS reads its own shadow tables internally with the usual SQLite
      // compiler. Require physical tables before allowing that module to run.
      if (root <= 0) break;
      if (eq(name,"justinmetadata")) content = true;
      if (eq(name,"fulltext_segments")) segments = true;
      if (eq(name,"fulltext_segdir")) segdir = true;
    }
  }
  bool ok = status == DONE && content && segments && segdir && declared;
  if (stmt) sql.finalize(stmt);
  s.fts = ok ? 1 : -1;
  return ok;
}
bool term_char(unsigned char c) {
  return c >= 128 || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
}
bool match_expression(const char *text, char *out) {
  if (!text || strlen(text) > 384) return false;
  size_t used = 0;
  int terms = 0;
  while (*text) {
    while (*text && !term_char(*text)) {
      // Structured PRS searches, FTS operators and punctuation use the
      // regular catalog search. Do not reinterpret them as different terms.
      if (!strchr(" \t\r\n",*text)) return false;
      ++text;
    }
    if (!*text) break;
    const char *start = text;
    while (term_char(*text)) ++text;
    size_t bytes = text-start;
    if (bytes > 96 || ++terms > 12) return false;
    if (terms > 1) out[used++]=' '; // implicit AND works with both FTS3 parser builds
    out[used++]='"'; memcpy(out+used,start,bytes); used+=bytes;
    // FTS3/4 expects the prefix star INSIDE the quoted term.
    out[used++]='*'; out[used++]='"';
  }
  out[used] = 0;
  return terms > 0;
}
const char *search(Source &s, const char *terms, int limit) {
  char expression[512];
  if (limit < 1 || limit > 40 || !match_expression(terms,expression) || !has_fts(s)) return "!unsupported";
  sqlite3_stmt *stmt = nullptr;
  time_limit(s,20);
  int status = sql.prepare_v3(s.db,"SELECT docid FROM main.fulltext WHERE fulltext MATCH ?1 LIMIT ?2",-1,0,&stmt,nullptr);
  if (status == OK) status = sql.bind_text(stmt,1,expression,-1,nullptr);
  if (status == OK) status = sql.bind_int64(stmt,2,limit);
  s.reply.used = 0;
  bool ok = s.reply.append("+",1);
  if (status == OK && ok) {
    while ((status = sql.step(stmt)) == ROW) {
      char value[32];
      int n = snprintf(value,sizeof(value),"%lld\n",(long long)sql.column_int64(stmt,0));
      if (!(ok = s.reply.append(value,n))) break;
    }
  }
  if (stmt) sql.finalize(stmt);
  sql.progress_handler(s.db,0,nullptr,nullptr);
  return status == DONE && ok ? s.reply.data : "!unsupported";
}
} // namespace

extern "C" int prs_sm_open(const char *path) {
  if (!resolve()) return 0; // unavailable OS capability; Lua has a shared reader
  Source *s = nullptr;
  for (auto &candidate : sources) if (!candidate.id) { s = &candidate; break; }
  if (!s) return 0;
  s->path = prs_absolute_disk_path(path);
  if (!s->path) return 0; // retain the validated shared reader for unsupported path syntax
  s->wal = suffix(s->path,L"-wal"); s->journal = suffix(s->path,L"-journal");
  if (!s->wal || !s->journal || !begin_read(*s,true)) { release(*s); return -1; }
  do { serial = serial % 0x7fffffffu + 1; } while (source_for((int)serial));
  s->id = (int)serial;
  snprintf(s->alias,sizeof(s->alias),"prs-sm-source-%u",serial);
  int status = sql.open_v2(s->alias,&s->db,1|0x8000,vfs_name); // READONLY | NOMUTEX
  bool configured = false;
  if (status == OK) {
    configured = sql.db_config(s->db,1017,0,nullptr) == OK && // TRUSTED_SCHEMA
      sql.db_config(s->db,1010,1,nullptr) == OK && // DEFENSIVE
      sql.db_config(s->db,1015,0,nullptr) == OK && // ENABLE_VIEW
      sql.db_config(s->db,1003,0,nullptr) == OK && // ENABLE_TRIGGER
      sql.db_config(s->db,1005,0,nullptr) == OK;   // ENABLE_LOAD_EXTENSION
    sql.limit(s->db,0,MAX_RECORD); // LENGTH
    sql.limit(s->db,7,0); // ATTACHED
    status = sql.set_authorizer(s->db,authorize,s);
  }
  if (!end_read(*s) || status != OK) { release(*s); return -1; }
  if (!configured) { release(*s); return 0; }
  return s->id;
}
extern "C" bool prs_sm_valid(int id) { Source *s = source_for(id); return s && valid(*s); }
extern "C" const char *prs_sm_read(int id, const char *op, const char *key, const char *index, int limit) {
  Source *s = source_for(id);
  if (!s || !begin_read(*s,false)) return "!changed";
  const char *answer = query(*s,op,key,index,limit);
  return end_read(*s) ? answer : "!changed";
}
extern "C" const char *prs_sm_search(int id, const char *terms, int limit) {
  Source *s = source_for(id);
  if (!s || !begin_read(*s,false)) return "!changed";
  s->searching = true;
  const char *answer = search(*s,terms,limit);
  s->searching = false;
  return end_read(*s) ? answer : "!changed";
}
extern "C" void prs_sm_close(int id) { if (Source *s = source_for(id)) release(*s); }
extern "C" void prs_sm_unload() {
  for (auto &s : sources) if (s.id) release(s);
  if (sql.library) { sql.vfs_unregister(&vfs); FreeLibrary(sql.library); sql = {}; }
}
extern "C" const char *prs_sm_drives() {
  static char letters[27];
  DWORD mask = GetLogicalDrives();
  int count = 0;
  for (int i = 0; i < 26; ++i) if (mask & (1u << i)) {
    wchar_t root[] = L"A:\\";
    root[0] += i;
    UINT type = GetDriveTypeW(root);
    if (type == DRIVE_FIXED || type == DRIVE_REMOVABLE || type == DRIVE_RAMDISK) letters[count++] = (char)root[0];
  }
  letters[count] = 0;
  return letters;
}
