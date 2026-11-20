// Main-thread-only handle table. No hooks into playback, no file association,
// no project state and no audio file paths handed to REAPER/SWS.
#include "reaper_plugin.h"
#include "reader.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
extern "C" void *prs_make_decoder(PrsAudio *);
extern "C" void prs_free_decoder(void *);
static PCM_source *(*from_simple)(ISimpleMediaDecoder *, const char *);
static reaper_plugin_info_t *host;
struct Slot { int id; PrsAudio *reader; };
static Slot slots[32];
static unsigned serial;
static Slot *lookup(int id) {
  if (id>0) for (auto &s:slots) if(s.id==id) return &s;
  return nullptr;
}
static int open_stream(const char *path, double duration, double lo, double hi, bool reverse) {
  for(auto &s:slots) if(!s.reader) {
    PrsAudio *r=prs_open(path,duration,lo,hi,reverse);
    if(!r) return 0;
    do {serial=serial%0x7fffffffu+1;} while(lookup((int)serial));
    s.id=(int)serial;s.reader=r;return s.id;
  }
  return 0;
}
static void close_stream(int id) {if(auto *s=lookup(id)){prs_close(s->reader);*s={};}}
static const char *peaks(int id,int points,bool channels) {
  auto *s=lookup(id);return s?prs_peaks(s->reader,points,channels):"";
}
// Create via REAPER's own ReaScript factory: the resulting PCM_source is a
// host-validated object. Consume exactly one private token. No file handler.
static PCM_source *from_type(const char *type,int) {
  static const char prefix[]="PRS_AUDITION_";
  if(!type || strncmp(type,prefix,sizeof(prefix)-1)) return nullptr;
  const char *n=type+sizeof(prefix)-1;
  if(!*n || *n<'1'||*n>'9')return nullptr;
  char *end;unsigned long id=strtoul(n,&end,10);
  if(*end || id>0x7fffffffu)return nullptr;
  Slot *s=lookup((int)id);if(!s)return nullptr;
  PrsAudio *r=s->reader;*s={};
  auto *d=static_cast<ISimpleMediaDecoder*>(prs_make_decoder(r));
  if(!d)return nullptr;
  auto *src=from_simple(d,nullptr);if(!src)prs_free_decoder(d);
  return src;
}
static PCM_source *never_file(const char *,int){return nullptr;}
static const char *no_ext(int,const char **){return nullptr;}
static pcmsrc_register_t provider={from_type,never_file,no_ext};
static void *open_va(void **a,int n) {
  if(n!=5 || !a[0] || !a[1] || !a[2] || !a[3])return nullptr;
  return (void*)(intptr_t)open_stream((const char*)a[0],*(double*)a[1],*(double*)a[2],*(double*)a[3],!!a[4]);
}
static void *close_va(void **a,int n){if(n==1)close_stream((int)(intptr_t)a[0]);return nullptr;}
static void *peaks_va(void **a,int n){return (void*)(n==3?peaks((int)(intptr_t)a[0],(int)(intptr_t)a[1],!!a[2]):"");}
struct Registration {const char *key;void *value;};
extern "C" void prs_quick_init(const char *(*)());
extern "C" void prs_quick_unload();
extern "C" int prs_quick_open(const char*,const char*,bool);
extern "C" bool prs_quick_add(int,const char*,const char*);
extern "C" bool prs_quick_close(int,bool);
extern "C" const char *prs_quick_find(int,const char*);
static void *qo_va(void **a,int n){return (void*)(intptr_t)(n==3?prs_quick_open((const char*)a[0],(const char*)a[1],!!a[2]):0);}
static void *qa_va(void **a,int n){return (void*)(intptr_t)(n==3&&prs_quick_add((int)(intptr_t)a[0],(const char*)a[1],(const char*)a[2]));}
static void *qc_va(void **a,int n){return (void*)(intptr_t)(n==2&&prs_quick_close((int)(intptr_t)a[0],!!a[1]));}
static void *qf_va(void **a,int n){return (void*)(n==2?prs_quick_find((int)(intptr_t)a[0],(const char*)a[1]):"");}
extern "C" int prs_sm_open(const char*);
extern "C" void prs_sm_close(int);
extern "C" bool prs_sm_valid(int);
extern "C" const char *prs_sm_read(int,const char*,const char*,const char*,int);
extern "C" const char *prs_sm_search(int,const char*,int);
extern "C" const char *prs_sm_drives();
extern "C" void prs_sm_unload();
static void *sm_open_va(void **a,int n) { return (void*)(intptr_t)(n == 1 ? prs_sm_open((const char*)a[0]) : 0); }
static void *sm_close_va(void **a,int n) { if (n == 1) prs_sm_close((int)(intptr_t)a[0]); return nullptr; }
static void *sm_valid_va(void **a,int n) { return (void*)(intptr_t)(n == 1 && prs_sm_valid((int)(intptr_t)a[0])); }
static void *sm_read_va(void **a,int n) {
  return (void*)(n == 5 ? prs_sm_read((int)(intptr_t)a[0],(const char*)a[1],(const char*)a[2],
    (const char*)a[3],(int)(intptr_t)a[4]) : "!argument");
}
static void *sm_search_va(void **a,int n) {
  return (void*)(n == 3 ? prs_sm_search((int)(intptr_t)a[0],(const char*)a[1],(int)(intptr_t)a[2]) : "!argument");
}
static void *sm_drives_va(void**,int n) { return (void*)(n == 0 ? prs_sm_drives() : ""); }
#define REG(name,func,va,def) {"API_" name,(void*)func},{"APIvararg_" name,(void*)va},{"APIdef_" name,(void*)def}
static Registration registrations[]={
  REG("PRS_SM_Open",prs_sm_open,sm_open_va,"int\0const char*\0path\0Open a generation-checked read-only Soundminer SQLite reader.\0"),
  REG("PRS_SM_Close",prs_sm_close,sm_close_va,"void\0int\0id\0Close a Soundminer SQLite reader.\0"),
  REG("PRS_SM_Valid",prs_sm_valid,sm_valid_va,"bool\0int\0id\0Check the source generation and its journal state.\0"),
  REG("PRS_SM_Read",prs_sm_read,sm_read_va,"const char*\0int,const char*,const char*,const char*,int\0id,operation,key,indexName,limit\0Read a bounded batch or one indexed Soundminer row.\0"),
  REG("PRS_SM_Search",prs_sm_search,sm_search_va,"const char*\0int,const char*,int\0id,terms,limit\0Search an existing compatible Soundminer full-text index.\0"),
  REG("PRS_SM_LocalDrives",prs_sm_drives,sm_drives_va,"const char*\0\0\0List local Windows data drive letters.\0"),
  REG("PRS_Quick_Open",prs_quick_open,qo_va,"int\0const char*,const char*,bool\0scope,signature,build\0Open a PRS search projection.\0"),
  REG("PRS_Quick_Add",prs_quick_add,qa_va,"bool\0int,const char*,const char*\0id,offset,text\0Add a search row to a private staging index.\0"),
  REG("PRS_Quick_Close",prs_quick_close,qc_va,"bool\0int,bool\0id,publish\0Close or publish a PRS search projection.\0"),
  REG("PRS_Quick_Find",prs_quick_find,qf_va,"const char*\0int,const char*\0id,term\0Find bounded offsets in a PRS search projection.\0"),
  {"pcmsrc",&provider},
  {"API_PRS_Audio_Open",(void*)open_stream},{"APIvararg_PRS_Audio_Open",(void*)open_va},
  {"APIdef_PRS_Audio_Open",(void*)"int\0const char*,double,double,double,bool\0path,durationHint,startFraction,endFraction,reverse\0Open bounded shared audio. Close the returned token after use.\0"},
  {"API_PRS_Audio_Close",(void*)close_stream},{"APIvararg_PRS_Audio_Close",(void*)close_va},
  {"APIdef_PRS_Audio_Close",(void*)"void\0int\0token\0Release an unconsumed audio token.\0"},
  {"API_PRS_Audio_Peaks",(void*)peaks},{"APIvararg_PRS_Audio_Peaks",(void*)peaks_va},
  {"APIdef_PRS_Audio_Peaks",(void*)"const char*\0int,int,bool\0token,points,multichannel\0Read a bounded batch of waveform peaks.\0"}
};
static unsigned registered;
static void unload() {
  if(host)while(registered){auto &r=registrations[--registered];char key[80];snprintf(key,sizeof(key),"-%s",r.key);host->Register(key,r.value);}
  for(auto &s:slots)if(s.reader)close_stream(s.id);
  prs_quick_unload();
  prs_sm_unload();
  host=nullptr;
}
extern "C" REAPER_PLUGIN_DLL_EXPORT int REAPER_PLUGIN_ENTRYPOINT(REAPER_PLUGIN_HINSTANCE, reaper_plugin_info_t *rec) {
  if(!rec){unload();return 0;}
  if(rec->caller_version!=REAPER_PLUGIN_VERSION || !rec->GetFunc || !rec->Register)return 0;
  from_simple=(decltype(from_simple))rec->GetFunc("PCM_Source_CreateFromSimple");
  if(!from_simple)return 0;
  host=rec;
  prs_quick_init((const char*(*)())rec->GetFunc("GetResourcePath"));
  for(auto &r:registrations){if(!host->Register(r.key,r.value)){unload();return 0;}registered++;}
  return 1;
}
