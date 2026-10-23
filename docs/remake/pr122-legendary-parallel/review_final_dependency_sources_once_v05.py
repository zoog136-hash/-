#!/usr/bin/env python3
"""One technical review/diagnostic board per newly saved FINAL_DEPENDENCY8 source.

Never inspect original13/71/dependency10/recovery7 corrections, healthy clips or the frozen corpus. A
completed per-source unit is reused without rescanning its PNG. This script
does not decide visual quality, generate images or mutate actor resources.
"""
# Reused immutable review_v03 source SHA256 ee9b4b1e761fb2b1c0e356a764ed185f2ce355642eebb00c559ace99fabe00b8
from __future__ import annotations

import argparse
import collections
import hashlib
import importlib.util
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont

WORK = Path('/workspace/legendary_work')
REPO = Path('/workspace/legendary_repo')
DOCS = Path('docs/remake/pr122-legendary-parallel')
COHORT = DOCS / 'quality-v04'
PLAN = DOCS / 'quality-v02/correction-plan-v06.json'
PLAN_SHA = '044f43ada55205df75cc594f68a4c4901c4703121bef81c291cff538ad41692a'
BASELINE = '6bcd94f5a0868426ac4b5ae0ebffd93916fad1ba'
FROZEN_SHA = 'bce7e7260712a27515627806a88690158f47bf8ddf4cd172dba5b5ba3eee00c6'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(path, expected=None):
    raw = Path(path).read_bytes()
    if expected and sha(raw) != expected:
        raise ValueError('Pinned changed-source metadata SHA mismatch')
    return json.loads(raw), sha(raw)


def write_new(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x') as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write('\n')


def norm(path):
    return str(path).removeprefix('res://')


def board(source, record, entry, output):
    if output.exists():
        return
    # Diagnostic rendering only; raw source/cells remain unmodified on disk.
    with Image.open(source) as image:
        sheet = image.convert('RGBA')
    with Image.open(REPO / norm(record['reference'])) as image:
        reference = image.convert('RGBA')
    width = min(1536, max(1024, sheet.width))
    factor = width / sheet.width
    height = round(sheet.height * factor)
    header = 240
    canvas = Image.new('RGB', (width, height + header), '#555b64')
    draw = ImageDraw.Draw(canvas)
    reference.thumbnail((220, 220))
    canvas.paste(reference, (10, 10), reference)
    title = (f"{entry['correction_candidate_id']} {entry['slot'][0]} {entry['slot'][1]} {entry['slot'][2].upper()}\n"
             f"NEW SOURCE ONLY | {sheet.width}x{sheet.height} | grid {record['source_grid']}\n"
             f"{record['source_sha256']}\n"
             "Catalog identity reference at left; raw generated sheet below.\n"
             "Camera, identity, role and healthy guards: targeted static review; approval0.")
    draw.multiline_text((250, 24), title, fill='white', spacing=12)
    background = Image.new('RGB', (width, height), '#656a73')
    resized = sheet.resize((width, height)) if factor != 1 else sheet
    background.paste(resized, (0, 0), resized)
    canvas.paste(background, (0, header))
    columns, rows = record['source_grid']
    for column in range(1, columns):
        x = round(column * width / columns)
        draw.line((x, header, x, header + height), fill='#f2b658', width=2)
    for row in range(1, rows):
        y = header + round(row * height / rows)
        draw.line((0, y, width, y), fill='#f2b658', width=2)
    sequence = record['source_pose_sequence']
    for pose in sequence:
        if pose.get('source_kind') != 'new':
            continue
        ordinal = pose['new_sheet_cell']
        x = round((ordinal % columns) * width / columns) + 8
        y = header + round((ordinal // columns) * height / rows) + 8
        draw.text((x, y), f"cell{ordinal} / playback phase{pose['phase']}", fill='#ffdc85', stroke_width=1, stroke_fill='black')
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('xb') as handle:
        canvas.save(handle, format='PNG')


def inspect_batch(batch):
    plan, _ = read(WORK / PLAN, PLAN_SHA)
    expected = {x['correction_candidate_id']: x for x in plan['jobs'] if x['state'] == 'READY' and x.get('batch') == batch}
    if not expected:
        raise ValueError('This batch is outside the new FINAL_DEPENDENCY8 cohort')
    receipt_path = Path('/workspace/legendary_delivery_logs') / f'quality-batch{batch}-delivery.json'
    if not receipt_path.exists():
        return {'status': 'WAIT_REMOTE_RECEIPT', 'batch': batch}
    receipt, receipt_sha = read(receipt_path)
    if receipt.get('status') != 'REMOTE_SAVED':
        return {'status': 'WAIT_REMOTE_SAVED', 'batch': batch}
    commit = receipt.get('remote_sha') or receipt.get('commit_sha')
    if not re.fullmatch(r'[0-9a-f]{40}', commit or ''):
        raise ValueError('Require the exact remotely saved commit')
    manifest_path = DOCS / f'quality-v02/batch{batch}-revision-library-v02.json'
    manifest, manifest_sha = read(REPO / manifest_path)
    spec = importlib.util.spec_from_file_location('legendary_original_onepass_algorithm', WORK / DOCS / 'audit_legendary_static_once_v01.py')
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    units = []
    for entry in manifest['revisions']:
        candidate = entry['correction_candidate_id']
        if candidate not in expected:
            raise ValueError('Do not review an old/healthy/non-cohort correction')
        record_path = REPO / norm(entry['record'])
        record, record_sha = read(record_path, entry['record_sha256'])
        if [record['key'], record['direction'], record['role']] != entry['slot']:
            raise ValueError('Changed source actor mismatch')
        output = WORK / COHORT / 'source-technical' / (candidate + '-review-v01.json')
        if output.exists():
            unit, _ = read(output)
            if unit['sha256'] != record['source_sha256'] or unit['record_sha256'] != record_sha:
                raise ValueError('A completed unit is immutable; no source rereview')
        else:
            source = REPO / norm(record['source'])
            if '/quality-v02/' not in source.as_posix():
                raise ValueError('Only newly saved correction source PNGs are in scope')
            parsed = audit.parse_frames(REPO / norm(record['output_spriteframes']))
            frames = [(i, frame) for i, frame in enumerate(parsed['frames'])
                      if norm(frame['source']) == norm(record['source'])]
            unit = audit.scan_source(source, frames, record)
            if unit['sha256'] != record['source_sha256']:
                raise ValueError('Changed source PNG SHA differs from saved record')
            unit.update(source=norm(record['source']), authored_slot=entry['slot'],
                        dependents=[{'slot': entry['slot'], 'phase': phase, 'region': frame['region']} for phase, frame in frames],
                        record=entry['record'], record_sha256=record_sha,
                        SpriteFrames=entry['SpriteFrames'], SpriteFrames_sha256=entry['SpriteFrames_sha256'],
                        correction_candidate_id=candidate, previous_source=record['previous_source'],
                        previous_source_sha256=record['previous_source_sha256'],
                        batch=batch, remote_commit=commit, remote_receipt_sha256=receipt_sha,
                        source_pose_phase_unit='Author clip playback phase, not sheet-cell ordinal',
                        baseline_sha=BASELINE, frozen_review_sha256=FROZEN_SHA,
                        review_scope='ONLY_NEW_FINAL_DEPENDENCY8_CHANGED_SOURCE_ONCE', final_approved=0)
            write_new(output, unit)
        board_path = WORK / COHORT / 'visual-boards' / (candidate + '-source-v01.png')
        board(REPO / unit['source'], record, entry, board_path)
        units.append(unit)
    index_path = WORK / COHORT / f'batch{batch}-changed-source-technical-index-v01.json'
    if not index_path.exists():
        write_new(index_path, {'schema': 'legendary-targeted-technical-index-v4', 'baseline_sha': BASELINE,
            'frozen_review_sha256': FROZEN_SHA, 'cohort_plan_sha256': PLAN_SHA,
            'batch': batch, 'changed_sources_reviewed': len(units), 'additional_whole_reviews': 0,
            'source_findings': units, 'manifest': 'res://' + str(manifest_path), 'manifest_sha256': manifest_sha,
            'remote_commit': commit, 'remote_receipt_sha256': receipt_sha,
            'quality_status': 'HOLD', 'final_approved': 0})
    return {'status': 'NEW_SOURCE_TECHNICAL_UNITS_READY', 'batch': batch, 'new_sources': len(units),
            'candidates': [u['correction_candidate_id'] for u in units],
            'finding_counts': dict(collections.Counter(f['code'] for u in units for f in u['findings'])),
            'index': str(index_path), 'index_sha256': sha(index_path.read_bytes()),
            'visual_review_status': 'AWAITING_ONE_CHANGED_SOURCE_VISUAL_REVIEW', 'whole_corpus_rereviews': 0}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=int, required=True)
    args = parser.parse_args()
    plans={313:'quality-v02/correction-plan-v09.json',314:'quality-v02/correction-plan-v10.json'}
    pins={313:'32e7779799e977d56047e4a7fc27901ae5fa5444983418194e3129358e1f74c9',314:'1d6ac9e1f3a98ee22d17dcdc3eea772573a064e940a073dd6d12ada7da2df307'}
    if args.batch not in plans:raise ValueError('Only newly saved final dependency8')
    PLAN=DOCS/plans[args.batch]; PLAN_SHA=pins[args.batch]
    print(json.dumps(inspect_batch(args.batch), ensure_ascii=False))
