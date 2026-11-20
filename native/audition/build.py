"""Build the Win64 PRS audition extension with pinned Zig 0.15.2, no Windows SDK install."""
import argparse
import os
from pathlib import Path
import subprocess

src = Path(__file__).resolve().parent
root = src.parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--zig", required=True, type=Path)
parser.add_argument("--out", required=True, type=Path)
args = parser.parse_args()
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
zig = str(args.zig.resolve())
sdk = root / "dependencies/reawebapi/licenses/licenses"
header = (sdk / "reaper_plugin.h").read_text()
start = header.index("class ISimpleMediaDecoder\n")
end = header.index("\n};", start) + 3
(out / "decoder_sdk.hpp").write_text(header[:header.index("#ifndef _REAPER_PLUGIN_H_")] +
    "\nusing INT64=long long; using ReaSample=double;\n" + header[start:end], encoding="utf-8")
env = {**os.environ, "SOURCE_DATE_EPOCH": "0",
       "ZIG_GLOBAL_CACHE_DIR": os.environ.get("ZIG_GLOBAL_CACHE_DIR", str(out / "zig-cache"))}
def run(*args):
    subprocess.run([zig, *map(str, args)], check=True, cwd=out, env=env)
def msvc_object(unit, obj):
    # Win64 C ABI for the platform/codec and Cockos' required MSVC C++ ABI
    # for the only class with virtual functions. No CRT object crosses it.
    run("clang", "-cc1", "-triple", "x86_64-pc-windows-msvc", "-std=c++17", "-emit-obj",
        "-O2", "-fms-extensions", "-fno-rtti", "-fcheck-new", "-I", out, "-I", src, "-o", obj, unit)
msvc_object(src/"decoder.cpp", "decoder.obj")
run("cc","-target","x86_64-windows-gnu","-O2","-DNDEBUG","-c",src/"reader.c","-o","reader.obj")
run("c++","-target","x86_64-windows-gnu","-O2","-fno-exceptions","-fno-rtti","-I",sdk,
    "-c",src/"extension.cpp","-o","extension.obj")
run("c++","-target","x86_64-windows-gnu","-O2","-fno-exceptions","-fno-rtti",
    "-c",src/"quick_index.cpp","-o","quick.obj")
run("c++","-target","x86_64-windows-gnu","-O2","-fno-exceptions","-fno-rtti",
    "-c",src/"soundminer_sqlite.cpp","-o","soundminer.obj")
run("cc","-target","x86_64-windows-gnu","-shared","-s","reader.obj","decoder.obj","extension.obj","quick.obj","soundminer.obj",
    "-o","reaper_prs_audition.dll")
