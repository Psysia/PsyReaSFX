# UCS catalog provenance

PsyReaSFX derives `ucs-8.2.1.tsv` from the official
`UCS v8.2.1 Full Translations.xlsx` workbook published through the
[Universal Category System resources page](https://universalcategorysystem.com/).

- UCS version: `8.2.1`
- Source workbook SHA-256: `CACA08099B40203897365C02B6A52F5556ADA7BEB695ADCE2A6C64640AA9E195`
- Official resource archive SHA-256 at extraction time:
  `B07056157FB5AB6D0053251A72834294BE19CE62154A357093311AFD509414A0`
- Extracted fields: Category, SubCategory, CatID, CatShort, Explanations,
  English Synonyms, Simplified Chinese Category/SubCategory/Synonyms.
- Extracted records: `753`

UCS describes the project and its resources as Public Domain. PsyReaSFX keeps
the official data separate from future user dictionaries and classifier rules.
Regenerate the compact file with `tools/generate_ucs_catalog.py`; do not edit
generated category rows by hand.
