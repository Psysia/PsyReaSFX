"""Synthetic SQLite concurrency against the real Lua reader/import runtime.

Only the ReaScript native ABI is stubbed for command-line Lua. The native fork's
shared_readonly CTest independently verifies Win32 sharing while real handles
are open. This test never opens user databases or controls Soundminer.
"""
import argparse
from contextlib import closing
import json
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import threading


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lua", required=True)
    parser.add_argument("--module", default="src/lua/27_sqlite_reader.lua")
    parser.add_argument("--runtime", help="Also test external writes during the full production import runtime")
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="concurrency-", dir=root) as folder:
        folder = pathlib.Path(folder)
        database = folder / "synthetic.sqlite"
        with closing(sqlite3.connect(database)) as connection:
            connection.execute("CREATE TABLE justinmetadata(recid INTEGER PRIMARY KEY, FilePath TEXT, Description TEXT)")
            connection.executemany("INSERT INTO justinmetadata VALUES(?,?,?)", ((i, f"/synthetic/{i}.wav", "before") for i in range(1, 5001)))
            connection.commit()
        worker = folder / "worker.lua"
        worker.write_text('''local native_open = io.open
local source = arg[2]:gsub("\\\\", "/"):lower()
io.open = function(path, mode)
  local normalized = tostring(path):gsub("\\\\", "/"):lower()
  if normalized:sub(1, #source) == source then assert(mode == "rb", "source must be opened rb only") end
  return native_open(path, mode)
end
os.remove = function() error("reader attempted remove") end
os.rename = function() error("reader attempted rename") end
os.execute = function() error("reader attempted process execution") end
io.popen = function() error("reader attempted process execution") end
dofile(arg[1])
reaper = { ReaWeb_ReadSharedRange = dofile("tools/lua_shared_readonly_fixture.lua") }
dofile((arg[1]:gsub("27_sqlite_reader.lua$", "26_shared_readonly.lua")))
local db = assert(SoundminerSQLite.open(arg[2]))
assert(db:tables().justinmetadata)
local iterator = db:rows("justinmetadata")
assert(iterator())
io.stdout:write("READY\\n"); io.stdout:flush()
assert(io.stdin:read("*l") == "check")
local unchanged = db:unchanged()
assert(not pcall(iterator), "cached row iterator must stop after external commit")
-- Signal only after the iterator has finished probing synthetic files. The
-- Python rename must run while this fixture is blocked, not during its CRT
-- ABI stub's transient open (real shared handles are covered by native CTest).
io.stdout:write(unchanged and "UNCHANGED\\n" or "CHANGED\\n"); io.stdout:flush()
assert(io.stdin:read("*l") == "close")
db:close()
db = assert(SoundminerSQLite.open(arg[2]))
iterator = db:rows("justinmetadata")
io.stdout:write("STREAM\\n"); io.stdout:flush()
assert(io.stdin:read("*l") == "stream")
local ok, reason = pcall(function() for _ in iterator do end end)
assert(not ok and tostring(reason):find("changed"), "concurrent writer must stop the reader")
db:close()
io.stdout:write("STOPPED\\n"); io.stdout:flush()
''', encoding="utf-8")
        process = subprocess.Popen([args.lua, str(worker), str(pathlib.Path(args.module).resolve()), str(database)],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            assert process.stdout.readline().strip() == "READY"
            updates = 0
            with closing(sqlite3.connect(database, timeout=0.0)) as connection:
                for index in range(25):
                    connection.execute("UPDATE justinmetadata SET Description=? WHERE recid=?", (f"writer-{index}", index + 1))
                    connection.commit()
                    updates += 1
            process.stdin.write("check\n"); process.stdin.flush()
            assert process.stdout.readline().strip() == "CHANGED"
            renamed = folder / "renamed.sqlite"
            rename_error = None
            try:
                database.rename(renamed)
                renamed.rename(database)
            except OSError as error:
                rename_error = {"type": type(error).__name__, "winerror": getattr(error, "winerror", None), "errno": error.errno}
            assert rename_error is None, f"idle logical reader kept an OS handle: {rename_error}"
            process.stdin.write("close\n"); process.stdin.flush()
            assert process.stdout.readline().strip() == "STREAM"
            writer_started = threading.Event()
            writer_errors, streaming_updates = [], []
            def writer():
                try:
                    with closing(sqlite3.connect(database, timeout=0.0)) as connection:
                        for index in range(100):
                            connection.execute("UPDATE justinmetadata SET Description=? WHERE recid=?", (f"stream-{index}", index + 100))
                            connection.commit()
                            streaming_updates.append(index)
                            writer_started.set()
                except Exception as error:
                    writer_errors.append(str(error)); writer_started.set()
            thread = threading.Thread(target=writer)
            thread.start()
            assert writer_started.wait(10)
            process.stdin.write("stream\n"); process.stdin.flush()
            assert process.stdout.readline().strip() == "STOPPED"
            thread.join(10)
            assert not thread.is_alive() and not writer_errors and len(streaming_updates) == 100, writer_errors
            stdout, stderr = process.communicate(timeout=10)
            assert process.returncode == 0, stderr
            database.rename(renamed); renamed.rename(database)
            with closing(sqlite3.connect(database)) as connection:
                assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
                assert connection.execute("SELECT COUNT(*) FROM justinmetadata WHERE Description LIKE 'writer-%'").fetchone()[0] == updates
            print(json.dumps({"writer_commits": updates, "concurrent_writer_commits": len(streaming_updates),
                              "change_detected": True, "cached_iterator_stopped": True,
                              "rename_while_reader_open_error": rename_error, "rename_after_close": True}, indent=2))
        finally:
            if process.poll() is None:
                process.kill(); process.communicate(timeout=10)
    if args.runtime:
        with tempfile.TemporaryDirectory(prefix="import-concurrency-", dir=root) as folder:
            subprocess.run([sys.executable, "tools/generate_soundminer_import_fixtures.py", folder], check=True)
            process = subprocess.Popen([args.lua, "tools/lua_soundminer_import_selftest.lua", args.runtime, folder,
                                        "dependencies/reawebapi/windows-x64.lock.json", "concurrent-writer"],
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8")
            try:
                ready_line = process.stdout.readline().strip()
                if ready_line != "CONCURRENT_IMPORT_READY":
                    stdout, stderr = process.communicate(timeout=10)
                    raise AssertionError(ready_line + stdout + stderr)
                commits, errors = [], []
                ready = threading.Event()
                def import_writer():
                    try:
                        with closing(sqlite3.connect(pathlib.Path(folder) / "changing.sqlite", timeout=0.0)) as database:
                            for index in range(100):
                                database.execute("UPDATE justinmetadata SET Description=? WHERE recid=1", (f"external-import-{index}",))
                                database.commit(); commits.append(index); ready.set()
                    except Exception as error:
                        errors.append(str(error)); ready.set()
                thread = threading.Thread(target=import_writer); thread.start()
                assert ready.wait(10)
                process.stdin.write("writer-started\n"); process.stdin.flush()
                stdout, stderr = process.communicate(timeout=90)
                thread.join(10)
                assert process.returncode == 0, stderr
                assert not thread.is_alive() and not errors and len(commits) == 100, errors
                assert "Soundminer integration: PASS" in stdout, stdout
                print("Production import with 100 external SQLite commits: PASS (safe abort, writer unaffected)")
            finally:
                if process.poll() is None:
                    process.kill(); process.communicate(timeout=10)


if __name__ == "__main__":
    main()
