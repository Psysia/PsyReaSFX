#pragma once
#ifdef __cplusplus
extern "C" {
#endif
typedef struct PrsAudio PrsAudio;
PrsAudio *prs_open(const char *utf8, double duration_hint, double lo, double hi, int reverse);
PrsAudio *prs_duplicate(const PrsAudio *);
void prs_close(PrsAudio *);
int prs_channels(const PrsAudio *);
int prs_rate(const PrsAudio *);
int prs_bits(const PrsAudio *);
long long prs_length(const PrsAudio *);
long long prs_position(const PrsAudio *);
void prs_position_set(PrsAudio *, long long);
int prs_samples(PrsAudio *, double *, int);
int prs_valid(PrsAudio *);
const char *prs_peaks(PrsAudio *, int points, int multichannel);
void *prs_allocate(unsigned long long);
void prs_release(void *);
#ifdef __cplusplus
}
#endif
