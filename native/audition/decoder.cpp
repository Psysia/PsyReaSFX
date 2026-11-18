// Only this translation unit crosses the host's C++ ABI. The header is the
// unmodified ISimpleMediaDecoder declaration from the pinned Cockos SDK.
#include "decoder_sdk.hpp"
#include "reader.h"
// Freestanding clang MS-ABI bridge; floating-point execution uses the Win64
// hardware ABI and the C objects provide the CRT.
extern "C" { int _fltused = 0; }

class AuditionDecoder final : public ISimpleMediaDecoder {
  PrsAudio *stream;
  bool online;
public:
  static void *operator new(decltype(sizeof(0)) n) noexcept { return prs_allocate(n); }
  static void operator delete(void *p) noexcept { prs_release(p); }
  explicit AuditionDecoder(PrsAudio *s) : stream(s), online(s != nullptr) {}
  ~AuditionDecoder() override { prs_close(stream); }
  ISimpleMediaDecoder *Duplicate() override {
    auto *s = prs_duplicate(stream);
    if (!s) return nullptr;
    auto *copy = new AuditionDecoder(s);
    if (!copy) prs_close(s);
    return copy;
  }
  void Open(const char *, int, int, int) override { online = prs_valid(stream); }
  void Close(bool) override { online = false; } // the codec owns no open source file
  const char *GetFileName() override { return ""; } // no path for a native sidecar
  const char *GetType() override { return "PRS_SHARED_AUDIO"; }
  void GetInfoString(char *buf,int len,char *title,int tlen) override {
    if (buf && len>0) *buf=0;
    if (title && tlen>0) *title=0;
  }
  bool IsOpen() override { return online; }
  int GetNumChannels() override { return prs_channels(stream); }
  int GetBitsPerSample() override { return prs_bits(stream); }
  double GetSampleRate() override { return prs_rate(stream); }
  INT64 GetLength() override { return prs_length(stream); }
  INT64 GetPosition() override { return prs_position(stream); }
  void SetPosition(INT64 p) override { prs_position_set(stream,p); }
  int ReadSamples(ReaSample *p,int n) override { return online ? prs_samples(stream,p,n) : 0; }
};
extern "C" void *prs_make_decoder(PrsAudio *s) {
  auto *d=new AuditionDecoder(s); if (!d) prs_close(s); return d;
}
extern "C" void prs_free_decoder(void *d) { delete static_cast<AuditionDecoder*>(d); }
