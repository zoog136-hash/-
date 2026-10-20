"""Pack six authored PNG poses losslessly; this does not approve animation."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import os
from PIL import Image


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def finite(value):
    if isinstance(value, float):
        require(math.isfinite(value), "Nonfinite metadata")
    elif isinstance(value, dict):
        for item in value.values():
            finite(item)
    elif isinstance(value, list):
        for item in value:
            finite(item)


def decode(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate metadata member")
            result[key] = value
        return result
    value = json.loads(data, object_pairs_hook=pairs)
    finite(value)
    return value


def path_file(value):
    path = Path(value)
    require(path.is_absolute() and path.resolve() == path and path.is_file(), "Canonical regular input required")
    require(not any(p.is_symlink() for p in (path, *path.parents)), "Symlink input forbidden")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", required=True, type=Path)
    parser.add_argument("--expected-plan-sha256", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    plan_path = path_file(args.plan)
    plan_bytes = plan_path.read_bytes()
    require(len(plan_bytes) < 100000 and sha(plan_bytes) == args.expected_plan_sha256, "Pinned packing plan changed")
    plan = decode(plan_bytes)
    require(plan["schema"] == "pr122-authored-six-pose-packing-v1", "Explicit authoring plan required")
    require(plan["key"] == "transform:413" and plan["role"] in ("walk", "run", "idle", "attack", "hit", "death") and plan["direction"] in ("NW", "N", "NE"), "Missing 413 rear dedicated clip only")
    require(plan["root_basis"] == "PINNED_RIG_ROOT_NOT_ALPHAFOOT", "Never infer root from changing pose alpha")
    require(plan["logical_canvas"] == 1024, "Retain original profile logical canvas")
    canvas = plan["physical_canvas"]
    require(type(canvas) is int and 256 <= canvas <= 4096 and canvas % 8 == 0, "Single fixed body-unit canvas required")
    root = plan["rig_root_in_unpadded_frame"]
    require(isinstance(root, list) and len(root) == 2 and all(type(v) in (int, float) for v in root), "Pinned actual rig root required")
    tile = plan["tile_size"]
    require(isinstance(tile, list) and len(tile) == 2 and all(type(v) is int and 256 <= v <= 2048 for v in tile), "Bounded native tile required")
    frames = plan["frames"]
    require(len(frames) == 6 and [f["phase"] for f in frames] == list(range(6)), "Exactly six chronological actual poses required")
    output = args.output
    require(output.is_absolute() and output.resolve() == output and output.is_relative_to(Path("/workspace/scratch")), "Exclusive scratch output only")
    proof_path = output.with_suffix(".packing.json")
    require(not any(p.is_symlink() for p in (output, *output.parents)), "Symlink output forbidden")
    require(not os.path.lexists(output) and not os.path.lexists(proof_path), "Preserve pre-existing output")
    atlas = Image.new("RGBA", (tile[0] * 2, tile[1] * 3))
    ready, rows = [], []
    for frame in frames:
        source = path_file(frame["path"])
        data = source.read_bytes()
        require(len(data) <= 10 * 1024 * 1024 and sha(data) == frame["sha256"], "Actual pose source changed")
        image = Image.open(source)
        require(image.format == "PNG" and image.mode == "RGBA", "Exact RGBA PNG required; no implicit conversion")
        require(image.width <= tile[0] and image.height <= tile[1], "Never resize a pose to fit")
        image.load()
        translation = frame.get("storage_translation", [0, 0])
        require(len(translation) == 2 and all(type(v) is int for v in translation), "Explicit integer storage translation required")
        bounds = image.getchannel("A").getbbox()
        require(bounds is not None, "Empty pose forbidden")
        phase = frame["phase"]
        origin = [(phase % 2) * tile[0], (phase // 2) * tile[1]]
        anchor = [root[i] + translation[i] for i in (0, 1)]
        margins = [canvas * .5 - (anchor[0] - bounds[0]), canvas * .625 - (anchor[1] - bounds[1])]
        require(min(margins) >= 0 and margins[0] + bounds[2] - bounds[0] <= canvas and margins[1] + bounds[3] - bounds[1] <= canvas, "Pinned root/body canvas cannot contain whole pose")
        atlas.paste(image, tuple(origin))
        pixels = sha(image.tobytes())
        require(sha(atlas.crop((origin[0], origin[1], origin[0] + image.width, origin[1] + image.height)).tobytes()) == pixels, "Packing changed pose RGBA")
        ready.append((source, frame["sha256"], origin, image.size, pixels))
        rows.append(dict(phase=phase, source=str(source), source_sha256=frame["sha256"], source_size=list(image.size), source_rgba_sha256=pixels, atlas_origin=origin, region=[origin[0]+bounds[0], origin[1]+bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]], atlas_root_anchor=[anchor[i]+origin[i] for i in (0, 1)], physical_canvas=canvas, virtual_foot=[canvas*.5, canvas*.625], storage_translation=translation))
    require(len({item[1] for item in ready}) == 6, "Six distinct completed authored poses required")
    require(len({(item[3], item[4]) for item in ready}) == 6, "Identical pose pixels with different PNG encoding are not new poses")
    require(plan_path.read_bytes() == plan_bytes and all(sha(source.read_bytes()) == expected for source, expected, *_ in ready), "Author inputs changed before write")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        atlas.save(stream, format="PNG", compress_level=6)
        stream.flush()
        os.fsync(stream.fileno())
    saved = Image.open(output)
    saved.load()
    require(saved.mode == "RGBA" and saved.size == atlas.size, "Saved atlas shape changed")
    for source, expected, origin, size, pixels in ready:
        require(sha(source.read_bytes()) == expected, "Source changed after packing")
        require(sha(saved.crop((origin[0], origin[1], origin[0]+size[0], origin[1]+size[1])).tobytes()) == pixels, "Saved PNG changed actual pose pixels")
    proof = dict(status="PACKED_EXACT_RGBA_NOT_ANIMATION_APPROVAL", key=plan["key"], direction=plan["direction"], role=plan["role"], plan_path=str(plan_path), plan_sha256=sha(plan_bytes), output=str(output), output_sha256=sha(output.read_bytes()), image_size=list(saved.size), fixed_physical_canvas=canvas, logical_canvas=1024, source_resampled=False, actor_approvals_added=0, authored_poses=rows)
    with proof_path.open("x") as stream:
        json.dump(proof, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps(dict(status=proof["status"], output=str(output), sha256=proof["output_sha256"], poses=6, source_resampled=False)))


if __name__ == "__main__":
    main()
