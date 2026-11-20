// The codecs only know these callbacks. No fopen, memory mapping, native
// decoder pathname or standing OS handle to the user's original is involved.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "reader.h"
#define DR_WAV_IMPLEMENTATION
#define DR_WAV_NO_STDIO
#include "vendor/dr_wav.h"
#define DR_FLAC_IMPLEMENTATION
#define DR_FLAC_NO_STDIO
#include "vendor/dr_flac.h"
#define DR_MP3_IMPLEMENTATION
#define DR_MP3_NO_STDIO
#include "vendor/dr_mp3.h"

enum { WINDOW = 32768, BLOCK = 1024, MAX_CH = 64, PEAK_BATCH = 64 };
typedef struct { uint64_t size, write, change; DWORD volume, high, low; } Stamp;
typedef enum { WAVE, FLAC, MP3 } Format;
struct PrsAudio {
  wchar_t *path;
  Stamp stamp;
  uint64_t offset, cache_start, bytes_read, byte_limit;
  unsigned cached, reads, open_read_limit;
  unsigned char window[WINDOW];
  int failed, initialized, channels, rate, bits, reverse;
  Format kind;
  union { drwav wav; drflac *flac; drmp3 mp3; } decoder;
  int64_t frames, lo, hi, position, decoder_pos;
  double duration_hint;
  float *scratch;
  int point, points, peak_channel_count;
  int64_t bucket_consumed;
  float maxima[8];
  char reply[48 + PEAK_BATCH * 8 * 4];
};
void *prs_allocate(unsigned long long n) { return calloc(1, (size_t)n); }
void prs_release(void *p) { free(p); }
static uint64_t ft(FILETIME t) { return ((uint64_t)t.dwHighDateTime << 32) | t.dwLowDateTime; }
static HANDLE open_input(const wchar_t *path) {
  return CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
    NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
}
static int stamp(HANDLE h, Stamp *s) {
  BY_HANDLE_FILE_INFORMATION i;
  FILE_BASIC_INFO basic;
  if (h == INVALID_HANDLE_VALUE || GetFileType(h) != FILE_TYPE_DISK ||
      !GetFileInformationByHandle(h, &i) || (i.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ||
      !GetFileInformationByHandleEx(h, FileBasicInfo, &basic, sizeof(basic))) return 0;
  s->size = ((uint64_t)i.nFileSizeHigh << 32) | i.nFileSizeLow;
  s->write = ft(i.ftLastWriteTime); s->change = basic.ChangeTime.QuadPart;
  s->volume = i.dwVolumeSerialNumber; s->high = i.nFileIndexHigh; s->low = i.nFileIndexLow;
  return s->size > 0 && s->size <= INT64_MAX;
}
static int same(const Stamp *a, const Stamp *b) {
  return a->size == b->size && a->write == b->write && a->change == b->change &&
    a->volume == b->volume && a->high == b->high && a->low == b->low;
}
int prs_valid(PrsAudio *a) {
  if (!a || a->failed) return 0;
  Stamp s; HANDLE h = open_input(a->path);
  int ok = stamp(h, &s) && same(&a->stamp, &s);
  if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
  if (!ok) a->failed = 1;
  return ok;
}
static int fill(PrsAudio *a) {
  DWORD n = 0;
  uint64_t left = a->stamp.size - a->offset;
  DWORD want = (DWORD)(left < WINDOW ? left : WINDOW);
  if (a->failed || !want) return 0;
  if (a->bytes_read + want > a->byte_limit || a->reads >= a->open_read_limit) { a->failed = 1; return 0; }
  HANDLE h = open_input(a->path);
  Stamp s; LARGE_INTEGER where; where.QuadPart = (LONGLONG)a->offset;
  int ok = stamp(h, &s) && same(&s, &a->stamp) &&
    SetFilePointerEx(h, where, NULL, FILE_BEGIN) && ReadFile(h, a->window, want, &n, NULL) &&
    n == want && stamp(h, &s) && same(&s, &a->stamp);
  if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
  if (!ok) { a->failed = 1; return 0; }
  a->bytes_read += n; a->reads++;
  a->cache_start = a->offset; a->cached = n;
  return 1;
}
static size_t read_bytes(void *opaque, void *dst, size_t count) {
  PrsAudio *a = opaque; size_t done = 0;
  while (done < count && !a->failed && a->offset < a->stamp.size) {
    if (a->offset < a->cache_start || a->offset - a->cache_start >= a->cached)
      if (!fill(a)) break;
    size_t at = (size_t)(a->offset - a->cache_start), take = a->cached - at;
    if (take > count - done) take = count - done;
    memcpy((unsigned char*)dst + done, a->window + at, take);
    a->offset += take; done += take;
  }
  return a->failed ? 0 : done;
}
static int seek_bytes(PrsAudio *a, int offset, int origin) {
  if (a->failed || origin < 0 || origin > 2) return 0;
  uint64_t base = origin == 0 ? 0 : origin == 1 ? a->offset : a->stamp.size;
  if ((offset < 0 && (uint64_t)-(int64_t)offset > base) ||
      (offset >= 0 && (unsigned)offset > a->stamp.size - base)) return 0;
  a->offset = base + (int64_t)offset; return 1;
}
#define CALLBACKS(p) \
  static p##_bool32 p##_seek(void *u, int off, p##_seek_origin whence) {return seek_bytes(u,off,(int)whence);} \
  static p##_bool32 p##_tell(void *u, p##_int64 *out) {*out=(p##_int64)((PrsAudio*)u)->offset; return 1;}
CALLBACKS(drwav)
CALLBACKS(drflac)
CALLBACKS(drmp3)
wchar_t *prs_absolute_disk_path(const char *s) {
  if (!s || !*s || strlen(s) > 32768) return NULL;
  for (const unsigned char *p=(const unsigned char*)s; *p; ++p) if (*p < 32) return NULL;
  int n=MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s,-1,NULL,0);
  if (!n || n>32760) return NULL;
  wchar_t *p=calloc((size_t)n+8,sizeof(*p));
  if (!p || !MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s,-1,p+8,n)) {free(p);return NULL;}
  wchar_t *v=p+8;
  for (int i=0;i<n;i++) if(v[i]==L'/') v[i]=L'\\';
  // Only drive/UNC disk paths. Never interpret a device or pipe name.
  if (n>=4 && ((v[0]>=L'A' && v[0]<=L'Z') || (v[0]>=L'a' && v[0]<=L'z')) && v[1]==L':' && v[2]==L'\\') {
    memmove(p+4,v,n*sizeof(*v)); memcpy(p,L"\\\\?\\",4*sizeof(*v));
  } else if(n>=6 && v[0]==L'\\' && v[1]==L'\\' && v[2]!=L'.' && v[2]!=L'?' && v[2]!=L'\\') {
    wchar_t *share=wcschr(v+2,L'\\');
    if (!share || !_wcsnicmp(share,L"\\pipe\\",6) || !_wcsnicmp(share,L"\\mailslot\\",10)) {free(p);return NULL;}
    memmove(p+8,v+2,(n-2)*sizeof(*v)); memcpy(p,L"\\\\?\\UNC\\",8*sizeof(*v));
  } else {free(p);return NULL;}
  return p;
}
static PrsAudio *open_wide(const wchar_t *path, const Stamp *expected, double hint) {
  PrsAudio *a=calloc(1,sizeof(*a));
  if (!a) return NULL;
  a->path=_wcsdup(path); if (!a->path) goto fail;
  HANDLE h=open_input(path);
  int ok=stamp(h,&a->stamp) && (!expected || same(expected,&a->stamp));
  if (h!=INVALID_HANDLE_VALUE) CloseHandle(h);
  if(!ok) goto fail;
  // Never accidentally scan a whole long file to determine its duration.
  a->byte_limit=512*1024; a->open_read_limit=24; a->duration_hint=hint;
  unsigned char sig[12];
  if(read_bytes(a,sig,sizeof(sig))!=sizeof(sig)) goto fail;
  a->offset=0;
  if(!memcmp(sig,"fLaC",4)) {
    a->kind=FLAC;
    drflac *f=drflac_open(read_bytes,drflac_seek,drflac_tell,a,NULL);
    if(!f) goto fail;
    a->decoder.flac=f; a->initialized=1; a->rate=f->sampleRate;
    a->channels=f->channels; a->bits=f->bitsPerSample; a->frames=f->totalPCMFrameCount;
  } else if(!memcmp(sig,"ID3",3) || (sig[0]==0xff && (sig[1]&0xe0)==0xe0)) {
    a->kind=MP3;
    drmp3 *m=&a->decoder.mp3;
    if(!drmp3_init(m,read_bytes,drmp3_seek,drmp3_tell,NULL,a,NULL)) goto fail;
    a->initialized=1; a->rate=m->sampleRate; a->channels=m->channels; a->bits=32;
    if(m->totalPCMFrameCount!=DRMP3_UINT64_MAX) a->frames=drmp3_get_pcm_frame_count(m);
    else if (hint>0 && hint<=31536000.) a->frames=(int64_t)(hint*a->rate+0.5);
  } else {
    a->kind=WAVE;
    drwav *w=&a->decoder.wav;
    if(!drwav_init_ex(w,read_bytes,drwav_seek,drwav_tell,NULL,a,NULL,0,NULL)) goto fail;
    a->initialized=1; a->rate=w->sampleRate; a->channels=w->channels; a->bits=w->bitsPerSample;
    a->frames=w->totalPCMFrameCount;
  }
  if(a->failed || a->frames<=0 || a->frames>9007199254740991LL ||
     a->channels<=0 || a->channels>MAX_CH || a->rate<=0 || a->rate>1536000) goto fail;
  a->scratch=malloc(sizeof(float)*BLOCK*a->channels);
  if(!a->scratch) goto fail;
  a->byte_limit=UINT64_MAX; a->open_read_limit=UINT32_MAX;
  a->hi=a->frames;
  return a;
fail: prs_close(a); return NULL;
}
PrsAudio *prs_open(const char *utf8,double hint,double lo,double hi,int reverse) {
  if(!(lo>=0 && lo<hi && hi<=1)) return NULL;
  wchar_t *p=prs_absolute_disk_path(utf8); if(!p) return NULL;
  PrsAudio *a=open_wide(p,NULL,hint); free(p);
  if(a) {
    a->lo=(int64_t)(lo*a->frames); a->hi=(int64_t)(hi*a->frames); a->reverse=!!reverse;
    if(a->lo>=a->hi) {prs_close(a);return NULL;}
  }
  return a;
}
PrsAudio *prs_duplicate(const PrsAudio *a) {
  if(!a || a->failed) return NULL;
  PrsAudio *b=open_wide(a->path,&a->stamp,a->duration_hint);
  if(b) {b->lo=a->lo;b->hi=a->hi;b->reverse=a->reverse;}
  return b;
}
void prs_close(PrsAudio *a) {
  if(!a) return;
  if(a->initialized) {
    if(a->kind==WAVE) drwav_uninit(&a->decoder.wav);
    else if(a->kind==FLAC) drflac_close(a->decoder.flac);
    else drmp3_uninit(&a->decoder.mp3);
  }
  free(a->path);free(a->scratch);free(a);
}
int prs_channels(const PrsAudio *a){return a?a->channels:0;}
int prs_bits(const PrsAudio *a){return a?a->bits:0;}
int prs_rate(const PrsAudio *a){return a?a->rate:0;}
long long prs_length(const PrsAudio *a){return a?a->hi-a->lo:0;}
long long prs_position(const PrsAudio *a){return a?a->position:0;}
void prs_position_set(PrsAudio *a,long long pos){if(a) a->position=pos<0?0:pos>prs_length(a)?prs_length(a):pos;}
static int frames(PrsAudio *a,int64_t at,int count) {
  if(a->failed || count<=0 || count>BLOCK) return 0;
  if(at!=a->decoder_pos){
    int ok=a->kind==WAVE?drwav_seek_to_pcm_frame(&a->decoder.wav,at):
      a->kind==FLAC?drflac_seek_to_pcm_frame(a->decoder.flac,at):drmp3_seek_to_pcm_frame(&a->decoder.mp3,at);
    if(!ok) return 0;
  }
  int got=(int)(a->kind==WAVE?drwav_read_pcm_frames_f32(&a->decoder.wav,count,a->scratch):
    a->kind==FLAC?drflac_read_pcm_frames_f32(a->decoder.flac,count,a->scratch):
    drmp3_read_pcm_frames_f32(&a->decoder.mp3,count,a->scratch));
  a->decoder_pos=at+got;return a->failed?0:got;
}
int prs_samples(PrsAudio *a,double *dst,int count) {
  int done=0;
  if (!a || !prs_valid(a)) return 0;
  while(dst && a && done<count && a->position<a->hi-a->lo) {
    int n=count-done; if(n>BLOCK)n=BLOCK;
    if(n>a->hi-a->lo-a->position)n=(int)(a->hi-a->lo-a->position);
    int64_t at=a->reverse?a->hi-a->position-n:a->lo+a->position;
    int got=frames(a,at,n);
    if(!got || (a->reverse && n!=got)) break;
    for(int i=0;i<got;i++) for(int ch=0;ch<a->channels;ch++)
      dst[(size_t)(done+i)*a->channels+ch]=a->scratch[(a->reverse?got-1-i:i)*a->channels+ch];
    a->position+=got;done+=got;if(n!=got)break;
  }
  return done;
}
static int64_t edge(int point,int64_t length,int points) {
  return (length/points)*point + (length%points)*point/points;
}
const char *prs_peaks(PrsAudio *a,int requested,int multi) {
  if(!a || a->failed || requested<32 || requested>4096 || !prs_valid(a)) return "";
  int points=a->frames<requested?(int)a->frames:requested, nch=a->channels>8?8:a->channels;
  int lanes=multi?nch:1;
  if(a->points && (a->points!=points || a->peak_channel_count!=lanes)) return "";
  a->points=points;a->peak_channel_count=lanes;
  int first=a->point,out=0;
  char *data=a->reply+46; LARGE_INTEGER freq,t0,now;
  QueryPerformanceFrequency(&freq); QueryPerformanceCounter(&t0);
  static const char hex[]="0123456789abcdef";
  do {
    if(a->point>=points)break;
    int64_t start=edge(a->point,a->frames,points), end=edge(a->point+1,a->frames,points);
    int64_t width=end-start;
    // Compressed MP3 seeks may scan. Decode it once in forward order; on
    // random-access formats use the same centered windows as the Lua reader.
    if(a->kind!=MP3 && requested<512 && width>256){start+=(width-256)/2;width=256;}
    int64_t left=width-a->bucket_consumed;
    int want=(int)(left>BLOCK?BLOCK:left);
    int got=frames(a,start+a->bucket_consumed,want);
    if(got!=want || !got)return "";
    for(int i=0;i<got;i++)for(int ch=0;ch<(multi?nch:a->channels);ch++) {
      int l=multi?ch:0; float v=fabsf(a->scratch[i*a->channels+ch]);
      if(v>a->maxima[l])a->maxima[l]=v>1?1:v;
    }
    a->bucket_consumed+=got;
    if(a->bucket_consumed==width) {
      for(int l=0;l<lanes;l++){
        unsigned v=(unsigned)(a->maxima[l]*65535.f+0.5f);a->maxima[l]=0;
        for(int shift=12;shift>=0;shift-=4)data[out++]=hex[(v>>shift)&15];
      }
      a->point++;a->bucket_consumed=0;
    }
    QueryPerformanceCounter(&now);
  }while(a->point-first<PEAK_BATCH && (now.QuadPart-t0.QuadPart)*1000<2*freq.QuadPart);
  if(a->point==points && !prs_valid(a))return "";
  int h=snprintf(a->reply,46,"%d:%d:%d:%d:",points,nch,first,a->point);
  memmove(a->reply+h,data,(size_t)out);a->reply[h+out]=0;return a->reply;
}
