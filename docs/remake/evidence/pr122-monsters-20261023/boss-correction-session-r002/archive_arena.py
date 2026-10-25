#!/usr/bin/env python3
"""Preserve real-speed rendered QA outputs without ephemeral project symlinks."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runtime_output', type=Path)
    parser.add_argument('--name', default='arena-r003')
    args = parser.parse_args()
    source = args.runtime_output.resolve()
    report = json.loads((source / 'report.json').read_text())
    process = json.loads((source / 'process.json').read_text())
    assert process['returncode'] == 0
    assert report['capture_enabled'] and report['speed_scale'] == 1.0 and report['camera_zoom'] == 1.0
    target = HERE / args.name
    target.mkdir(exist_ok=False)
    files = []
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if relative.parts[0] in ('project', 'user') or path.is_symlink() or not path.is_file():
            continue
        output = target / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, output)
        data = output.read_bytes()
        files.append(dict(path=output.relative_to(ROOT).as_posix(), bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    cases = []
    for case in report['cases']:
        slug = Path(case['samples_file']).parent.name
        samples = json.loads((target / slug / 'samples.json').read_text())
        assert all(min(row['source_texture_size']) > 0 for row in samples), case['key']
        assert all(min(row['source_region'][2:]) > 0 for row in samples), case['key']
        cases.append(dict(key=case['key'], profile=case['profile'],
                          requested_segments=len(case['segments']),
                          played_segments=sum(row['status'] == 'PLAYED_AT_GAME_SCALE' for row in case['segments']),
                          not_authored_segments=sum(row['status'] != 'PLAYED_AT_GAME_SCALE' for row in case['segments']),
                          tick_samples=len(samples), viewport_captures=case['capture_count'],
                          actual_Monster_reference_speed=case['actual_Monster_reference_speed'],
                          pixel_scale=case['pixel_scale'],
                          max_virtual_canvas_foot_error=max(row['virtual_canvas_foot_error'] for row in samples),
                          virtual_canvas_anchor_is_not_anatomical_contact_approval=True))
    value = dict(schema='pr122-boss-correction-arena-receipt-v1', engine=report['engine'],
                 renderer=report['video_adapter'], speed_scale=1.0, camera_zoom=1.0,
                 actual_Main=False, original_ActorMotion=True, cases=cases, files=files,
                 captures=sum(row['viewport_captures'] for row in cases),
                 new_approvals=0, process=process)
    (target / 'receipt.json').write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(cases=cases, captures=value['captures'], files=len(files)), ensure_ascii=False))


if __name__ == '__main__':
    main()
