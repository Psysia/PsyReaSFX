// Disposable PRS lookup, not a catalog database. Its only payload is text
// plus offsets into a *specific verified PRS snapshot*. Never open a supplied
// database path; all index files live under the host's own resource path.
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <wchar.h>
#include <string.h>
namespace {
struct db;struct stmt;
HMODULE lib;const char *(*resource)();
#define FN(ret,name,...) ret (*name)(__VA_ARGS__)
FN(int,open_v2,const char*,db**,int,const char*);FN(int,close,db*);
FN(int,exec,db*,const char*,void*,void*,char**);
FN(int,prepare_v2,db*,const char*,int,stmt**,const char**);FN(int,finalize,stmt*);
FN(int,step,stmt*);FN(int,reset,stmt*);FN(int,bind_text,stmt*,int,const char*,int,void(*)(void*));
FN(int,bind_int64,stmt*,int,int64_t);FN(int64_t,column_int64,stmt*,int);FN(const unsigned char*,column_text,stmt*,int);
FN(void,progress_handler,db*,int,int(*)(void*),void*);
#undef FN
const int ROW=100,DONE=101;
struct Index {int id;bool writer,bad;db *file;stmt *insert;wchar_t *target,*temp;char reply[1400];};
Index slots[12];unsigned serial;
Index *get(int id){for(auto &s:slots)if(id>0 && id==s.id)return &s;return nullptr;}
bool resolve(){
  if(lib)return true;
  lib=LoadLibraryExW(L"winsqlite3.dll",nullptr,LOAD_LIBRARY_SEARCH_SYSTEM32);
  if(!lib)return false;
#define BIND(n) n=(decltype(n))GetProcAddress(lib,"sqlite3_" #n);if(!n)goto fail
  BIND(open_v2);BIND(close);BIND(exec);BIND(prepare_v2);BIND(finalize);BIND(step);BIND(reset);
  BIND(bind_text);BIND(bind_int64);BIND(column_int64);BIND(column_text);BIND(progress_handler);
#undef BIND
  return true;
fail:FreeLibrary(lib);lib=nullptr;return false;
}
bool scope_ok(const char *s){
  if(!s)return false;if(!strcmp(s,"prs"))return true;
  if(strlen(s)!=19||strncmp(s,"sm_",3))return false;
  for(int i=3;i<19;i++)if(!strchr("0123456789abcdef",s[i]))return false;
  return true;
}
bool finish(Index *s,bool publish) {
  bool ok=false;
  if(s->insert)finalize(s->insert);
  if(s->writer && publish && !s->bad)ok=!exec(s->file,"COMMIT",nullptr,nullptr,nullptr);
  if(s->file && close(s->file))ok=false;
  if(ok)ok=!!MoveFileExW(s->temp,s->target,MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH);
  if(s->temp)DeleteFileW(s->temp);
  free(s->target);free(s->temp);*s={};return ok;
}
int check_deadline(void *opaque){
  LARGE_INTEGER now;QueryPerformanceCounter(&now);
  return now.QuadPart>=*(LONGLONG*)opaque;
}
// A separator before and after each codepoint makes even a one-character
// query three characters long. Thus short CJK terms and two-letter
// abbreviations can use the same FTS5 index as long substrings.
void projection(const char *text,size_t length,char *out,bool pattern) {
  if(pattern)*out++='*';
  *out++=1;
  for(size_t i=0;i<length;i++) {
    const char c=text[i];
    if(pattern && (c=='[' || c=='?' || c=='*')){*out++='[';*out++=c;*out++=']';}
    else *out++=c;
    if(i+1==length || ((unsigned char)text[i+1]&0xc0)!=0x80)*out++=1;
  }
  if(pattern)*out++='*';
  *out=0;
}
}
extern "C" void prs_quick_init(const char *(*path)()){resource=path;}
extern "C" void prs_quick_unload(){
  for(auto &s:slots)if(s.id)finish(&s,false);
  if(lib){FreeLibrary(lib);lib=nullptr;}resource=nullptr;
}
extern "C" int prs_quick_open(const char *scope,const char *signature,bool build){
  if(!scope_ok(scope)||!signature||!*signature||strlen(signature)>512||!resource||!resolve())return 0;
  const char *r=resource();if(!r||strlen(r)>32000)return 0;
  int n=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,r,-1,nullptr,0);if(!n)return 0;
  Index *s=nullptr;for(auto &v:slots)if(!v.id){s=&v;break;}if(!s)return 0;
  if(build)for(auto &v:slots)if(v.writer)return 0; // never compete with another bulk index build
  s->target=(wchar_t*)calloc(n+160,sizeof(wchar_t));
  if(!s->target)return 0;
  MultiByteToWideChar(CP_UTF8,0,r,-1,s->target,n);
  wcscat(s->target,L"\\Data\\PsyReaSFX-QuickSearch");
  if(build)CreateDirectoryW(s->target,nullptr);
  size_t len=wcslen(s->target);
  swprintf(s->target+len,75,L"\\%hs-v2.sqlite",scope);
  do{serial=serial%0x7fffffffu+1;}while(get((int)serial));
  s->id=(int)serial;s->writer=build;
  const wchar_t *path=s->target;
  if(build){
    s->temp=(wchar_t*)calloc(n+160,sizeof(wchar_t));if(!s->temp){finish(s,false);return 0;}
    swprintf(s->temp,n+160,L"%ls.%lx.%lx.%x.tmp",s->target,GetCurrentProcessId(),GetTickCount(),serial);
    HANDLE h=CreateFileW(s->temp,GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(h==INVALID_HANDLE_VALUE){free(s->temp);s->temp=nullptr;finish(s,false);return 0;}CloseHandle(h);path=s->temp;
  }
  int bytes=WideCharToMultiByte(CP_UTF8,0,path,-1,nullptr,0,nullptr,nullptr);
  char *utf8=(char*)malloc(bytes);if(!utf8){finish(s,false);return 0;}
  WideCharToMultiByte(CP_UTF8,0,path,-1,utf8,bytes,nullptr,nullptr);
  int err=open_v2(utf8,&s->file,build?2:1,nullptr);free(utf8);
  if(err){finish(s,false);return 0;}
  // Writers only ever open a freshly created PRS temp. No journaling is
  // needed: only a closed, committed file can replace the last good index.
  if(build){
    err=exec(s->file,"PRAGMA journal_mode=OFF;PRAGMA synchronous=OFF;BEGIN;CREATE TABLE meta(s TEXT);"
      "CREATE VIRTUAL TABLE quick USING fts5(body,tokenize='trigram',detail=none);",nullptr,nullptr,nullptr);
    stmt *m=nullptr;
    if(!err)err=prepare_v2(s->file,"INSERT INTO meta VALUES(?)",-1,&m,nullptr);
    if(!err)err=bind_text(m,1,signature,-1,nullptr);
    if(!err)err=step(m)==DONE?0:1;
    if(m)finalize(m);
    if(!err)err=prepare_v2(s->file,"INSERT INTO quick(rowid,body) VALUES(?,?)",-1,&s->insert,nullptr);
  }else{
    exec(s->file,"PRAGMA query_only=ON;PRAGMA trusted_schema=OFF;",nullptr,nullptr,nullptr);
    stmt *m=nullptr;err=prepare_v2(s->file,"SELECT s FROM meta LIMIT 1",-1,&m,nullptr);
    if(!err){const char *value=step(m)==ROW?(const char*)column_text(m,0):nullptr;err=!value||strcmp(value,signature);}
    if(m)finalize(m);
  }
  if(err){finish(s,false);return 0;}return s->id;
}
extern "C" bool prs_quick_add(int id,const char *offset,const char *body){
  Index *s=get(id);if(!s||!s->writer||s->bad||!body||!offset||strlen(body)>65536)return false;
  char *end;int64_t at=_strtoi64(offset,&end,10);
  if(end==offset || *end || at<0 || at>9007199254740991LL)return false;
  size_t len=strlen(body);
  char *encoded=(char*)malloc(len*2+2);
  if(!encoded){s->bad=true;return false;}
  projection(body,len,encoded,false);
  s->bad=bind_int64(s->insert,1,at+1) || bind_text(s->insert,2,encoded,-1,(void(*)(void*))-1) ||
    step(s->insert)!=DONE || reset(s->insert);
  free(encoded);return !s->bad;
}
extern "C" bool prs_quick_close(int id,bool publish){auto *s=get(id);return s&&finish(s,publish);}
extern "C" const char *prs_quick_find(int id,const char *term){
  Index *s=get(id);if(!s||s->writer||!term||strlen(term)>512)return "";
  const char *words[16];size_t lengths[16];int count=0;
  char sql[512]="SELECT rowid FROM quick";
  for(const char *p=term;*p && count<16;){
    p+=strspn(p," \t\r\n\f\v");
    size_t n=strcspn(p," \t\r\n\f\v");if(!n)break;
    strcat(sql,count?" AND body GLOB ?":" WHERE body GLOB ?");
    words[count]=p;lengths[count++]=n;p+=n;
  }
  strcat(sql," LIMIT 80");
  stmt *q=nullptr;int used=0;
  LARGE_INTEGER now,freq;QueryPerformanceFrequency(&freq);QueryPerformanceCounter(&now);
  LONGLONG deadline=now.QuadPart+freq.QuadPart/100;
  progress_handler(s->file,500,check_deadline,&deadline);
  if(!prepare_v2(s->file,sql,-1,&q,nullptr)){
    char pattern[4*512+4];bool bound=true;
    for(int i=0;i<count && bound;i++) {
      projection(words[i],lengths[i],pattern,true);
      bound=bind_text(q,i+1,pattern,-1,(void(*)(void*))-1)==0;
    }
    while(bound && step(q)==ROW){
      int written=snprintf(s->reply+used,sizeof(s->reply)-used,"%lld,", (long long)column_int64(q,0)-1);
      if(written<=0||written>=(int)sizeof(s->reply)-used)break;used+=written;
    }
  }
  if(q)finalize(q);progress_handler(s->file,0,nullptr,nullptr);s->reply[used]=0;return s->reply;
}
