#!/usr/bin/env python3
"""Pack one cook shard's output into one cooked actor pack part (ZIP).

Layout (read by scripts/boot/source523_pack.gd like a pack part):
  source523/source523_part.json   first entry: schema, pack_id (cooked id),
                                  part, parts, cooked=true, format, members
  source523/cooked/<tag>/actors/*.twca

Members are stored (the actor files are already zstd compressed). Prints a
JSON line with the part's file name, bytes and SHA-256 for the pin table.
Runs in the private Twm cook workflow; the output never enters the game repo.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

PART_SCHEMA = 'twilight-client523-resource-pack-part-v1'
LIMIT = 1_900_000_000


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cooked', type=Path, required=True, help='cook --out directory of this shard')
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--cooked-id', required=True)
    parser.add_argument('--part', type=int, required=True)
    parser.add_argument('--parts', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    fmt = report['format']
    files = sorted(p for p in args.cooked.rglob('*.twca'))
    members = []
    for path in files:
        rel = path.relative_to(args.cooked).as_posix()
        members.append(['cooked/' + rel, path.stat().st_size])
    total = sum(size for _, size in members)
    if total > LIMIT:
        raise SystemExit(f'part {args.part} would hold {total} bytes > {LIMIT}; rerun with more shards')
    index = {'schema': PART_SCHEMA, 'pack_id': args.cooked_id, 'part': args.part, 'parts': args.parts,
             'cooked': True, 'format': fmt, 'members': members}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, 'w', compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        archive.writestr('source523/source523_part.json', json.dumps(index, separators=(',', ':')))
        for path, (member, _) in zip(files, members):
            archive.write(path, 'source523/' + member)
    digest = hashlib.sha256()
    with args.output.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    print(json.dumps({'file': args.output.name, 'part': args.part, 'parts': args.parts, 'bytes': args.output.stat().st_size,
                      'sha256': digest.hexdigest(), 'members': len(members), 'member_bytes': total}))


if __name__ == '__main__':
    main()
