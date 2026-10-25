"""Keep archived first-pass clips out of APKs without dropping runtime resources."""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
from pathlib import Path
import re

DRAFT_EXPORT_PATTERN = "assets/actors/eight_direction/native_locomotion_staging/transform_*/draft001/*"
DRAFT_ROOT = "assets/actors/eight_direction/native_locomotion_staging"
RESOURCE_PATH = re.compile(r'"(res://[^"\n]+)"')
REQUIRED_RUNTIME_JSON = (
    "data/combat_animation_profiles.json", "data/animation_presentation.json",
    "data/catalog_v19.json",
)
# Archived original PNG build metadata is excluded from the APK. The actual
# runtime streams from the separate aden_mobile_pack.json and encoded .bin data.
ARCHIVED_SOURCE_MANIFEST = "assets/maps/aden_city_region/compiled/manifest.json"
ADEN_RUNTIME_MANIFEST = "data/maps/aden_mobile_pack.json"


def audit_authoring_exclusions(root: Path) -> dict:
    """Prove the exact excluded files are detached, docs-backed review clips.

    A new runtime/catalog reference or a changed kind of file fails closed. All
    selected native clips, approved resources, textures and production catalog
    entries remain inside the existing APK verification scope.
    """
    root = root.resolve()
    preset = (root / "export_presets.cfg").read_text(encoding="utf-8")
    filters = re.findall(r'^exclude_filter="([^"]*)"$', preset, re.MULTILINE)
    if len(filters) != 1 or DRAFT_EXPORT_PATTERN not in filters[0].split(","):
        raise ValueError("Android preset must explicitly exclude only the archived draft001 scope")
    excluded_patterns = filters[0].split(",")
    excluded = []
    for folder in sorted((root / DRAFT_ROOT).glob("transform_*/draft001")):
        actor = folder.parent.name
        if not re.fullmatch(r"transform_[0-9]+", actor):
            raise ValueError("Unexpected authoring folder: " + str(folder))
        expected_source = re.compile(
            r"res://docs/remake/evidence/pr122-mythic-detailed/batch03/"
            + re.escape(actor) + r"-.+-draft-v01\.png")
        for path in sorted(folder.iterdir()):
            if not path.is_file() or path.is_symlink() or path.suffix != ".tres":
                raise ValueError("Only archived review SpriteFrames may be excluded: " + str(path))
            content = path.read_text(encoding="utf-8")
            references = RESOURCE_PATH.findall(content)
            if not content.startswith('[gd_resource type="SpriteFrames"') or len(references) != 1:
                raise ValueError("Excluded resource is not a single-source review clip: " + str(path))
            if not expected_source.fullmatch(references[0]):
                raise ValueError("Excluded clip no longer references its archived draft PNG: " + str(path))
            excluded.append({"path": path.relative_to(root).as_posix(),
                             "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                             "source": references[0]})

    paths = {row["path"] for row in excluded}
    forbidden = re.compile(r"(?:res://)?" + re.escape(DRAFT_ROOT)
                           + r"/transform_[0-9]+/draft001/")
    checked = 0
    for relative in REQUIRED_RUNTIME_JSON:
        if paths and not (root / relative).is_file():
            raise ValueError("Missing runtime catalog for export closure: " + relative)
    # Runtime code can load new JSON manifests indirectly. Check every exported
    # JSON in the runtime trees, not a fixed allowlist of known catalog names.
    json_files = sorted(path for top in ("data", "assets", "scenes", "scripts")
                        for path in (root / top).rglob("*.json") if path.is_file())
    for path in json_files:
        relative = path.relative_to(root).as_posix()
        content = path.read_text(encoding="utf-8")
        json.loads(content)
        excluded_by_preset = any(fnmatch.fnmatchcase(relative, pattern) for pattern in excluded_patterns)
        if forbidden.search(content):
            raise ValueError("Runtime or selected staging manifest references excluded draft001: " + relative)
        if excluded_by_preset:
            # Only this exact authoring-time PNG manifest can be missing from
            # the APK, not a catalog used by the running game.
            if relative != ARCHIVED_SOURCE_MANIFEST:
                raise ValueError("Runtime catalog excluded by Android preset: " + relative)
            runtime = root / ADEN_RUNTIME_MANIFEST
            if not runtime.is_file() or any(fnmatch.fnmatchcase(ADEN_RUNTIME_MANIFEST, pattern)
                                            for pattern in excluded_patterns):
                raise ValueError("Aden runtime pack manifest is missing from Android export")
            pack = json.loads(runtime.read_text(encoding="utf-8"))
            if pack.get("schema") != 1 or pack.get("map_id") != "aden_world" or not re.fullmatch(
                    r"[0-9a-f]{64}", str(pack.get("manifest_sha256", ""))):
                raise ValueError("Invalid Aden runtime pack manifest")
            continue
        checked += 1
    files = [root / "Main.tscn", root / "project.godot"]
    for top in ("assets", "scenes", "scripts"):
        files.extend(path for path in (root / top).rglob("*")
                     if path.suffix in {".gd", ".tres", ".tscn", ".png", ".webp", ".svg"})
    for path in files:
        relative = path.relative_to(root).as_posix()
        if relative in paths or not path.is_file():
            continue
        if any(fnmatch.fnmatchcase(relative, pattern) for pattern in excluded_patterns):
            raise ValueError("Non-archive runtime resource excluded by Android preset: " + relative)
        if path.suffix not in {".png", ".webp"} and forbidden.search(path.read_text(encoding="utf-8")):
            raise ValueError("Exported code/resource references excluded draft001: " + relative)
        checked += 1
    return {"excluded_authoring_resources": excluded,
            "excluded_count": len(excluded), "runtime_closure_files_checked": checked,
            "production_resources_excluded": 0, "source_files_deleted": 0}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit_authoring_exclusions(args.root)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("ANDROID_ANIMATION_SCOPE_OK archived_review_clips=%d runtime_closure_files=%d production_excluded=0" %
          (report["excluded_count"], report["runtime_closure_files_checked"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
