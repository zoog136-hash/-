"""PR122 opt-in palette/name variants. Never writes shared catalogues or sources.

Only reviewed same-model recipes may produce an integration patch. A mask is
mandatory for palette changes. No whole-sprite tint is accepted as finished art.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import tempfile
from pathlib import Path
from typing import Any

from PIL import Image

OUTPUT = Path("assets/actors/eight_direction/palette_alias_pr122/generated")
PROTECTED = {f"transform:{n}" for n in (
    393, 267, 258, 412, 288, 401, 176, 351, 349, 328, 249, 218, 173, 167, 110, 2
)}
TEXTURE = re.compile(r'(\[ext_resource\s+type="Texture2D"\s+path=")([^"]+)("[^\n]*\])')


class Hold(ValueError):
    """A source, review or concurrency gate is not satisfied."""


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record_hash(value: Any) -> str:
    return digest(json.dumps(value, ensure_ascii=False, sort_keys=True,
                             separators=(",", ":"), allow_nan=False).encode())


def local_path(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value.startswith("res://"):
        raise Hold("A res:// path is required")
    relative = value[6:]
    if not relative or "\\" in relative or Path(relative).is_absolute():
        raise Hold("Invalid resource path")
    path = (root.resolve() / relative).resolve()
    if path == root.resolve() or not path.is_relative_to(root.resolve()):
        raise Hold("Resource path escapes repository")
    return path


def checked_bytes(root: Path, uri: str, expected: str) -> bytes:
    if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise Hold("Missing SHA-256 lock")
    path = local_path(root, uri)
    if not path.is_file():
        raise Hold(f"Missing source: {uri}")
    data = path.read_bytes()
    if digest(data) != expected:
        raise Hold(f"Source changed: {uri}")
    return data


def recolor_masked(source: Image.Image, mask: Image.Image,
                   color: str) -> tuple[Image.Image, int]:
    """0=protected; 255=selected. Retain source alpha and HSV value shading."""
    if source.mode != "RGBA" or mask.mode != "L" or source.size != mask.size:
        raise Hold("Require an RGBA source and same-size L semantic mask")
    if not isinstance(color, str) or not re.fullmatch(r"[0-9a-fA-F]{6}", color):
        raise Hold("Require a six-digit RGB color")
    tint = tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))
    peak = max(tint)
    if peak == 0:
        raise Hold("Black tint destroys shading; use a reviewed dark palette")
    pixels = []
    changed = 0
    for original, weight in zip(source.getdata(), mask.getdata()):
        r, g, b, alpha = original
        if weight == 0 or alpha == 0:
            pixels.append(original)
            continue
        value = max(r, g, b)
        mapped = tuple((value * channel + peak // 2) // peak for channel in tint)
        result = tuple((old * (255 - weight) + new * weight + 127) // 255
                       for old, new in zip((r, g, b), mapped)) + (alpha,)
        pixels.append(result)
        changed += result != original
    output = Image.new("RGBA", source.size)
    output.putdata(pixels)
    return output, changed


def _review_gate(recipe: dict, profiles: dict, protected: set[str]) -> None:
    target, source = recipe.get("target"), recipe.get("source")
    if target in protected or source in protected:
        raise Hold("Target or donor belongs to the native/locomotion worker")
    if not isinstance(target, str) or not isinstance(source, str) or target == source:
        raise Hold("Distinct target and source IDs are required")
    visited = set()
    cursor = source
    while cursor:
        if cursor in visited or cursor in protected or cursor not in profiles:
            raise Hold("Donor chain is cyclic, protected or missing")
        visited.add(cursor)
        cursor = profiles[cursor].get("shared_visual_source", "")
    if recipe.get("identity_verified") is not True:
        raise Hold("Same-model identity has not been reviewed")
    if not recipe.get("identity_evidence"):
        raise Hold("Missing same-model evidence")
    if recipe.get("source_motion_reviewed") is not True:
        raise Hold("Source motion quality has not been reviewed")
    for role, key in (("target", target), ("source", source)):
        if key not in profiles or record_hash(profiles[key]) != recipe.get(f"{role}_record_sha256"):
            raise Hold(f"{role} record changed; refresh the recipe, not the catalogue")
    if recipe.get("kind") not in ("name_alias", "masked_palette"):
        raise Hold("Unknown variant kind")
    if recipe["kind"] == "name_alias" and any(
        profiles[key].get("color_tint", "ffffff").lower() != "ffffff"
        for key in (target, source)
    ):
        raise Hold("Name-only aliases cannot erase an existing tint")
    if recipe["kind"] == "masked_palette" and recipe.get("mask_reviewed") is not True:
        raise Hold("An explicit reviewed clothing/equipment mask is required")


def build(root: Path, recipe: dict, profiles: dict,
          protected: set[str] | None = None) -> dict:
    """Reserve a new directory; publish its patch last. Never apply the patch."""
    root = root.resolve()
    _review_gate(recipe, profiles, PROTECTED | (protected or set()))
    slug = recipe.get("slug", "")
    if not isinstance(slug, str) or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,79}", slug):
        raise Hold("Invalid output slug")
    destination = local_path(root, "res://" + (OUTPUT / slug).as_posix())
    if destination.exists():
        raise Hold("Output already exists; do not overwrite another worker")
    frames_uri = recipe.get("frames_path", "")
    for key in (recipe["target"], recipe["source"]):
        if profiles[key].get("frames_path") != frames_uri:
            raise Hold("Only an already-confirmed same frames family is supported")
    source_bytes = checked_bytes(root, frames_uri, recipe.get("frames_sha256", ""))
    text = source_bytes.decode("utf-8")
    if not text.startswith('[gd_resource type="SpriteFrames"'):
        raise Hold("Expected a text SpriteFrames resource")
    matches = list(TEXTURE.finditer(text))
    declarations = re.findall(r'\[ext_resource[^\n]*type="Texture2D"[^\n]*\]', text)
    if len(matches) != len(declarations) or any("uid=" in m.group(0) for m in matches):
        raise Hold("Unsupported texture declaration or UID; explicit migration required")
    paths = list(dict.fromkeys(match.group(2) for match in matches))
    if not paths:
        raise Hold("No supported Texture2D dependencies")
    textures = recipe.get("textures", {})
    if set(paths) != set(textures):
        raise Hold("Every source texture must have an explicit hash lock")
    locks = {frames_uri: recipe["frames_sha256"]}
    texture_bytes = {}
    for uri in paths:
        texture_bytes[uri] = checked_bytes(root, uri, textures[uri].get("sha256", ""))
        locks[uri] = textures[uri]["sha256"]
    # All writes stay inside this worker's new generated directory.
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".stage-", dir=destination.parent) as tmp:
        stage = Path(tmp)
        replacements = {}
        changed = 0
        if recipe["kind"] == "masked_palette":
            for index, uri in enumerate(paths):
                info = textures[uri]
                mask_uri = info.get("mask_path", "")
                mask_bytes = checked_bytes(root, mask_uri, info.get("mask_sha256", ""))
                locks[mask_uri] = info["mask_sha256"]
                with Image.open(io.BytesIO(texture_bytes[uri])) as image, Image.open(io.BytesIO(mask_bytes)) as mask:
                    output, count = recolor_masked(image, mask, recipe.get("color", ""))
                filename = f"atlas_{index:03d}.png"
                output.save(stage / filename)
                changed += count
                replacements[uri] = "res://" + (OUTPUT / slug / filename).as_posix()
            if changed == 0:
                raise Hold("The masks produced no changed pixels; do not count a no-op")
            rewritten = TEXTURE.sub(lambda m: m.group(1) + replacements[m.group(2)] + m.group(3), text)
            # Restore only texture URIs to prove every other byte was retained.
            inverse = {value: key for key, value in replacements.items()}
            restored = TEXTURE.sub(lambda m: m.group(1) + inverse[m.group(2)] + m.group(3), rewritten)
            if restored != text:
                raise Hold("Animation metadata was changed")
            (stage / "SpriteFrames.tres").write_text(rewritten, encoding="utf-8", newline="")
            result_frames = "res://" + (OUTPUT / slug / "SpriteFrames.tres").as_posix()
        else:
            result_frames = frames_uri  # No copied PNG or fabricated animation.
        patch = {
            "schema": 1, "target": recipe["target"], "source": recipe["source"],
            "name": profiles[recipe["target"]]["name"], "kind": recipe["kind"],
            "expected_target_record_sha256": recipe["target_record_sha256"],
            "expected_source_record_sha256": recipe["source_record_sha256"],
            "resource_sha256_locks": locks,
            "set_visual_fields": {"frames_path": result_frames, "color_tint": "ffffff"},
            "changed_pixels": changed, "new_motion_poses": 0,
            "animation_bytes_preserved_except_texture_paths": True,
            "godot_playback": "NOT_RUN", "main_integration": "NOT_APPLIED",
            "identity_evidence": recipe["identity_evidence"],
        }
        patch["output_sha256"] = {p.name: digest(p.read_bytes()) for p in stage.iterdir()}
        (stage / "integration_patch.json").write_text(
            json.dumps(patch, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for uri, sha in locks.items():
            checked_bytes(root, uri, sha)
        # mkdir(exist_ok=False) reserves a new directory without replacing even an
        # empty competing directory. Publish the patch last as the ready marker.
        try:
            destination.mkdir()
        except FileExistsError as error:
            raise Hold("Output appeared during generation") from error
        for artifact in sorted(stage.iterdir(), key=lambda p: p.name == "integration_patch.json"):
            artifact.rename(destination / artifact.name)
        return patch


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--recipe", type=Path, required=True)
    parser.add_argument("--protected-targets", type=Path, required=True,
                        help="JSON list of latest native-worker owned target IDs")
    args = parser.parse_args()
    try:
        recipe = json.loads(args.recipe.read_text(encoding="utf-8"))
        profiles = json.loads((args.root / "data/combat_animation_profiles.json").read_text(encoding="utf-8"))["profiles"]
        protected = json.loads(args.protected_targets.read_text(encoding="utf-8"))
        if not isinstance(protected, list) or not protected or not all(isinstance(x, str) for x in protected):
            raise Hold("Latest native ownership list is required")
        result = build(args.root, recipe, profiles, set(protected))
    except (Hold, OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({"status": "HOLD", "reason": str(error)}, ensure_ascii=False))
        return 2
    print(json.dumps({"status": "STAGED_NOT_INTEGRATED", "target": result["target"],
                      "changed_pixels": result["changed_pixels"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
