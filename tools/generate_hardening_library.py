#!/usr/bin/env python3
"""Generate a deterministic, disposable PsyReaSFX stress-test library."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import time
import zlib
from pathlib import Path


def wave_bytes(seed: int, channels: int = 2, sample_rate: int = 48000) -> bytes:
    digest = hashlib.sha256(f"psyreasfx:{seed}".encode("ascii")).digest()
    frames = 32
    samples = bytearray()
    for frame in range(frames):
        for channel in range(channels):
            offset = (frame * channels + channel) % (len(digest) - 1)
            value = int.from_bytes(digest[offset : offset + 2], "little", signed=False) - 32768
            samples.extend(struct.pack("<h", value))
    block_align = channels * 2
    byte_rate = sample_rate * block_align
    fmt = struct.pack("<HHIIHH", 1, channels, sample_rate, byte_rate, block_align, 16)
    riff_size = 4 + 8 + len(fmt) + 8 + len(samples)
    return b"RIFF" + struct.pack("<I", riff_size) + b"WAVEfmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(samples)) + samples


def png_bytes(width: int = 64, height: int = 64) -> bytes:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend((20 + x * 2, 80 + y * 2, 150, 255))

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="New or empty output directory")
    parser.add_argument("--count", type=int, default=5000)
    parser.add_argument("--duplicate-every", type=int, default=97)
    parser.add_argument("--multichannel-every", type=int, default=997)
    parser.add_argument("--allow-existing", action="store_true")
    args = parser.parse_args()

    if args.count < 1 or args.count > 250000:
        parser.error("--count must be between 1 and 250000")
    root = args.root.resolve()
    if root.exists() and any(root.iterdir()) and not args.allow_existing:
        parser.error(f"refusing to write into non-empty directory: {root}")

    started = time.perf_counter()
    audio_root = root / "Library A" / "1. Source"
    artwork_root = root / "Library A" / "2. Artwork"
    artwork_root.mkdir(parents=True, exist_ok=True)
    (artwork_root / "cover.png").write_bytes(png_bytes())

    duplicate_pairs = []
    multichannel = []
    for index in range(args.count):
        folder = audio_root / f"Category-{index % 32:02d}" / f"Group-{(index // 32) % 32:02d}"
        folder.mkdir(parents=True, exist_ok=True)
        channels = 4 if args.multichannel_every > 0 and index % args.multichannel_every == 0 else 2
        seed = index
        if args.duplicate_every > 0 and index % args.duplicate_every == 1:
            seed = index - 1
            duplicate_pairs.append([index - 1, index])
        path = folder / f"TEST_{index:06d}_{channels}ch.wav"
        path.write_bytes(wave_bytes(seed, channels))
        if channels > 2:
            multichannel.append(index)

    manifest = {
        "schema": 1,
        "generator": "tools/generate_hardening_library.py",
        "count": args.count,
        "audioRoot": str(audio_root),
        "artwork": str(artwork_root / "cover.png"),
        "offlineRoot": str(root / "Offline Library" / "Missing Source"),
        "duplicatePairs": duplicate_pairs,
        "multichannelIndexes": multichannel,
        "elapsedSeconds": time.perf_counter() - started,
    }
    root.mkdir(parents=True, exist_ok=True)
    (root / "hardening-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
