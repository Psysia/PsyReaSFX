#pragma once

namespace reaweb {
// ABI prefix of Cockos jsfx/jsfx_api.h (LGPL), Copyright (C) 2004 and onwards,
// Cockos Incorporated. https://github.com/justinfrankel/jsfx
// SX_Instance remains opaque. Accept only the inspected engine ABI version.
struct JsfxEngineApi {
  unsigned version;
  void* (*create)(const char*, const char*, bool*);
  int (*process)(void*, double*, int, int, int, double, int, int, double, double, double, double, double, int);
  void* (*create_ui)(void*, void*, void*, void*);
  void* (*get_ui)(void*);
  void (*delete_ui)(void*);
  void (*destroy)(void*);
  const char* (*name)(void*);
  void (*load)(void*, const char*);
  const char* (*save)(void*, int*);
  int (*count)(void*);
  double (*get)(void*, int, double*, double*, double*);
  void (*param_name)(void*, int, char*, int);
  void (*set)(void*, int, double, int);
  void (*set_midi_ctx)(void*, double (*)(void*, int, double*, double*, double*, double*), void*);
  void (*set_reaper_api)(void* (*)(const char*));
  void (*load_serialized)(void*, const char*, int);
  const char* (*save_serialized)(void*, int*);
  const char* (*filename)(void*);
  int (*latency)(void*);
  void (*update_channels)(void*, int);
  const char** (*pins)(void*, int, int*);
  bool (*changed)(void*);
  void (*display)(void*, int, char*, int, double*);
  int (*is_enum)(void*, int);
};
inline constexpr unsigned jsfx_engine_version = 0xf0f01091;
}
