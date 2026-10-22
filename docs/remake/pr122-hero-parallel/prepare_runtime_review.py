#!/usr/bin/env python3
"""Build a symlinked Main review project; leave branch common runtime untouched."""
import difflib
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
OVERLAY = Path('/workspace/runtime/pr122-hero-death-review-20261022-r001')
REVIEW = ROOT / 'docs/remake/pr122-hero-parallel/runtime-review'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--overlay-dir', type=Path, default=OVERLAY)
    args = parser.parse_args()
    overlay = args.overlay_dir.resolve()
    relative = 'scripts/animation/actor_motion.gd'
    current = (ROOT / relative).read_text()
    needle = '\tif dead: tint.a = 1.0 - clampf((death_clock - maxf(0.55, profile.death_duration)) / 0.45, 0.0, 1.0)'
    replacement = ('\tvar keep_hero_corpse: bool = source != null and profile.profile_id.begins_with("transform:") and bool(source.get_meta("pr122_hero_hold_final_death_frame", false))\n'
                   '\tif dead and not keep_hero_corpse: tint.a = 1.0 - clampf((death_clock - maxf(0.55, profile.death_duration)) / 0.45, 0.0, 1.0)')
    upstream = 'func _available_death_key(' in current
    if upstream:
        old, new = current, current
    elif current.count(needle) == 1:
        old, new = current, current.replace(needle, replacement)
    else:
        assert current.count(replacement) == 1, 'Review against current runtime before updating this patch'
        old, new = current.replace(replacement, needle), current
    REVIEW.mkdir(parents=True, exist_ok=True)
    patch = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                      fromfile='a/' + relative, tofile='b/' + relative))
    patch_path = REVIEW / 'hero-corpse-hold.patch'
    if upstream:
        pass # Preserve the superseded local patch as historical review evidence.
    elif patch_path.exists():
        assert patch_path.read_text() == patch, 'Preserve prior reviewed patch'
    else:
        patch_path.write_text(patch)
    if overlay.exists():
        assert (overlay / relative).read_text() == new, 'Use a fresh directory for a changed runtime review'
        print('HERO_RUNTIME_REVIEW_REUSED overlay=' + str(overlay))
        return
    overlay.mkdir(parents=True)
    for item in ROOT.iterdir():
        if item.name in ['.git', '.godot', 'scripts']:
            continue
        (overlay / item.name).symlink_to(item, target_is_directory=item.is_dir())
    shutil.copytree(ROOT / 'scripts', overlay / 'scripts')
    (overlay / relative).write_text(new)
    cache = overlay / '.godot'
    cache.mkdir()
    (cache / '.gdignore').write_text('')
    imported = ROOT / '.godot/imported'
    if imported.exists():
        (cache / 'imported').symlink_to(imported, target_is_directory=True)
    for name in ['global_script_class_cache.cfg', 'uid_cache.bin', 'extension_list.cfg']:
        source = ROOT / '.godot' / name
        if source.exists():
            shutil.copyfile(source, cache / name)
    receipt = dict(schema='hero-common-runtime-review-overlay-v1', overlay_path=str(overlay),
                   mode='UPSTREAM_EXACT_COPY' if upstream else 'LOCAL_OPT_IN_PATCH_REVIEW',
                   source_path=relative, source_sha256=hashlib.sha256(old.encode()).hexdigest(),
                   reviewed_sha256=hashlib.sha256(new.encode()).hexdigest(),
                   patch_path=str(patch_path.relative_to(ROOT)), branch_runtime_modified=current != old,
                   original_pr_modified=False, scope='opacity only for opt-in hero candidate resources')
    receipt_path = REVIEW / 'overlay-receipt.json'
    if receipt_path.exists(): receipt_path = REVIEW / ('overlay-receipt-' + overlay.name + '.json')
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    assert (ROOT / relative).read_text() == current
    print('HERO_RUNTIME_REVIEW_READY overlay=' + str(overlay))


if __name__ == '__main__':
    main()
