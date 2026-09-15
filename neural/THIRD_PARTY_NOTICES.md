# Third-party notices

The optional PsyReaSFX neural similarity component uses the following
third-party components:

- EfficientAT and EfficientAT_HEAR, Copyright © 2022 Florian Schmid — MIT
  License. The pinned upstream license is included with the model assets as
  `LICENSE-EfficientAT.txt`.
- `mn04_as_mAP_432.pt` AudioSet checkpoint from EfficientAT release `v0.0.1` —
  distributed under the upstream repository's MIT License.
- Microsoft.ML.OnnxRuntime — MIT License.
- NAudio.Core and NAudio.Wasapi, Copyright © 2020 Mark Heath — MIT License.

The EfficientAT_HEAR Python package metadata currently declares Apache-2.0,
while both pinned upstream repositories contain the same MIT `LICENSE` file.
PsyReaSFX records and redistributes the actual pinned license file rather than
silently relying on the inconsistent package metadata.
