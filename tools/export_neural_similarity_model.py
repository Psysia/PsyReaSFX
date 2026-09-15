#!/usr/bin/env python3
"""Export the frozen PsyReaSFX mn04_as scene embedding model.

Development-only dependencies:
  torch==2.11.0
  torchaudio==2.11.0
  torchvision==0.26.0
  onnx==1.22.0
  onnxruntime==1.30.0

The script consumes a pinned EfficientAT_HEAR checkout and a separately
downloaded, hash-verified mn04_as checkpoint. It exports an ONNX graph that
contains both the frozen mel frontend and the four MobileNet feature taps.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import math
import shutil
import sys
import wave
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
import torch.nn.functional as F
import torchaudio
from torch import nn


MODEL_NAME = "mn04_as"
PROFILE = "mn04_as_scene_320_v1"
DIMENSIONS = 320
SAMPLE_RATE = 32_000
MAX_WINDOW_SAMPLES = SAMPLE_RATE * 10
SCENE_HOP_SAMPLES = SAMPLE_RATE * 5 // 2
WEIGHTS_SHA256 = "899a8c6217063f6941793102a2780b3dd788ab11fce468d9cf5f0577c453321c"
UPSTREAM_COMMIT = "738e57daca70f2762f84f1af481c46dd8b7ebfe5"
UPSTREAM_FILES = {
    "hear_mn/mn04_all_b_mel_avgs.py": "a629f50f644da55d9d63c07d24488e1b5c74665cb2521060cb6bf534ca7a089e",
    "hear_mn/models/MobileNetV3.py": "e34c7b993edc626b86f58cbbb98ff7b71e8aa09ab4e09bd600964a842ca96606",
    "hear_mn/models/preprocess.py": "ae060c5b9e6ec26513f6b56d1ba5e0f8347cc5c872c47faa6f720332a007f23e",
    "LICENSE": "7fecf57238d733faf76a0d178f4973e9d3423e49e400d312a43e647700ce41ff",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_hash(path: Path, expected: str) -> None:
    actual = sha256_file(path)
    if actual != expected:
        raise RuntimeError(f"SHA-256 mismatch for {path}: expected {expected}, got {actual}")


class FrozenEfficientATMel(nn.Module):
    """ONNX-exportable equivalent of EfficientAT AugmentMelSTFT in eval mode."""

    def __init__(self) -> None:
        super().__init__()
        n_fft = 1024
        win_length = 800
        bins = n_fft // 2 + 1

        window = torch.hann_window(win_length, periodic=False, dtype=torch.float32)
        left = (n_fft - win_length) // 2
        window = F.pad(window, (left, n_fft - win_length - left))
        sample = torch.arange(n_fft, dtype=torch.float32)
        frequency = torch.arange(bins, dtype=torch.float32).unsqueeze(1)
        angle = 2.0 * math.pi * frequency * sample.unsqueeze(0) / n_fft
        real = torch.cos(angle) * window.unsqueeze(0)
        imag = -torch.sin(angle) * window.unsqueeze(0)

        mel_basis, _ = torchaudio.compliance.kaldi.get_mel_banks(
            128,
            n_fft,
            SAMPLE_RATE,
            0.0,
            15_000.0,
            vtln_low=100.0,
            vtln_high=-500.0,
            vtln_warp_factor=1.0,
        )
        mel_basis = F.pad(mel_basis, (0, 1), mode="constant", value=0)

        self.register_buffer("preemphasis", torch.tensor([[[-0.97, 1.0]]], dtype=torch.float32))
        self.register_buffer("dft", torch.cat((real, imag), dim=0).unsqueeze(1))
        self.register_buffer("mel_basis", mel_basis.to(torch.float32))
        self.n_fft = n_fft
        self.hop = 320
        self.bins = bins

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        signal = F.conv1d(waveform.unsqueeze(1), self.preemphasis)
        signal = F.pad(signal, (self.n_fft // 2, self.n_fft // 2), mode="reflect")
        spectrum = F.conv1d(signal, self.dft, stride=self.hop)
        real = spectrum[:, : self.bins, :]
        imag = spectrum[:, self.bins :, :]
        power = real.square() + imag.square()
        mel = torch.matmul(self.mel_basis, power)
        return (torch.log(mel + 0.00001) + 4.5) / 5.0


class SceneEmbeddingModel(nn.Module):
    def __init__(self, network: nn.Module) -> None:
        super().__init__()
        self.mel = FrozenEfficientATMel()
        self.features = network.features

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        mel = self.mel(waveform)
        outputs = [mel.mean(dim=2)]
        value = mel.unsqueeze(1)
        for index, component in enumerate(self.features):
            value = component(value)
            if index in (5, 11, 13, 15):
                outputs.append(F.adaptive_avg_pool2d(value, (1, 1)).flatten(1))
        return torch.cat(outputs, dim=1)


def make_golden_waveforms() -> dict[str, np.ndarray]:
    short_count = SAMPLE_RATE * 3 // 2
    short_time = np.arange(short_count, dtype=np.float64) / SAMPLE_RATE
    chirp_phase = 2.0 * math.pi * (180.0 * short_time + 0.5 * 4200.0 * short_time**2 / 1.5)
    short = 0.62 * np.sin(chirp_phase) * np.hanning(short_count)
    short[short_count // 3] += 0.45

    texture_count = SAMPLE_RATE * 3
    state = 0x13579BDF
    noise = np.empty(texture_count, dtype=np.float64)
    for index in range(texture_count):
        state = (1664525 * state + 1013904223) & 0xFFFFFFFF
        noise[index] = ((state >> 8) / 0xFFFFFF) * 2.0 - 1.0
    texture_time = np.arange(texture_count, dtype=np.float64) / SAMPLE_RATE
    carrier = np.sin(2.0 * math.pi * 73.0 * texture_time)
    envelope = 0.2 + 0.8 * np.square(np.sin(2.0 * math.pi * 1.7 * texture_time))
    texture = (0.24 * noise + 0.36 * carrier) * envelope
    for position in (8_000, 31_000, 62_000, 85_000):
        texture[position : position + 96] += np.linspace(0.75, 0.0, 96, endpoint=False)

    long_count = SAMPLE_RATE * 12
    long_time = np.arange(long_count, dtype=np.float64) / SAMPLE_RATE
    sweep = np.sin(2.0 * math.pi * (90.0 * long_time + 16.0 * long_time**2))
    tones = np.sin(2.0 * math.pi * 640.0 * long_time) + 0.45 * np.sin(2.0 * math.pi * 2370.0 * long_time)
    sections = np.where((np.arange(long_count) // SAMPLE_RATE) % 3 == 0, sweep, tones)
    long_scene = 0.36 * sections * (0.35 + 0.65 * np.square(np.sin(math.pi * 0.45 * long_time)))
    for position in range(SAMPLE_RATE, long_count, SAMPLE_RATE * 2):
        long_scene[position : position + 192] += np.linspace(0.8, 0.0, 192, endpoint=False)

    return {
        "chirp_impulse_1p5s": np.clip(short, -1.0, 1.0),
        "modulated_texture_3s": np.clip(texture, -1.0, 1.0),
        "evolving_scene_12s": np.clip(long_scene, -1.0, 1.0),
    }


def write_pcm16_wav(path: Path, samples: np.ndarray) -> np.ndarray:
    quantized = np.clip(np.rint(samples * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(quantized.tobytes())
    return quantized.astype(np.float32) / 32768.0


def vector_digest(vector: np.ndarray) -> str:
    return hashlib.sha256(np.asarray(vector, dtype="<f4").tobytes()).hexdigest()


def torch_scene_embedding(model: nn.Module, waveform: torch.Tensor) -> torch.Tensor:
    if waveform.shape[1] <= MAX_WINDOW_SAMPLES:
        return F.normalize(model(waveform), p=2.0, dim=1, eps=1e-12)
    padded = F.pad(
        waveform.unsqueeze(1),
        (MAX_WINDOW_SAMPLES // 2, MAX_WINDOW_SAMPLES // 2),
        mode="reflect",
    ).unsqueeze(1)
    segments = F.unfold(
        padded,
        kernel_size=(1, MAX_WINDOW_SAMPLES),
        stride=(1, SCENE_HOP_SAMPLES),
    ).transpose(-1, -2).transpose(0, 1)
    raw = torch.stack([model(segment) for segment in segments]).mean(dim=0)
    return F.normalize(raw, p=2.0, dim=1, eps=1e-12)


def ort_scene_embedding(session: ort.InferenceSession, waveform: np.ndarray) -> np.ndarray:
    def run_raw(samples: np.ndarray) -> np.ndarray:
        return session.run(["embedding_raw"], {"waveform": samples.astype(np.float32, copy=False)})[0]

    if waveform.shape[1] <= MAX_WINDOW_SAMPLES:
        raw = run_raw(waveform)
    else:
        padded = np.pad(
            waveform,
            ((0, 0), (MAX_WINDOW_SAMPLES // 2, MAX_WINDOW_SAMPLES // 2)),
            mode="reflect",
        )
        windows = []
        for start in range(0, waveform.shape[1] + 1, SCENE_HOP_SAMPLES):
            windows.append(run_raw(padded[:, start : start + MAX_WINDOW_SAMPLES]))
        raw = np.mean(np.stack(windows, axis=0), axis=0)
    norm = np.linalg.norm(raw, axis=1, keepdims=True)
    return raw / np.maximum(norm, 1e-12)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream-root", type=Path, required=True)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    upstream = args.upstream_root.resolve()
    weights = args.weights.resolve()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    require_hash(weights, WEIGHTS_SHA256)
    for relative, expected in UPSTREAM_FILES.items():
        require_hash(upstream / relative, expected)

    sys.path.insert(0, str(upstream))
    from hear_mn.hear_wrapper import MNHearWrapper  # pylint: disable=import-error,import-outside-toplevel
    from hear_mn.helpers.utils import NAME_TO_WIDTH  # pylint: disable=import-error,import-outside-toplevel
    from hear_mn.models.MobileNetV3 import get_model  # pylint: disable=import-error,import-outside-toplevel
    from hear_mn.models.preprocess import AugmentMelSTFT  # pylint: disable=import-error,import-outside-toplevel

    with contextlib.redirect_stdout(io.StringIO()):
        network = get_model(width_mult=NAME_TO_WIDTH(MODEL_NAME), pretrained_name=None)
    state_dict = torch.load(weights, map_location="cpu", weights_only=True)
    network.load_state_dict(state_dict)
    network.eval()

    reference = MNHearWrapper(
        mel=AugmentMelSTFT(n_mels=128, sr=SAMPLE_RATE, win_length=800, hopsize=320, n_fft=1024),
        net=network,
        mode=("b5", "b11", "b13", "b15", "mel_avgs"),
        scene_embedding_size=DIMENSIONS,
        timestamp_embedding_size=DIMENSIONS,
    ).eval()
    export_model = SceneEmbeddingModel(network).eval()

    golden_inputs: dict[str, torch.Tensor] = {}
    for name, source in make_golden_waveforms().items():
        decoded = write_pcm16_wav(output_dir / f"{name}.wav", source)
        golden_inputs[name] = torch.from_numpy(decoded).unsqueeze(0)
    shutil.copyfile(upstream / "LICENSE", output_dir / "LICENSE-EfficientAT.txt")

    with torch.no_grad():
        for name, waveform in golden_inputs.items():
            official = F.normalize(reference.get_scene_embeddings(waveform), p=2.0, dim=1, eps=1e-12)
            frozen = torch_scene_embedding(export_model, waveform)
            difference = float(torch.max(torch.abs(official - frozen)))
            cosine = float(F.cosine_similarity(official, frozen).item())
            if difference > 2e-4 or cosine < 0.999999:
                raise RuntimeError(
                    f"Frozen preprocessing mismatch for {name}: max_abs={difference}, cosine={cosine}"
                )

    onnx_path = output_dir / f"{PROFILE}.onnx"
    example = golden_inputs["modulated_texture_3s"]
    torch.onnx.export(
        export_model,
        example,
        onnx_path,
        input_names=["waveform"],
        output_names=["embedding_raw"],
        dynamic_axes={"waveform": {0: "batch", 1: "samples"}, "embedding_raw": {0: "batch"}},
        opset_version=17,
        do_constant_folding=True,
        dynamo=False,
    )
    model = onnx.load(str(onnx_path))
    onnx.checker.check_model(model)

    session = ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])
    golden_records = []
    for name, waveform in golden_inputs.items():
        with torch.no_grad():
            expected = torch_scene_embedding(export_model, waveform).numpy()[0]
        actual = ort_scene_embedding(session, waveform.numpy())[0]
        max_abs = float(np.max(np.abs(expected - actual)))
        cosine = float(np.dot(expected, actual) / (np.linalg.norm(expected) * np.linalg.norm(actual)))
        if max_abs > 2e-4 or cosine < 0.999999:
            raise RuntimeError(f"ONNX mismatch for {name}: max_abs={max_abs}, cosine={cosine}")
        golden_records.append(
            {
                "name": name,
                "audio_file": f"{name}.wav",
                "audio_sha256": sha256_file(output_dir / f"{name}.wav"),
                "samples": int(waveform.shape[1]),
                "embedding_sha256_float32_le": vector_digest(actual),
                "embedding": [float(value) for value in actual],
            }
        )

    golden_path = output_dir / "golden-v1.json"
    golden_path.write_text(
        json.dumps(
            {
                "schema": "PsyReaSFX-Neural-Golden-v1",
                "profile": PROFILE,
                "sample_rate": SAMPLE_RATE,
                "dimensions": DIMENSIONS,
                "tolerance": {"max_abs": 2e-4, "minimum_cosine": 0.999999},
                "cases": golden_records,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    manifest = {
        "schema": "PsyReaSFX-Neural-Model-v1",
        "profile": PROFILE,
        "model": MODEL_NAME,
        "dimensions": DIMENSIONS,
        "sample_rate": SAMPLE_RATE,
        "input": "mono float32 PCM in [-1,1]",
        "output": "raw per-window scene embedding; the sidecar averages windows then applies L2 normalization",
        "feature_taps": ["mel_avgs", "b5", "b11", "b13", "b15"],
        "upstream": {
            "repository": "https://github.com/fschmid56/EfficientAT_HEAR",
            "commit": UPSTREAM_COMMIT,
            "release": "https://github.com/fschmid56/EfficientAT/releases/tag/v0.0.1",
            "weights": "mn04_as_mAP_432.pt",
            "weights_sha256": WEIGHTS_SHA256,
            "license": "MIT",
        },
        "preprocessing": {
            "preemphasis": 0.97,
            "n_fft": 1024,
            "win_length": 800,
            "hop_length": 320,
            "hann_periodic": False,
            "center": True,
            "mel_bands": 128,
            "fmin": 0.0,
            "fmax": 15000.0,
            "log_offset": 1e-5,
            "normalization": "(x + 4.5) / 5",
            "maximum_window_samples": MAX_WINDOW_SAMPLES,
            "scene_hop_samples": SCENE_HOP_SAMPLES,
        },
        "export": {
            "torch": torch.__version__,
            "torchaudio": torchaudio.__version__,
            "onnx": onnx.__version__,
            "onnxruntime": ort.__version__,
            "opset": 17,
        },
        "artifacts": {},
    }
    for path in sorted(output_dir.iterdir()):
        if path.is_file() and path.name != "manifest-v1.json":
            manifest["artifacts"][path.name] = {
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
    manifest_path = output_dir / "manifest-v1.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Exported {onnx_path.name}: {onnx_path.stat().st_size} bytes")
    print(f"ONNX SHA-256: {sha256_file(onnx_path)}")
    print(f"Golden cases: {len(golden_records)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
