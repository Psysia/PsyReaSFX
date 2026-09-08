#!/usr/bin/env python3
"""Prevent new code from bypassing the Lua host and state boundaries."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "src" / "lua"

HOST_BOUNDARY_MODULES = (
    "20_jobs_storage.lua",
    "30_catalog.lua",
    "40_analysis.lua",
    "45_duplicate_confirmation.lua",
)

# Existing UI/runtime writes are migrated gradually. This baseline makes the
# debt monotonic: new work cannot add more direct writes outside AppState.
STATE_WRITE_CEILINGS = {
    "10_ui_core.lua": 54,
    "20_jobs_storage.lua": 45,
    "30_catalog.lua": 107,
    "40_analysis.lua": 49,
    "50_runtime_ui.lua": 1233,
}

DIRECT_STATE_WRITE = re.compile(
    r"\bstate(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]\r\n]+\])\s*="
)


def fail(message: str) -> None:
    print(f"architecture audit: {message}", file=sys.stderr)
    raise SystemExit(1)


for name in HOST_BOUNDARY_MODULES:
    text = (LUA / name).read_text(encoding="utf-8")
    if "reaper." in text:
        fail(f"{name} calls reaper directly; use HostApi")

for path in sorted(LUA.glob("*.lua")):
    text = path.read_text(encoding="utf-8")
    count = len(DIRECT_STATE_WRITE.findall(text))
    ceiling = STATE_WRITE_CEILINGS.get(path.name, 0)
    if count > ceiling:
        fail(
            f"{path.name} has {count} direct state writes (ceiling {ceiling}); "
            "use AppState or reduce legacy writes"
        )

build_script = (ROOT / "tools" / "Build-LuaRelease.ps1").read_text(
    encoding="utf-8"
)
for required in ("12_state_store.lua", "15_host_adapter.lua"):
    if f'"{required}"' not in build_script:
        fail(f"release build omits {required}")

print("Lua architecture audit OK")
