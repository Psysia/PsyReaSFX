"""Create synthetic Soundminer libraries, overview cache and PCM for Lua integration tests."""
import argparse
import hashlib
import json
import pathlib
import shutil
import sqlite3
import struct
import wave
import zlib


def varint(value):
    encoded = bytearray()
    while value > 127:
        encoded.append((value & 127) | 128)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def field(number, payload):
    return varint(number * 8 + 2) + varint(len(payload)) + payload


def overview(path, channels=1):
    result = field(1, path.encode("utf-8"))
    for channel in range(channels):
        raw = bytes([64, 192, 127, 129, 0, 0, 2, 255])
        if channel:
            raw = bytes([1, 255, 2, 254, 3, 253, 4, 252])
        result += field(2, b"\x08" + varint(channel) + field(2, zlib.compress(raw)) + b"\x18\x01")
    return result


def database(path, rows, local_waves=()):
    connection = sqlite3.connect(path)
    connection.execute("""CREATE TABLE justinmetadata (
        recid INTEGER PRIMARY KEY, FilePath TEXT, Pathname TEXT, Filename TEXT,
        Description TEXT, Keywords TEXT, Notes TEXT, UserComments TEXT,
        CatID TEXT, Category TEXT, SubCategory TEXT, Library TEXT, Rating INTEGER,
        SampleRate INTEGER, Channels INTEGER, BitDepth INTEGER, TotalFrames INTEGER,
        _Time REAL, _FilePathHash TEXT, _WaveformLink INTEGER, CustomField TEXT)""")
    for index, data in enumerate(rows, 1):
        row = {"recid": index, "Description": "中文描述\nsecond line", "Keywords": "metal,hit",
               "Notes": "note", "UserComments": "comment", "CatID": "IMPTMetl",
               "Category": "IMPACTS", "SubCategory": "METAL", "Library": "Synthetic Library",
               "Rating": 4, "SampleRate": 48000, "Channels": 1, "BitDepth": 16,
               "TotalFrames": 1536, "_Time": 1536 / 48000, "_WaveformLink": 0,
               "CustomField": "keep me\t特殊"}
        row.update(data)
        source = row.get("FilePath") or row["Pathname"] + "/" + row["Filename"]
        row.setdefault("Filename", source.rsplit("/", 1)[-1])
        row.setdefault("Pathname", source.rsplit("/", 1)[0])
        row.setdefault("_FilePathHash", hashlib.sha1(source.encode()).hexdigest())
        names = list(row)
        connection.execute(f"INSERT INTO justinmetadata ({','.join(names)}) VALUES ({','.join('?' for _ in names)})",
                           [row[key] for key in names])
    connection.execute("CREATE TABLE waveform (recid INTEGER PRIMARY KEY, FilePath TEXT, waveformrep BLOB)")
    connection.executemany("INSERT INTO waveform VALUES (?,?,?)", local_waves)
    connection.commit()
    connection.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    target = args.output.resolve()
    target.mkdir(parents=True, exist_ok=True)
    if any(target.iterdir()):
        parser.error("fixture directory must be empty")
    for folder in ["SoundminerV7/Databases", "SoundminerV7/Caches", "audio/FX", "audio/Music", "owned",
                   "cancel", "runtime/Scripts/PsyReaSFX", "runtime/Scripts/PsyReaSFX/backups",
                   "runtime/Scripts/PsyReaSFX/cache_quarantine", "runtime/Scripts/PsyReaSFX/wave_cache_v3",
                   "runtime/Scripts/PsyReaSFX/Transfer"]:
        (target / folder).mkdir(parents=True, exist_ok=True)
    old = "/Volumes/SM-Audio"
    names = ["FX/impact.wav", "FX/offline.wav", "Music/tone.wav", "FX/fallback.wav", "FX/no-frames.wav", "FX/local.wav"]
    for name in names + ["FX/not-in-soundminer.wav"]:
        if "offline" in name:
            continue
        with wave.open(str(target / "audio" / name), "wb") as output:
            output.setparams((1, 2, 48000, 1536, "NONE", "not compressed"))
            output.writeframes(struct.pack("<h", 8192) * 1536)
    rows = [{"FilePath": old + "/" + name} for name in names]
    rows[3].update(FilePath=None, Pathname=old + "/FX", Filename="fallback.wav")
    rows[4]["TotalFrames"] = None
    rows[5]["_WaveformLink"] = 7
    rows += [{"FilePath": old + "/FX/impact.wav", "Description": "duplicate must not overwrite"},
             {"FilePath": "relative/invalid.wav"}, {"FilePath": old + "/../invalid.wav"}]
    main_db = target / "SoundminerV7/Databases/Synthetic.sqlite"
    database(main_db, rows, [(7, old + "/FX/local.wav", overview(old + "/FX/local.wav"))])
    cache = sqlite3.connect(target / "SoundminerV7/Caches/waveforms.sqlite")
    cache.execute("CREATE TABLE overviews (id INTEGER PRIMARY KEY, filepath TEXT, filepathhash TEXT, timestamp DATE, overviews BLOB)")
    cache.execute("CREATE UNIQUE INDEX fphash ON overviews(filepathhash)")
    for index, name in enumerate(names[:-1], 1):
        path = old + "/" + name
        blob = b"unsupported-format" if name == "Music/tone.wav" else overview(path)
        cache.execute("INSERT INTO overviews VALUES (?,?,?,?,?)", (index, path, hashlib.sha1(path.encode()).hexdigest(), "2026-01-01", blob))
    cache.commit()
    cache.close()
    database(target / "cancel.sqlite", [{"FilePath": f"/Volumes/Cancel/item-{index:03}.wav"} for index in range(80)])
    database(target / "owned.sqlite", [{"FilePath": (target / "owned" / "new.wav").as_posix()}])
    database(target / "Second.sqlite", [{"FilePath": old + "/FX/impact.wav", "Description": "Second isolated library"}])
    shutil.copyfile(main_db, target / "changing.sqlite")
    shutil.copyfile(main_db, target / "wal.sqlite")
    (target / "wal.sqlite-wal").write_bytes(b"active write-ahead log")
    invalid = sqlite3.connect(target / "unsupported.sqlite")
    invalid.execute("CREATE TABLE unrelated (name TEXT)")
    invalid.close()
    inventory = {}
    for directory in target.rglob("*"):
        if directory.is_dir():
            inventory[directory.as_posix().lower()] = {
                "files": sorted(item.name for item in directory.iterdir() if item.is_file()),
                "directories": sorted(item.name for item in directory.iterdir() if item.is_dir()),
            }
    inventory[target.as_posix().lower()] = {
        "files": sorted(item.name for item in target.iterdir() if item.is_file()),
        "directories": sorted(item.name for item in target.iterdir() if item.is_dir()),
    }
    (target / "inventory.json").write_text(json.dumps(inventory, ensure_ascii=False), encoding="utf-8")
    print(f"Soundminer integration fixtures: {target}")


if __name__ == "__main__":
    main()
