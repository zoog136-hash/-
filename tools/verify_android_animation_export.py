#!/usr/bin/env python3
"""Inspect an actual TWILIGHT APK and compare exported native animation frames.

Example:
    python3 tools/verify_android_animation_export.py --apk build/TWILIGHT.apk \
        --godot /path/to/godot --output build/android-animation-validation

This checks exported resources and optional SDK signature/alignment tools. It
does not run the APK on an Android device or prove complete original-art delivery.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

from android_animation_export_scope import audit_authoring_exclusions


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resource_entry(resource_path: str) -> str:
    relative = resource_path.removeprefix("res://")
    if not resource_path.startswith("res://") or ".." in PurePosixPath(relative).parts:
        raise ValueError(f"Invalid exported resource path: {resource_path}")
    return "assets/" + relative


def run_logged(command: list[str], log: Path, timeout: int) -> int:
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
    return result.returncode


def sdk_checks(sdk: Path | None, apk: Path, output: Path, report: dict, timeout: int) -> None:
    if sdk is None:
        report["sdk_validation"] = {"status": "not_run", "reason": "Android SDK path was not supplied."}
        return
    candidates = [path for path in (sdk / "build-tools").glob("*") if (path / "apksigner").is_file()]
    if not candidates:
        report["failures"].append(f"Android SDK build tools missing: {sdk}")
        return
    build_tools = max(candidates, key=lambda path: tuple(int(n) for n in re.findall(r"\d+", path.name)))
    validation = {"build_tools": build_tools.name}
    commands = {
        "signature": [str(build_tools / "apksigner"), "verify", "--verbose", "--print-certs", str(apk)],
        "alignment": [str(build_tools / "zipalign"), "-c", "-P", "16", "-v", "4", str(apk)],
        "manifest": [str(build_tools / "aapt"), "dump", "badging", str(apk)],
    }
    for name, command in commands.items():
        code = run_logged(command, output / f"android-{name}.log", timeout)
        validation[name] = {"passed": code == 0, "exit_code": code}
        if code:
            report["failures"].append(f"Android {name} validation failed (exit {code})")
    report["sdk_validation"] = validation


def inspect_resources(apk: Path, root: Path, output: Path, report: dict) -> list[dict]:
    index = []
    scope = audit_authoring_exclusions(root)
    report["animation_export_scope"] = scope
    archived = {row["path"] for row in scope["excluded_authoring_resources"]}
    with zipfile.ZipFile(apk) as archive:
        report["zip_crc_failure"] = archive.testzip()
        if report["zip_crc_failure"]:
            report["failures"].append("APK ZIP CRC failed: " + report["zip_crc_failure"])
        names = set(archive.namelist())
        for relative in sorted(archived):
            if "assets/" + relative in names or "assets/" + relative + ".remap" in names:
                report["failures"].append("Archived review clip unexpectedly exported: " + relative)
        libraries = sorted(name for name in names if name.startswith("lib/") and name.endswith(".so"))
        report["native_libraries"] = libraries
        report["architectures"] = sorted({name.split("/")[1] for name in libraries})
        if report["architectures"] != ["arm64-v8a"]:
            report["failures"].append("Expected the existing Android ARM64 export preset")
        art_root = root / "assets/actors/eight_direction"
        sources = sorted(source for source in art_root.rglob("SpriteFrames.tres")
                         if source.relative_to(root).as_posix() not in archived)
        if not sources:
            report["failures"].append("No native SpriteFrames sources found")
        for source in sources:
            relative = source.relative_to(root).as_posix()
            remap = "assets/" + relative + ".remap"
            if remap not in names:
                report["failures"].append("Missing SpriteFrames remap: " + relative)
                continue
            match = re.search(r'(?m)^path\s*=\s*"(res://[^\"]+)"', archive.read(remap).decode())
            if not match:
                report["failures"].append("Invalid SpriteFrames remap: " + relative)
                continue
            binary_entry = resource_entry(match.group(1))
            if binary_entry not in names:
                report["failures"].append("Missing compiled SpriteFrames: " + binary_entry)
                continue
            destination = output / "compiled-resources" / source.parent.relative_to(root) / "SpriteFrames.res"
            destination.parent.mkdir(parents=True, exist_ok=True)
            binary = archive.read(binary_entry)
            destination.write_bytes(binary)
            row = {"source": "res://" + relative, "source_sha256": sha256(source),
                   "exported_binary": match.group(1), "exported_binary_sha256": hashlib.sha256(binary).hexdigest(),
                   "inspection_file": str(destination)}
            index.append(row)
        report["sprite_frames"] = index
        textures = []
        for source in sorted(art_root.rglob("*.png")):
            relative = source.relative_to(root).as_posix()
            import_entry = "assets/" + relative + ".import"
            if import_entry not in names:
                report["failures"].append("Missing PNG texture import: " + relative)
                continue
            texture_paths = re.findall(r'(?m)^path(?:\.[\w]+)?\s*=\s*"(res://[^\"]+\.ctex)"',
                                       archive.read(import_entry).decode())
            present = bool(texture_paths) and all(resource_entry(path) in names for path in texture_paths)
            if not present:
                report["failures"].append("Missing imported PNG texture: " + relative)
            texture_matches = []
            for texture_path in texture_paths:
                entry = resource_entry(texture_path)
                imported_source = root / texture_path.removeprefix("res://")
                if entry not in names or not imported_source.is_file():
                    report["failures"].append("Cannot compare imported PNG bytes: " + texture_path)
                    continue
                packed_sha = hashlib.sha256(archive.read(entry)).hexdigest()
                matches = packed_sha == sha256(imported_source)
                if not matches:
                    report["failures"].append("Exported PNG texture differs from source import: " + relative)
                texture_matches.append({"path": texture_path, "sha256": packed_sha,
                                        "byte_identical_to_source_import": matches})
            textures.append({"source": relative, "source_sha256": sha256(source),
                             "exported_textures": texture_paths, "all_present": present,
                             "imported_texture_comparisons": texture_matches})
        report["png_textures"] = textures
        json_sources = [root / relative for relative in ["data/combat_animation_profiles.json",
                                                        "data/animation_presentation.json",
                                                        "data/resource_delivery_ledger.json"]]
        json_sources.extend(sorted(art_root.rglob("provenance.json")))
        report["raw_json_matches"] = []
        for source in json_sources:
            relative = source.relative_to(root).as_posix()
            data = source.read_bytes()
            matches = "assets/" + relative in names and archive.read("assets/" + relative) == data
            if not matches:
                report["failures"].append("Exported JSON differs from current source: " + relative)
            report["raw_json_matches"].append({"path": relative, "byte_identical": matches,
                                               "sha256": hashlib.sha256(data).hexdigest()})
    return index


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", required=True, help="Godot executable matching the APK export version")
    parser.add_argument("--output", type=Path, required=True, help="Directory for JSON, logs and small compiled resources")
    parser.add_argument("--android-sdk", type=Path, default=os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT"))
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    apk, root, output = args.apk.resolve(), args.root.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "apk": str(apk),
              "failures": [], "device_execution": {"status": "not_run",
              "reason": "This verifier inspects the APK; device execution requires a separate connected device test."}}
    try:
        report["apk_bytes"], report["apk_sha256"] = apk.stat().st_size, sha256(apk)
        report["godot_version"] = subprocess.check_output([args.godot, "--version"], text=True, timeout=30).strip()
        index = inspect_resources(apk, root, output, report)
        index_path = output / "android-resource-index.json"
        index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")
        frames_path = output / "android-compiled-frames.json"
        # Delete a previous result so a failed engine run cannot reuse a stale pass.
        frames_path.unlink(missing_ok=True)
        command = [args.godot, "--headless", "--path", str(root), "--script",
                   str(root / "tools/android_export_frames.gd"), "--", "--index", str(index_path),
                   "--output", str(frames_path)]
        code = run_logged(command, output / "android-compiled-frames.log", args.timeout)
        if code or not frames_path.is_file():
            report["failures"].append(f"Godot compiled frame inspection failed (exit {code})")
        else:
            frames = json.loads(frames_path.read_text())
            report["compiled_native_sprite_frames_validation"] = frames
            if not frames.get("passed", False) or frames.get("sprite_frames") != len(index):
                report["failures"].append("Exported SpriteFrames differ from source")
        sdk_checks(args.android_sdk, apk, output, report, args.timeout)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        report["failures"].append(str(error))
    report["passed"] = not report["failures"]
    (output / "android.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("ANDROID_ANIMATION_EXPORT " + json.dumps({key: report.get(key) for key in
          ["passed", "apk_sha256", "architectures", "failures"]}, ensure_ascii=False))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
