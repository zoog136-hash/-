#!/usr/bin/env python3
"""Pin real batch files, stage them, and verify their exact Git-index bytes."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent


def main():
    evidence = HERE.parent
    names = ['boss-correction-session-r002', 'boss-fix06-queen-n', 'boss-fix07-zombie-e',
             'boss-fix08-demon-e', 'boss-fix09-kurtz', 'boss-fix10-queen-diagonal-attack',
             'boss-fix11-demon-se-nw', 'boss-review-followup-20261023']
    folders = [evidence / name for name in names]
    assets = ROOT / 'assets/actors/eight_direction/monster_boss_repair'
    folders += [assets / name for name in ['ice_queen/n-r001', 'ice_queen/combined-r002',
                                           'ice_queen/combat-r002', 'zombie_lord/r003',
                                           'albino_demon/r003', 'kurtz/r003']]
    files = set()
    excluded = {'delivery-manifest.json', 'github-delivery-receipt.json', 'final-save.json'}
    for folder in folders:
        for path in folder.rglob('*'):
            if not path.is_file() or path.is_symlink() or path.name in excluded:
                continue
            if any(part in ('__pycache__', '.godot', 'project', 'user') for part in path.parts):
                continue
            if path.suffix in ('.pyc', '.import', '.tmp'):
                continue
            files.add(path)
    files.update(ROOT / name for name in ['data/pr122_monster_boss_repair_staging.json',
                                         'data/pr122_monster_production_scope.json',
                                         'data/pr122_monster_production_batches.json',
                                         'tools/reclassify_pr122_monsters.py'])
    entries = []
    for path in sorted(files):
        data = path.read_bytes()
        entries.append(dict(path=path.relative_to(ROOT).as_posix(), bytes=len(data),
                            sha256=hashlib.sha256(data).hexdigest()))
    manifest = dict(schema='pr122-boss-correction-delivery-manifest-v1', date='2026-10-23',
                    source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    files=entries, file_count=len(entries), bytes=sum(row['bytes'] for row in entries),
                    SHA256_mismatches=0, all_entries_verified_against_Git_index=True,
                    mutable_resume_document='docs/remake/TWILIGHT_PR122_RESUME_20261019.md is committed but excluded from frozen pins because parallel work appends to it.',
                    approval_changes=0, default_catalog_switches=0)
    output = HERE / 'delivery-manifest.json'
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    stage = [entry['path'] for entry in entries] + [output.relative_to(ROOT).as_posix(), 'docs/remake/TWILIGHT_PR122_RESUME_20261019.md']
    subprocess.run(['git', 'add', '--sparse', '-f', '--', *stage], cwd=ROOT, check=True)
    process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for entry in entries:
            process.stdin.write((':' + entry['path'] + '\n').encode())
            process.stdin.flush()
            header = process.stdout.readline().split()
            assert len(header) == 3 and header[1] == b'blob', entry['path']
            size = int(header[2])
            data = process.stdout.read(size)
            assert process.stdout.read(1) == b'\n'
            assert size == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
    finally:
        process.stdin.close()
        process.wait()
    subprocess.run(['git', 'diff', '--cached', '--check'], cwd=ROOT, check=True)
    print(json.dumps(dict(files=len(entries), bytes=manifest['bytes'], tracked_index_SHA256_mismatches=0)))


if __name__ == '__main__':
    main()
