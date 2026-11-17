"""Generate synthetic SQLite files for the dependency-free Lua reader tests.

No Soundminer database or source audio is copied. Uses Python's standard SQLite
implementation so tests exercise independent real on-disk SQLite structures.
"""
import argparse
import pathlib
import shutil
import sqlite3
import struct


def create_database(path, page_size):
    connection = sqlite3.connect(path)
    connection.execute(f"PRAGMA page_size={page_size}")
    connection.execute("PRAGMA journal_mode=DELETE")
    connection.execute(
        "CREATE TABLE justinmetadata (recid INTEGER PRIMARY KEY, Filename TEXT, "
        "Pathname TEXT, Description TEXT, Small INTEGER, Big INTEGER, Score REAL, "
        "Missing TEXT, waveformrep BLOB)"
    )
    rows = []
    for index in range(1, 2201):
        description = "引号, comma ('nested')\n" + ("x" * 19000 if index == 101 else f"row-{index}")
        rows.append((index, f"音效-{index}.wav", "C:/Audio/中文", description,
                     -index, -9223372036854775808 if index == 101 else 9223372036854775807,
                     0.125, None, bytes(range(256)) * (120 if index == 101 else 1)))
    rows += [(-9223372036854775808, "min.wav", "", "", -8388608, 8388607, 0.0, None, b""),
             (-1, "negative.wav", "", "", -129, 32768, 1.0, None, b""),
             (9223372036854775807, "max.wav", "", "", -2147483648, 2147483648, -3.25, None, b"\0")]
    connection.executemany("INSERT INTO justinmetadata VALUES (?,?,?,?,?,?,?,?,?)", rows)
    connection.execute("ALTER TABLE justinmetadata ADD COLUMN Later INTEGER DEFAULT 42")
    connection.execute("ALTER TABLE justinmetadata ADD COLUMN LaterText TEXT DEFAULT 'a,b)'")
    connection.execute("CREATE UNIQUE INDEX filename_idx ON justinmetadata (Filename)")
    connection.execute("CREATE INDEX longtext_idx ON justinmetadata (Description COLLATE BINARY ASC)")
    connection.execute("CREATE INDEX ignored_desc_idx ON justinmetadata (Pathname DESC)")
    connection.execute("CREATE TABLE collated (id INTEGER PRIMARY KEY, word TEXT COLLATE NOCASE)")
    connection.execute("CREATE INDEX ignored_nocase_idx ON collated (word)")
    connection.execute("INSERT INTO collated VALUES (1,'A')")
    connection.execute("CREATE TABLE typed (id INTEGER PRIMARY KEY, word)")
    connection.executemany("INSERT INTO typed VALUES (?,?)", [(1, None), (2, 42), (3, 'abc'), (4, b'abc'), (5, 'xyz')])
    connection.execute("CREATE INDEX typed_idx ON typed (word)")
    connection.execute('CREATE TABLE "tricky,column" ("a,b" INTEGER, [nullable] TEXT, '
                       '`quoted``name` TEXT DEFAULT \'x,y)\', CONSTRAINT pk PRIMARY KEY ("a,b"))')
    connection.execute('INSERT INTO "tricky,column" VALUES (5,NULL,\'yes\')')
    connection.execute("CREATE TABLE descending (id INTEGER PRIMARY KEY DESC, label TEXT)")
    connection.execute("INSERT INTO descending VALUES (101, 'no rowid alias')")
    connection.execute("CREATE TABLE no_rowid (id TEXT PRIMARY KEY) WITHOUT ROWID")
    connection.execute("CREATE TABLE generated (a INTEGER, b INTEGER GENERATED ALWAYS AS (a+1) VIRTUAL)")
    connection.commit()
    root = connection.execute("SELECT rootpage FROM sqlite_schema WHERE name='justinmetadata'").fetchone()[0]
    connection.close()
    return root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    if any(destination.iterdir()):
        parser.error("fixture output must be empty")
    root = create_database(destination / "ordinary.sqlite", 512)
    create_database(destination / "large-page.sqlite", 65536)
    original = (destination / "ordinary.sqlite").read_bytes()
    (destination / "truncated.sqlite").write_bytes(original[:-1])
    invalid = bytearray(original)
    invalid[:16] = b"not a database!!"
    (destination / "bad-header.sqlite").write_bytes(invalid)
    invalid = bytearray(original)
    invalid[56:60] = struct.pack(">I", 2)
    (destination / "utf16.sqlite").write_bytes(invalid)
    invalid = bytearray(original)
    # The table's interior rightmost child now refers to itself.
    offset = (root - 1) * 512
    assert invalid[offset] == 5
    invalid[offset + 8:offset + 12] = struct.pack(">I", root)
    (destination / "cycle.sqlite").write_bytes(invalid)
    invalid = bytearray(original)
    # An invalid cell pointer on the table root must be rejected before a read.
    invalid[offset + 12:offset + 14] = b"\0\1"
    (destination / "bad-pointer.sqlite").write_bytes(invalid)
    shutil.copyfile(destination / "ordinary.sqlite", destination / "wal.sqlite")
    (destination / "wal.sqlite-wal").write_bytes(b"active WAL")
    shutil.copyfile(destination / "ordinary.sqlite", destination / "journal.sqlite")
    (destination / "journal.sqlite-journal").write_bytes(b"hot journal" + b"\0" * 600)
    shutil.copyfile(destination / "ordinary.sqlite", destination / "persist.sqlite")
    (destination / "persist.sqlite-journal").write_bytes(b"\0" * 28 + b"stale pages")
    shutil.copyfile(destination / "ordinary.sqlite", destination / "changing.sqlite")
    print(f"Generated synthetic SQLite fixtures: {destination}")


if __name__ == "__main__":
    main()
