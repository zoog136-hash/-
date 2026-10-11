# TWILIGHT — Codex Google Drive source handoff (2026-10-11)

## Actual source location

- Google Drive folder (private): https://drive.google.com/drive/folders/1QTl1U45iWuJeQcI9ljuV11Le8nkXK-39
- Split archives folder: https://drive.google.com/drive/folders/11fcRnrEJAanWR6fIYaor4U34_ib1DgcH
- Total: 16 sanitized source ZIP archives, 836,676,007 bytes (~798 MiB).
- 11 ZIP files are stored directly in the top-level Drive folder.
- Five source ZIP files (a1.zip, a2002.zip, a2003.zip, a3.zip, immma2004.zip) are provided as 18 chunks under drive_chunks/ to respect connector transfer limits.
- Drive upload operations succeeded. Folder listings verified each expected filename and size. Full remote redownload and SHA-256 recheck is still pending.

## Drive contents

- README_CODEX_DRIVE_KO.md — Korean handoff and inventory.
- SOURCE_ARCHIVES_MANIFEST.json — per-archive sanitized SHA-256, original SHA, size, and excluded sensitive paths.
- DRIVE_CHUNK_MANIFEST.json — per-chunk SHA-256 and assembly order.
- DRIVE_DELIVERY_RECEIPT.json — source delivery summary.
- verify_archive_manifest.py — SHA-256 and ZIP CRC validator for all 16 archives.
- reassemble_drive_chunks.py — reconstruct the five large archives from the 18 chunks.
- source ZIP files and drive_chunks/ subfolder.

## Codex access procedure

1. In Codex use **Sources > Use plugins > Google Drive**, if available for the account/workspace, and connect the Google account that owns the folder.
2. Search for `TWILIGHT_Codex_Source_Archive_20261011` or open the folder link. The Drive link alone does not grant private-file access or automatically mount files into the runtime.
3. Obtain all 11 direct ZIPs and 18 split parts, manifests, and two Python validation scripts in a Codex-accessible working directory, preserving `source_archives/` and `drive_chunks/`.
4. Run `python3 reassemble_drive_chunks.py` followed by `python3 verify_archive_manifest.py`. Do not claim resources installed until the full bytes and hashes pass in the Codex runtime.
5. Recheck remote head on PR #84 before code work. This handoff branch is independent and does not modify or merge PR #84 or main.
6. Do not commit third-party graphics or private credentials into a public repo without appropriate rights/security review. Six PEM/PFX private-key files were excluded from the sanitized archives.

## Important scope boundary

This GitHub documentation does **not** contain the 798 MiB of ZIP bytes; the actual archives are in private Drive. The Google Drive connection and binary download capability in the target Codex session must be tested separately. There has been no claim of Codex-side verification or Godot installation.
