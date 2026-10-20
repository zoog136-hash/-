# TWILIGHT map asset bundles

This folder holds runtime map data preserved separately from source code.

## Oman 1–10 map-remake v2
- File: `TWILIGHT-map-remake-private-20261015-v2.zip`
- SHA-256: `9123660429fc06a9e88a3f7719f2121401f53dc57d71e1da543b085caa399708`
- Size: 1,413,515 bytes
- Contents: `data/map_remake/private/`, `effective_layouts.json`, `DELIVERY_MANIFEST.json`
- To install into a freshly downloaded main source checkout, extract the archive **at the Godot project root**, preserving directories; verify SHA-256 first.
- Original gameplay coordinates and modern Lineage M visual fidelity are not thereby verified.

## Albino / Escaros / Temples native PNG v5
The runtime native-PNG pack has been independently recovered from the owner's Google Drive and verified against `data/maps/native_png_archive.json`. It is 274,172,103 bytes split into three pieces of 94,371,840, 94,371,840 and 85,428,423 bytes. **The v5 binary pieces are NOT yet bundled here.** Refer to `docs/native-png-maps-20261019/README.md` for installation and verification.

Do not confuse the source-code presence of PR #128 with installed runtime PNG content. The PNG mode is opt-in, and regular Godot Android project import does not automatically install private PNG assets.
