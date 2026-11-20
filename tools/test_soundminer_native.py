"""Synthetic native SQLite, FTS, file sharing and mutation regressions."""
import ctypes
import hashlib
from pathlib import Path
import sqlite3
import struct
import time


def unpack_rows(reply):
    assert reply[:1] == b"+", reply
    rows = []
    pos = 1
    while pos < len(reply):
        end = reply.index(b":", pos)
        header = reply[pos:end].decode("ascii")
        tag = next(ch for ch in header if ch.isalpha())
        column, size = (int(n) for n in header.split(tag))
        data = reply[end + 1:end + 1 + size]
        assert len(data) == size
        pos = end + 1 + size
        if column == 0:
            rows.append({})
        if tag == "i":
            data = int(data)
        elif tag == "d":
            data = struct.unpack("<d", bytes.fromhex(data.decode()))[0]
        elif tag == "x":
            data = bytes.fromhex(data.decode())
        rows[-1][column] = data
    return rows


def verify_soundminer_sqlite(api, directory: Path):
    integer, string, boolean = ctypes.c_int, ctypes.c_char_p, ctypes.c_bool
    open_source = api("API_PRS_SM_Open", integer, string)
    close = api("API_PRS_SM_Close", None, integer)
    valid = api("API_PRS_SM_Valid", boolean, integer)
    read = api("API_PRS_SM_Read", string, integer, string, string, string, integer)
    search = api("API_PRS_SM_Search", string, integer, string, integer)
    drives = api("API_PRS_SM_LocalDrives", string)().decode()
    assert drives == "".join(sorted(set(drives))) and all("A" <= c <= "Z" for c in drives)
    directory.mkdir()
    path = directory / "只读源.sqlite"
    data = b"\0\xff:\r\n1234"
    with sqlite3.connect(path) as writer:
        writer.executescript("""
            CREATE TABLE justinmetadata (recid INTEGER PRIMARY KEY, FilePath, Filename, Description, Custom, Optional, Frames);
            CREATE TABLE waveform (id INTEGER PRIMARY KEY, FilePath TEXT, waveformrep BLOB);
            CREATE TABLE overviews (id INTEGER PRIMARY KEY, filepath TEXT, filepathhash TEXT, overviews BLOB);
            CREATE UNIQUE INDEX "arbitrary""index" ON overviews(filepathhash);
            CREATE VIRTUAL TABLE fulltext USING fts4(content="justinmetadata", Filename,Description,
                tokenize=unicode61 "remove_diacritics=2");
        """)
        writer.executemany("INSERT INTO justinmetadata VALUES (?,?,?,?,?,?,?)", [
            (-1, "/Volumes/L/early.wav", "early", None, None, None, -1),
            (0, "/Volumes/L/空.wav", "zero", "空", "", None, 0),
            (41, "/Volumes/L/a.wav", "Metal Rattle", "élan", data, "a\0b", 1.25),
            (2**53 + 7, "/Volumes/L/b.wav", "Just Metal", "élan", None, None, 2**53 + 21),
        ])
        writer.executemany("INSERT INTO justinmetadata(FilePath,Filename) VALUES(?,?)",
                           [(f"/Volumes/L/fx{i}", f"effect {i}") for i in range(420)])
        writer.execute("INSERT INTO waveform VALUES (7,'/Volumes/L/a.wav',?)", (data,))
        writer.execute("INSERT INTO overviews VALUES (9,'/Volumes/L/a.wav','001f',?)", (data,))
        writer.execute("INSERT INTO fulltext(fulltext) VALUES('rebuild')")
    writer.close()
    original = hashlib.sha256(path.read_bytes()).digest()
    native_open = lambda: open_source(str(path).encode())
    handle = native_open()
    assert handle > 0 and valid(handle)
    assert not any(directory.glob("*-wal")) and not any(directory.glob("*-journal"))
    first = unpack_rows(read(handle, b"rows", b"", b"", 3))
    assert [row[0] for row in first] == [-1, 0, 41]
    assert first[1][2] == "/Volumes/L/空.wav".encode() and first[1][5] == b"" and 6 not in first[1]
    assert first[2][5] == data and first[2][6] == b"a\0b" and first[2][7] == 1.25
    second = unpack_rows(read(handle, b"rows", b"41", b"", 1))[0]
    assert second[0] == 2**53 + 7 and second[7] == 2**53 + 21
    assert unpack_rows(read(handle, b"metadata_id", str(second[0]).encode(), b"", 1)) == [second]
    assert unpack_rows(read(handle, b"paths", b"", b"5", 2))[0] == {
        0: -1, 1: b"/Volumes/L/early.wav", 3: b"early",
    }
    assert unpack_rows(read(handle,b"cache_hash",b"001f",b'arbitrary"index',1))[0][4] == data
    assert unpack_rows(read(handle,b"wave_id",b"7",b"",1))[0][3] == data
    assert read(handle,b"cache_hash",b"absent",b'arbitrary"index',1)==b"+"
    started = time.perf_counter()
    assert search(handle,b"Met Rat",32) == b"+41\n"
    assert search(handle,b"nothing",32) == b"+"
    assert search(handle,b"x OR *",32) == b"!unsupported"
    assert len(search(handle,b"eff",7)[1:].splitlines()) == 7
    assert search(handle,"élan".encode(),32) == b"+41\n" + str(2**53+7).encode() + b"\n"
    elapsed = (time.perf_counter() - started) * 1000
    assert hashlib.sha256(path.read_bytes()).digest() == original
    assert sorted(directory.iterdir()) == [path], "reader wrote a SQLite sidecar"

    # An idle or cached read is invalidated by a writer. An open reader never
    # acquires a SQLite SHARED lock that could delay BEGIN EXCLUSIVE or COMMIT.
    writer = sqlite3.connect(path, timeout=0)
    writer.execute("BEGIN EXCLUSIVE")
    writer.execute("UPDATE justinmetadata SET Filename='changed' WHERE recid=41")
    assert not valid(handle) and read(handle,b"rows",b"",b"",2) == b"!changed"
    writer.commit()
    assert not valid(handle)
    close(handle)
    assert writer.execute("PRAGMA journal_mode=WAL").fetchone()[0] == "wal"
    writer.execute("UPDATE justinmetadata SET Filename='WAL change' WHERE recid=41")
    writer.commit()
    assert native_open() < 0 and (directory/(path.name+"-wal")).stat().st_size > 0
    writer.close()

    # A new generation can be opened once the writer has checkpointed/closed.
    handle = native_open()
    assert handle > 0
    assert unpack_rows(read(handle,b"metadata_id",b"41",b"",1))[0][3] == b"WAL change"
    moved = path.with_suffix(".moved")
    path.rename(moved)
    assert not valid(handle) and search(handle,b"changed",8) == b"!changed"
    close(handle)
    moved.rename(path)
    # A zeroed PERSIST header is safe; a nonzero rollback journal is active.
    journal = path.with_name(path.name + "-journal")
    journal.write_bytes(bytes(28))
    handle = native_open()
    assert handle > 0 and valid(handle)
    journal.write_bytes(b"active" + bytes(22))
    assert not valid(handle) and native_open() < 0
    close(handle)
    journal.unlink()

    alternate = directory / "alternative-schema.sqlite"
    with sqlite3.connect(alternate) as writer:
        writer.executescript("""
            CREATE TABLE another_catalog(id INTEGER PRIMARY KEY, Filename TEXT);
            CREATE VIEW justinmetadata AS SELECT * FROM another_catalog;
            CREATE VIRTUAL TABLE waveform USING fts4(FilePath);
            CREATE VIRTUAL TABLE fulltext USING fts4(content='another_catalog', Filename);
        """)
    writer.close()
    handle = open_source(str(alternate).encode())
    assert handle > 0 and read(handle,b"rows",b"",b"",1) == b"!query", "physical metadata table required"
    assert read(handle,b"wave_id",b"1",b"",1) == b"!query", "physical waveform table required"
    assert search(handle,b"common",32) == b"!unsupported", "unrecognized external FTS content table"
    assert valid(handle)
    close(handle)
    return {"verified_native_rows": 424, "five_indexed_fts_queries_ms": round(elapsed, 2)}
