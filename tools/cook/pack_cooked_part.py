#!/usr/bin/env python3
"""Pack cook outputs into the fewest cooked actor pack parts (ZIP, each <= 1.9 GB).

Input: one or more cook --out directories (shard outputs, each holding
<tag>/actors/*.twca, shard 0 also <tag>/effects/effect_index.bin).
Output: twilight523-cooked-<n>of<N>.zip, read by scripts/boot/source523_pack.gd
like pack parts:
  source523/source523_part.json   first entry: schema, pack_id (cooked id),
                                  part, parts, cooked=true, format, members
  source523/cooked/<tag>/...
Members are stored (actor files are already zstd compressed); files are
distributed largest first into the fewest parts under the limit. Prints one
JSON line per part (file, bytes, sha256) for the pin table.
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
OVERHEAD = 200  # zip headers per member, generous


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cooked', type=Path, action='append', required=True)
    parser.add_argument('--format', required=True)
    parser.add_argument('--cooked-id', required=True)
    parser.add_argument('--output', type=Path, required=True, help='directory for the parts')
    parser.add_argument('--extra', type=Path, action='append', default=[], help='small file stored in part 1 under source523/cooked/')
    parser.add_argument('--limit', type=int, default=LIMIT)
    args = parser.parse_args()
    files = {}
    for root in args.cooked:
        for path in sorted(p for p in root.rglob('*') if p.is_file() and not p.name.startswith('report-')):
            rel = 'cooked/' + path.relative_to(root).as_posix()
            if rel in files:
                if files[rel].read_bytes() != path.read_bytes():
                    raise SystemExit('two shards wrote different ' + rel)
                continue
            files[rel] = path
    order = sorted(files, key=lambda r: -files[r].stat().st_size)
    bins = []
    for rel in order:
        size = files[rel].stat().st_size + OVERHEAD + len(rel)
        for b in bins:
            if b['bytes'] + size <= args.limit:
                b['members'].append(rel)
                b['bytes'] += size
                break
        else:
            bins.append({'members': [rel], 'bytes': size + 4096})
    parts = len(bins)
    args.output.mkdir(parents=True, exist_ok=True)
    for number, b in enumerate(bins, 1):
        members = sorted(b['members'])
        extras = [('cooked/' + e.name, e) for e in args.extra] if number == 1 else []
        listing = [[m, files[m].stat().st_size] for m in members] + [[m, p.stat().st_size] for m, p in extras]
        index = {'schema': PART_SCHEMA, 'pack_id': args.cooked_id, 'part': number, 'parts': parts,
                 'cooked': True, 'format': args.format, 'members': listing}
        out = args.output / f'twilight523-cooked-{number}of{parts}.zip'
        with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
            archive.writestr('source523/source523_part.json', json.dumps(index, separators=(',', ':')))
            for m in members:
                archive.write(files[m], 'source523/' + m)
            for m, p in extras:
                archive.write(p, 'source523/' + m)
        digest = hashlib.sha256()
        with out.open('rb') as stream:
            for block in iter(lambda: stream.read(1 << 20), b''):
                digest.update(block)
        print(json.dumps({'file': out.name, 'part': number, 'parts': parts, 'bytes': out.stat().st_size,
                          'sha256': digest.hexdigest(), 'members': len(listing)}))


if __name__ == '__main__':
    main()
