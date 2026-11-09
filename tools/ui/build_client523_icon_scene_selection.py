#!/usr/bin/env python3
"""Icon CSB scene selection for the existing source523 image/UI icon path.

Inputs are two private packs built from the complete 523 client:

* the source523 image pack (build_source523_image_pack.py) whose AssetView rows
  of AssetType 101 are recorded as ``unsupported_csb`` (icon CSB scenes);
* an original UI pack (build_original_ui_pack.py) with no blockers that holds
  those ``UI/CsbFile/icon/*.csb`` scenes and their dependency closure.

Output: a ``source523-original-ui-icon-selection-v1`` document for
``Source523ImageAssets.configure_original_ui_selection`` (CLI
``--source523-ui-icons=<file> --source523-ui-icons-sha256=<pin>``).

Playback follows the client (LineageM 1.10.22.0 static analysis, common UI icon
setter 0x00C381A0): an AssetType 101 icon becomes a CSB node attached to the
slot Sprite, and its timeline plays ``normal`` with loop=true
(timeline.play("normal", true) at 0x00C386B1; play() starts at the clip's
start frame and never selects another clip). A scene without exactly one
``normal`` clip is therefore reported, not given another clip.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import sys

SELECTION_SCHEMA = 'source523-original-ui-icon-selection-v1'
SCENES_SCHEMA = 'patch523-original-ui-icon-scenes-v1'
PREFIX = 'UI/CsbFile/'
CLIP = 'normal'
POLICY_SOURCE = ('LineageM_1.10.22.0 static analysis (UI CSB stage 6): common icon setter 0x00C381A0 '
                 'attaches the AssetType101 CSB to the slot Sprite and calls timeline.play("normal", true) '
                 'at 0x00C386B1; play starts at the clip start frame and selects no other clip')
MAX_BYTES = 2 * 1024 * 1024  # Source523ImageAssets.ORIGINAL_UI_SELECTION_MAX_BYTES


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build(image_manifest_path: Path, ui_pack: Path, output: Path, pack_root: str | None = None) -> dict:
    image_raw = image_manifest_path.read_bytes()
    images = json.loads(image_raw)
    if images.get('source_snapshot') != 'patch523' and images.get('source_version') not in (523, '523'):
        raise SystemExit('image manifest is not the 523 source image pack')
    ui_raw = (ui_pack / 'original_ui.json').read_bytes()
    ui = json.loads(ui_raw)
    if ui.get('schema') != 'twilight-original-ui-v1':
        raise SystemExit('UI pack manifest schema differs')
    if ui.get('blockers'):
        raise SystemExit('UI pack has unresolved dependencies; the runtime refuses it')
    ui_sha = sha256(ui_raw)
    assets = {row['asset_id']: row for row in images['assets']}
    icons, unresolved = {}, collections.Counter()
    unresolved_icons = {}
    for icon in images['icons']:
        asset = assets.get(icon['asset_id'])
        if asset is None or asset.get('status') != 'unsupported_csb':
            continue
        member = asset['path']
        reason = None
        if asset.get('asset_type_id') != 101 or not member.startswith(PREFIX + 'icon/') or not member.endswith('.csb'):
            reason = 'not_an_icon_csb_path'
        elif member not in ui['scenes'] or member not in ui['files']:
            reason = 'csb_absent_from_ui_pack'
        else:
            scene = ui['scenes'][member]
            clips = [clip for clip in scene.get('animationList') or [] if clip.get('name') == CLIP]
            if scene.get('_partial_source_scene') or scene.get('_decode_blockers'):
                reason = 'scene_not_whole_or_not_decoded'
            elif scene.get('_source_sha256') != ui['files'][member]['sha256']:
                reason = 'scene_source_identity_mismatch'
            elif len(clips) != 1:
                reason = 'client_normal_clip_not_unique'
        if reason:
            unresolved[reason] += 1
            unresolved_icons[str(icon['id'])] = {'asset_id': icon['asset_id'], 'path': member, 'reason': reason}
            continue
        icons[str(icon['id'])] = {
            'asset_id': icon['asset_id'], 'asset_type_id': 101, 'file_path': member[len(PREFIX):],
            'member': member, 'reviewed_current523_manifest_sha256': ui_sha,
            'current523_scene_sha256': ui['files'][member]['sha256'],
            'clip': CLIP, 'repeat': True, 'original_repeat_declared': True, 'original_policy_confirmed': True,
            'policy_source': POLICY_SOURCE}
    if pack_root is None:
        pack_root = os.path.relpath(ui_pack.resolve(), output.resolve().parent)
    document = {'schema': SELECTION_SCHEMA, 'estimate_missing_repeat': False,
                'packs': [{'root': pack_root, 'manifest_sha256': ui_sha}],
                'document': {'source_icon_scenes': {'schema': SCENES_SCHEMA, 'icons': icons}},
                'client_policy': {'clip': CLIP, 'repeat': True, 'source': POLICY_SOURCE},
                'inputs': {'image_manifest_sha256': sha256(image_raw), 'ui_manifest_sha256': ui_sha},
                'unresolved_icons': unresolved_icons}
    raw = (json.dumps(document, ensure_ascii=False, indent=1, sort_keys=True) + '\n').encode()
    if len(raw) > MAX_BYTES:
        raise SystemExit('selection exceeds the runtime size limit')
    if output.exists():
        raise SystemExit('output selection already exists; existing selections are preserved')
    output.write_bytes(raw)
    references, unbound = collections.Counter(), collections.Counter()
    for table, rows in images.get('consumers', {}).items():
        for row in rows:
            for role, icon_id in row['roles'].items():
                key = str(icon_id)
                if key in icons:
                    references[f'{table}.{role}'] += 1
                elif key in unresolved_icons:
                    unbound[f'{table}.{role}'] += 1
    return {'selection': str(output), 'selection_sha256': sha256(raw), 'ui_manifest_sha256': ui_sha,
            'icons_bound': len(icons), 'icons_unresolved': dict(unresolved),
            'consumer_references_bound': dict(references), 'consumer_references_unresolved': dict(unbound)}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--image-manifest', type=Path, required=True, help='source523 image pack manifest.json')
    parser.add_argument('--ui-pack', type=Path, required=True, help='original UI pack directory')
    parser.add_argument('--output', type=Path, required=True, help='new selection JSON file')
    parser.add_argument('--pack-root', help='root written into the selection (default: relative to --output)')
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if repo in out.parents:
        parser.error('--output must be outside the repository')
    print(json.dumps(build(args.image_manifest, args.ui_pack, args.output, args.pack_root), ensure_ascii=False, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
