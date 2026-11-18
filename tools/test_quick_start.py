"""Time the packaged Lua entry through its first indexed RPC reply with a fixture host."""
import argparse
import ctypes as C
import json
from pathlib import Path
import tempfile
import time

from test_audition_native import host_api, header, method, P, I, S, D


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=Path)
    parser.add_argument("--lua-dll", required=True, type=Path)
    args = parser.parse_args()
    package = args.package.resolve()
    rows = 50000
    with tempfile.TemporaryDirectory(prefix="prs-quick-start-") as tmp:
        resource = Path(tmp).resolve()
        (resource / "Data").mkdir()
        database = resource / "Scripts/PsyReaSFX/index_v3.tsv"
        database.parent.mkdir(parents=True)
        _, api, source, keep = host_api(package / "runtime/audition/reaper_prs_audition.dll", resource)
        wav = resource / "fixture.wav"
        wav.write_bytes(header(96000) + b"\x00\x20"*48000)
        audio_open = api("API_PRS_Audio_Open", I, S, D, D, D, C.c_bool)
        audio_close = api("API_PRS_Audio_Close", None, I)
        qopen = api("API_PRS_Quick_Open", I, S, S, C.c_bool)
        qadd = api("API_PRS_Quick_Add", C.c_bool, I, S, S)
        qfind = api("API_PRS_Quick_Find", S, I, S)
        qclose = api("API_PRS_Quick_Close", C.c_bool, I, C.c_bool)
        offsets = []
        with database.open("wb") as f:
            f.write(b"path\tname\tduration\n")
            for i in range(rows):
                name = f"field {i}" if i < rows-1 else "needle"
                path = str(wav) if i==rows-1 else f"C:/synthetic/{i}.wav"
                row = f"{path}\t{name}\t1"
                offsets.append((str(f.tell()).encode(), row.lower().encode()))
                f.write(row.encode()+b"\n")
        identity = 1  # same synthetic stat as lua_shared_readonly_fixture.lua
        for byte in str(database).encode():
            identity = (identity * 31 + byte) & 0x7fffffff
        sig = f"{identity}|0|{database.stat().st_size}".encode()
        index = qopen(b"prs", sig, True)
        assert index
        for offset, body in offsets:
            assert qadd(index, offset, body)
        assert qclose(index, True)

        lua = C.CDLL(str(args.lua_dll.resolve()))
        def fn(name, result, *params):
            f = getattr(lua, name)
            f.argtypes, f.restype = params, result
            return f
        new = fn("luaL_newstate", P)
        open_libs = fn("luaL_openlibs", None, P)
        close = fn("lua_close", None, P)
        load = fn("luaL_loadstring", I, P, S)
        call = fn("lua_pcallk", I, P, I, I, I, P, P)
        read = fn("lua_tolstring", S, P, I, P)
        integer = fn("lua_tointegerx", C.c_longlong, P, I, P)
        number = fn("lua_tonumberx", D, P, I, P)
        boolean = fn("lua_toboolean", I, P, I)
        push_int = fn("lua_pushinteger", None, P, C.c_longlong)
        push_text = fn("lua_pushstring", P, P, S)
        push_bool = fn("lua_pushboolean", None, P, I)
        push_num = fn("lua_pushnumber", None, P, C.c_double)
        push_fn = fn("lua_pushcclosure", None, P, P, I)
        set_global = fn("lua_setglobal", None, P, S)
        state = new()
        open_libs(state)
        callbacks, errors = [], []
        def bind(name, implementation):
            callback = C.CFUNCTYPE(I, P)(implementation)
            callbacks.append(callback)
            push_fn(state, callback, 0)
            set_global(state, name.encode())
        def mkdir(l):
            folder = Path(read(l,1,None).decode()).resolve()
            if not folder.is_relative_to(resource):
                errors.append(f"Unexpected fixture directory {folder}")
                return 0
            folder.mkdir(parents=True, exist_ok=True)
            return 0
        def add_value(l, push, value):
            push(l, value)
            return 1
        bind("fixture_mkdir", mkdir)
        bind("fixture_clock", lambda l: add_value(l,push_num,time.perf_counter()))
        bind("fixture_defer", lambda l: time.sleep(0.03) or 0)
        bind("fixture_open", lambda l: add_value(l,push_int,qopen(read(l,1,None),read(l,2,None),boolean(l,3))))
        bind("fixture_find", lambda l: add_value(l,push_text,qfind(integer(l,1,None),read(l,2,None))))
        bind("fixture_close", lambda l: add_value(l,push_bool,qclose(integer(l,1,None),boolean(l,2))))
        objects=set()
        def make_source(l):
            name = read(l,1,None).decode()
            token = name.removeprefix("PRS_AUDITION_")
            obj = source(int(token)) if token.isdecimal() else None
            if not obj:
                errors.append("native source factory failed")
                return 0
            objects.add(obj)
            return add_value(l,push_int,obj)
        def first_pcm(l):
            obj = integer(l,1,None)
            if obj not in objects:
                errors.append("preview did not use the protected decoder")
                return add_value(l,push_bool,False)
            buffer=(D*64)()
            frames=method(obj,14,I,C.POINTER(D),I)(obj,buffer,len(buffer))
            return add_value(l,push_bool,frames==64 and buffer[0]==0.25)
        bind("fixture_audio_open",lambda l: add_value(l,push_int,audio_open(
            read(l,1,None),number(l,2,None),number(l,3,None),number(l,4,None),boolean(l,5))))
        bind("fixture_audio_close",lambda l: audio_close(integer(l,1,None)) or 0)
        bind("fixture_source",make_source)
        bind("fixture_pcm",first_pcm)
        # Use the same simulated REAPER API as the headless backend regression.
        setup = Path("tools/lua_webview_selftest.lua").read_text(encoding="utf-8").split("assert(loadfile(entry))()",1)[0]
        script = "arg={" + ",".join(json.dumps(str(p),ensure_ascii=False) for p in
                (package/"PsyReaSFX_Runtime.lua",resource)) + "}\n" + setup + """
reaper.RecursiveCreateDirectory, reaper.time_precise = fixture_mkdir, fixture_clock
reaper.PRS_Quick_Open, reaper.PRS_Quick_Find, reaper.PRS_Quick_Close = fixture_open,fixture_find,fixture_close
reaper.PRS_Audio_Open, reaper.PRS_Audio_Close = fixture_audio_open, fixture_audio_close
reaper.PCM_Source_CreateFromType = fixture_source
reaper.PCM_Source_CreateFromFile = function() error("private-copy fallback on compatible PCM") end
reaper.GetMediaSourceLength = function() return 1,false end
reaper.CF_CreatePreview = function(source) return source end
reaper.CF_Preview_SetValue = function() return true end
reaper.CF_Preview_GetValue = function(_,key) return true,key=="D_LENGTH" and 1 or 0 end
local clicked,first_pcm,query_ms,hydrated
reaper.CF_Preview_Play = function(source)
  local audible=fixture_pcm(source)
  assert(audible,"missing first PCM")
  first_pcm=first_pcm or fixture_clock()
  return true
end
local incoming, cursor = "", 1
reaper.ReaWeb_Receive = function() local message=incoming; incoming=""; return message end
local start = fixture_clock()
assert(loadfile(entry))()
for i=1,150 do
  while cursor<=#messages do
    local m=neural_json_decode(messages[cursor]); cursor=cursor+1
    if m.id=="bench" then
      assert(m.ok and #m.result.items==1 and m.result.items[1].name=="needle")
      assert(AppState.raw.startup_session,"query waited for full startup")
      clicked=fixture_clock();query_ms=(clicked-start)*1000;hydrated=#AppState.raw.assets
      incoming=neural_json_encode({protocol=1,id="play",method="startup.preview",params={path=m.result.items[1].path}})
    elseif m.id=="play" then
      assert(m.ok and m.result and first_pcm,m.error or "preview did not play")
      return neural_json_encode({first_search_reply_ms=query_ms, rows_hydrated=hydrated, total_rows=50000,
        click_to_pcm_with_simulated_host_ms=(first_pcm-clicked)*1000})
    end
    if not clicked and m.event=="state" and m.data.startup and m.data.startup.indexed then
      incoming='{"protocol":1,"id":"bench","method":"startup.search","params":{"query":"needle","explicit":true}}'
    end
  end
  fixture_defer(); deferred()
end
error("quick search did not reply")
"""
        try:
            if load(state,script.encode()) or call(state,0,1,0,None,None):
                raise RuntimeError(read(state,-1,None).decode())
            assert not errors, errors
            print(read(state,-1,None).decode())
        finally:
            close(state)
            for obj in objects:
                method(obj,0,None,C.c_uint)(obj,1)
            keep[1](None,None)  # end the fixture host and release its open reader


if __name__=="__main__":
    main()
