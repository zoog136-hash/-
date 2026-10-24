#!/usr/bin/env python3
"""Reconcile recorded completions with real tracked bytes; never author assets.

The historical count describes coverage, including shared bodies. This audit
does not upgrade individual visual, CI, APK, or device approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def audit(root):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args])

    tracked = {}
    for entry in git('ls-files', '--stage', '-z').split(b'\0'):
        if not entry:
            continue
        meta, path = entry.split(b'\t', 1)
        mode, oid, stage = meta.decode().split()
        if stage != '0':
            raise ValueError('Resolve merge conflicts before auditing tracked bytes')
        tracked[path.decode()] = oid

    checked = {}

    def verify(resource):
        relative = resource.removeprefix('res://')
        path = (root / relative).resolve()
        if not path.is_relative_to(root) or path == root:
            raise ValueError('Resource path escapes checkout: ' + resource)
        if relative in checked:
            return checked[relative]
        row = {'path': relative, 'tracked': relative in tracked, 'present': path.is_file()}
        if row['present']:
            data = path.read_bytes()
            row.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            row['git_blob_matches'] = (
                hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                == tracked.get(relative))
        else:
            row['git_blob_matches'] = False
        checked[relative] = row
        return row

    directory = root / 'docs/remake/evidence/pr100-direction-fix/original-based/coverage'
    coverage = json.loads((directory / 'coverage.json').read_text())
    profiles = json.loads((root / 'data/combat_animation_profiles.json').read_text())['profiles']
    recorded = [i for i in coverage['identities'] if i['native_connected']
                and i['group'] in {'hero_plus', 'normal_monster', 'boss'}]
    if len(recorded) != 392:
        raise ValueError('Unexpected historical completed roster: ' + str(len(recorded)))
    identities, missing, modified = [], [], []
    for identity in recorded:
        key, original = identity['key'], identity['frames_path']
        current = profiles.get(key, {}).get('frames_path', '')
        row = {'key': key, 'name': identity['name'], 'group': identity['group'],
               'recorded_frames_path': original, 'current_frames_path': current}
        if current != original:
            modified.append(key)
        required = {original}
        if current:
            required.add(current)
        for resource in list(required):
            frames = root / resource.removeprefix('res://')
            if frames.is_file():
                required.update(re.findall(r'path="(res://[^\"]+)"', frames.read_text()))
                provenance = frames.parent / 'provenance.json'
                if provenance.is_file():
                    required.add(provenance.relative_to(root).as_posix())
        errors = []
        for resource in sorted(required):
            evidence = verify(resource)
            if not evidence['tracked'] or not evidence['present'] or not evidence['git_blob_matches']:
                errors.append(evidence['path'])
        if not current:
            errors.append('missing current profile binding')
        row.update(required_paths=sorted(required), missing_or_untracked_or_modified_bytes=errors,
                   status='RECORDED_COMPLETE_BYTES_VERIFIED' if not errors else 'RECORDED_COMPLETE_NOT_DELIVERED')
        identities.append(row)
        if errors:
            missing.append(row)

    canonical = []
    for entry in coverage['recorded_main_evidence']:
        relative = (directory / entry['path']).resolve().relative_to(root).as_posix()
        result = verify(relative)
        canonical.append({'path': relative, 'expected_sha256': entry['sha256'],
                          'sha_matches': result.get('sha256') == entry['sha256'], **result})
    connected = [i for i in coverage['identities']
                 if i['group'] in {'hero_plus', 'normal_monster', 'boss'}
                 and profiles.get(i['key'], {}).get('layout') == 'directional8'
                 and profiles.get(i['key'], {}).get('frames_path')]
    return {'schema': 1, 'head': git('rev-parse', 'HEAD').decode().strip(),
            'index_tree': git('write-tree').decode().strip(),
            'scope': 'Tracked byte delivery only; historical shared-body coverage is not a new per-identity visual approval',
            'recorded_completed': len(recorded), 'runtime_connected': len(connected),
            'recorded_complete_but_missing_from_Git': missing,
            'profile_binding_changed_since_recorded_completion': modified,
            'verified_recorded_completed_bytes': len(recorded) - len(missing),
            'canonical_Main_reports': canonical,
            'canonical_report_errors': [r for r in canonical if not r['sha_matches']
                                        or not r['git_blob_matches'] or not r['tracked']],
            'identities': identities, 'files': list(checked.values()),
            'completed_added': 0, 'new_visual_approval': False, 'Android_real_device': 'NOT_RUN'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Use a new report path; earlier evidence is immutable')
    report = audit(args.root.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['head', 'recorded_completed', 'runtime_connected',
                     'verified_recorded_completed_bytes', 'profile_binding_changed_since_recorded_completion',
                     'recorded_complete_but_missing_from_Git', 'canonical_report_errors']}, ensure_ascii=False))
    raise SystemExit(bool(report['recorded_complete_but_missing_from_Git'] or report['canonical_report_errors']))
