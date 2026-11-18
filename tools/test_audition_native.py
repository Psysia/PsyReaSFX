"""Exercise the shipping DLL through the REAPER registration ABI, on synthetic media only."""
import argparse
import ctypes as C
from ctypes import c_void_p as P, c_int as I, c_double as D, c_longlong as L, c_char_p as S
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time

def host_api(path, resource):
    exports = {}
    calls = []
    def cb(ret, *args):
        def wrap(func):
            fn = C.CFUNCTYPE(ret,*args)(func)
            calls.append(fn)
            return fn
        return wrap
    @cb(P,P,S)
    def create(dec, name):
        assert not name
        return dec
    @cb(I,S,P)
    def register(key, p):
        exports[key.decode()] = p
        return 1
    directory = C.create_string_buffer(str(resource).encode())
    @cb(P)
    def resource_path():
        return C.addressof(directory)
    @cb(P,S)
    def get_func(key):
        if key == b"PCM_Source_CreateFromSimple": return C.cast(create,P).value
        if key == b"GetResourcePath": return C.cast(resource_path,P).value
        return None
    class Host(C.Structure):
        _fields_=[("version",I),("hwnd",P),("reg",type(register)),("get",type(get_func))]
    host=Host(0x20e,None,register,get_func)
    dll=C.CDLL(str(path.resolve())); entry=dll.ReaperPluginEntry
    entry.argtypes=[P,C.POINTER(Host)]
    assert entry(None,C.byref(host))==1
    def api(name, ret, *args):
        return C.CFUNCTYPE(ret,*args)(exports[name])
    def ctor(token):
        ptr=C.cast(exports["pcmsrc"], C.POINTER(P))[0]
        return C.CFUNCTYPE(P,S,I)(ptr)(f"PRS_AUDITION_{token}".encode(),0)
    return exports,api,ctor,(dll,entry,host,calls)

def method(obj, slot, ret, *args):
    vtbl=C.cast(obj,C.POINTER(C.POINTER(P)))[0]
    return C.CFUNCTYPE(ret,P,*args)(vtbl[slot])

def header(n, rate=48000):
    return struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF",n+36,b"WAVE",b"fmt ",16,1,1,rate,2*rate,2,16,b"data",n)

def read_counts():
    counters=(C.c_ulonglong*6)()
    assert C.windll.kernel32.GetProcessIoCounters(P(-1),C.byref(counters))
    return counters[3]

def main():
    cli=argparse.ArgumentParser();cli.add_argument("dll",type=Path);cli.add_argument("--out",type=Path,required=True)
    opt=cli.parse_args();opt.out.mkdir(parents=True,exist_ok=True)
    resource = tempfile.TemporaryDirectory(dir=opt.out.resolve())
    resource_root = Path(resource.name)
    (resource_root / "Data").mkdir()
    exports,api,source,keep=host_api(opt.dll, resource_root)
    open_=api("API_PRS_Audio_Open",I,S,D,D,D,C.c_bool)
    close=api("API_PRS_Audio_Close",None,I); peaks=api("API_PRS_Audio_Peaks",S,I,I,C.c_bool)
    def play(path,lo=0.,hi=1.,rev=False):
        token=open_(str(path).encode(),0.,lo,hi,rev); assert token
        obj=source(token); assert obj and not source(token)
        close(token); assert method(obj,4,S)(obj)==b""; return obj
    def samples(obj,num):
        buf=(D*num)()
        assert method(obj,14,I,C.POINTER(D),I)(obj,buf,num)==num
        return list(buf)
    def destroy(obj):
        method(obj,0,None,C.c_uint)(obj,1) # MSVC scalar deleting destructor
    report={}
    with tempfile.TemporaryDirectory(dir=opt.out.resolve()) as tmp:
        root=Path(tmp); wav=root/"声音.wav"; frames=48000
        data=struct.pack("<"+"h"*frames,*(i%16000-8000 for i in range(frames)))
        wav.write_bytes(header(len(data))+data)
        obj=play(wav,.25,.75,True)
        assert method(obj,11,L)(obj)==frames//2
        assert samples(obj,8)==[(i%16000-8000)/32768 for i in range(35999,35991,-1)]
        dup=method(obj,1,P)(obj); assert dup and samples(dup,8)[0]==(35999%16000-8000)/32768
        destroy(dup);destroy(obj)
        opened=[]
        for ext in ("wav","aiff","flac","mp3"):
            p=wav if ext=="wav" else root/("fixture."+ext)
            if ext!="wav":
                if not shutil.which("ffmpeg"): continue
                subprocess.run(["ffmpeg","-v","error","-i",wav,"-y",p],check=True)
            o=play(p); assert max(abs(v) for v in samples(o,256))>.01
            destroy(o)
            t=open_(str(p).encode(),0,0,1,False); assert t
            all_hex=""; after=0
            for _ in range(10000):
                reply=peaks(t,256,True)
                assert reply,ext
                count,ch,first,end,values=reply.decode().split(":")
                assert int(first)==after and int(ch)==1 and int(count)==256
                after=int(end);all_hex+=values
                if after==256:break
            assert len(all_hex)==256*4 and int(all_hex[:4],16)>0
            close(t);opened.append(ext)
        report["decoded"]=opened
        # Long cold WAV, non-zero audio at the requested point. Neither the
        # first sample nor a middle seek should read hundreds of MiB.
        p=root/"long.wav"; size=512*1024*1024
        with p.open("wb") as f:
            import msvcrt
            done=C.c_ulong()
            C.windll.kernel32.DeviceIoControl(P(msvcrt.get_osfhandle(f.fileno())),0x900c4,None,0,None,0,C.byref(done),None)
            f.write(header(size));f.write(data[:8192]);f.seek(44+size//2);f.write(data[:8192]);f.truncate(44+size)
        before=read_counts();t0=time.perf_counter();o=play(p);out=samples(o,256)
        report["cold_first_pcm_ms"]=(time.perf_counter()-t0)*1000;report["bytes_before_first_pcm"]=read_counts()-before
        assert out[0]==-8000/32768 and report["bytes_before_first_pcm"]<512*1024
        method(o,13,None,L)(o,size//4);assert samples(o,8)==out[:8]
        # A completely exclusive writer can open the file between callbacks.
        k=C.windll.kernel32;k.CreateFileW.restype=P
        h=k.CreateFileW(str(p),0xc0000000,0,None,3,0,None)
        assert h not in (None,P(-1).value),C.get_last_error()
        assert k.CloseHandle(P(h))
        moved=root/"renamed.wav";p.rename(moved);p.write_bytes(header(4096)+bytes(4096))
        method(o,13,None,L)(o,65536)
        assert method(o,14,I,C.POINTER(D),I)(o,(D*8)(),8)==0
        assert not method(o,1,P)(o),"must not duplicate a replaced original"
        destroy(o);assert not list(root.glob("*.reapeaks"))
        before=read_counts();start=time.perf_counter()
        token=open_(str(moved).encode(),0,0,1,False);assert token
        calls=0
        while calls<1024:
            count,_,_,end,_=peaks(token,128,False).split(b":",4)
            calls+=1
            if int(end)==int(count):break
        close(token)
        assert calls<1024 and int(end)==128
        report["long_overview_decode_ms"]=(time.perf_counter()-start)*1000
        report["long_overview_read_bytes"]=read_counts()-before
        report["long_overview_slices"]=calls
        assert open_(str((root/"missing.wav")).encode(),0,0,1,False)==0
    open_index=api("API_PRS_Quick_Open",I,S,S,C.c_bool)
    add=api("API_PRS_Quick_Add",C.c_bool,I,S,S)
    find=api("API_PRS_Quick_Find",S,I,S)
    finish=api("API_PRS_Quick_Close",C.c_bool,I,C.c_bool)
    sig=b"1:2|3|123456"
    assert not open_index(b"../external",sig,True) and not open_index(b"prs",sig,False)
    handle=open_index(b"prs",sig,True)
    assert handle, "could not build isolated search index"
    rows=50000
    for i in range(rows):
        body="rain field recording " + str(i) if i!=rows-1 else "needle 火车进站 [track]*"
        assert add(handle,str(128*i).encode(),body.encode())
    assert finish(handle,True)
    assert not open_index(b"prs",b"other snapshot",False)
    assert not open_index(b"sm_0123456789abcdef",sig,False)
    pending=open_index(b"prs",b"new",True)
    assert pending and add(pending,b"3",b"staging")
    finish(pending,False)
    start=time.perf_counter()
    handle=open_index(b"prs",sig,False)
    expected=str((rows-1)*128).encode()+b","
    assert handle and find(handle,b"needle")==expected
    report["catalog_rows"]=rows
    report["reopen_and_find_ms"]=(time.perf_counter()-start)*1000
    assert find(handle,"车进站".encode())==expected
    assert find(handle,"进".encode())==expected and find(handle,"火车".encode())==expected
    assert find(handle,"火车 needle".encode())==expected
    assert find(handle,b"[track]*")==expected
    assert len(find(handle,b"").split(b",")[:-1])==80
    finish(handle,False)
    assert [p.name for p in (resource_root/"Data"/"PsyReaSFX-QuickSearch").iterdir()]==["prs-v2.sqlite"]
    resource.cleanup()
    print(json.dumps(report,ensure_ascii=True))
    (opt.out/"audition.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
if __name__=="__main__": main()
