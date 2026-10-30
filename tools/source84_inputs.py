#!/usr/bin/env python3
"""Rebuild source84 from the existing eight Space ZIPs (or their split parts).
No network, Library credentials, new archive or artwork conversion is needed.
"""
import argparse
import bisect
import gzip
import hashlib
import io
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import zipfile
from source84_delivery import ROOT, digest, inventory, verify
from source_map_pack import build, LINKAGE_SHA
from install_source_map_local_pack import install as install_corrections

INPUTS = ROOT / 'data/maps/source84_input_archives.json'
EQUAL = ROOT / 'data/maps/source84_equal_collision_index.json'


class JoinedFile(io.RawIOBase):
    """Seek a split ZIP without creating a second 267 MB joined copy."""
    def __init__(self, paths):
        self.handles = [p.open('rb') for p in paths]
        self.offsets = [0]
        for p in paths: self.offsets.append(self.offsets[-1] + p.stat().st_size)
        self.position = 0

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        new = offset if whence == 0 else (self.position if whence == 1 else self.offsets[-1]) + offset
        if new < 0: raise ValueError('Negative ZIP seek')
        self.position = new
        return new

    def read(self, size=-1):
        remaining = self.offsets[-1] - self.position
        size = max(0, remaining if size < 0 else min(size, remaining))
        chunks = []
        while size:
            i = bisect.bisect_right(self.offsets, self.position) - 1
            take = min(size, self.offsets[i + 1] - self.position)
            self.handles[i].seek(self.position - self.offsets[i])
            data = self.handles[i].read(take)
            if len(data) != take: raise ValueError('Truncated ZIP part')
            chunks.append(data); self.position += take; size -= take
        return b''.join(chunks)

    def close(self):
        for handle in self.handles: handle.close()
        super().close()


def ingest(inputs, workspace, number):
    row = json.loads(INPUTS.read_text())['archives'][number - 1]
    full = inputs / row['filename']
    paths = [full] if full.is_file() else [inputs / p['filename'] for p in row['parts']]
    for path in paths:
        if not path.is_file() or path.is_symlink(): raise ValueError('Missing regular input: ' + str(path))
    if paths != [full]:
        for path, part in zip(paths, row['parts']):
            if path.stat().st_size != part['bytes'] or digest(path) != part['sha256']:
                raise ValueError('Split part SHA/size mismatch: ' + path.name)
    spec = inventory(); seen = set()
    with JoinedFile(paths) as stream:
        h = hashlib.sha256()
        while block := stream.read(1024 * 1024): h.update(block)
        if stream.offsets[-1] != row['bytes'] or h.hexdigest() != row['sha256']:
            raise ValueError('Original ZIP size/SHA mismatch: ' + row['filename'])
        stream.seek(0)
        with zipfile.ZipFile(stream) as z:
            names = z.namelist()
            if len(names) != len(set(names)): raise ValueError('Duplicate ZIP names')
            for name in names:
                if name not in spec['files'] or not name.startswith('chunks/'):
                    raise ValueError('Unapproved archive path: ' + name)
                item = spec['files'][name]
                if z.getinfo(name).file_size != item['bytes']: raise ValueError('Image size differs')
                data = z.read(name)  # Reads to EOF; ZIP CRC is checked here.
                if hashlib.sha256(data).hexdigest() != item['sha256']: raise ValueError('Image SHA differs')
                out = workspace / 'art' / name
                out.parent.mkdir(parents=True, exist_ok=True)
                if out.is_symlink(): raise ValueError('Symlink in staged artwork')
                if out.exists():
                    if digest(out) != item['sha256']: raise ValueError('Existing staged image changed')
                else:
                    with out.open('xb') as dest: dest.write(data)
                seen.add(name)
    if len(seen) != row['chunks']: raise ValueError('Archive chunk count differs')
    receipt = workspace / 'receipts' / ('%02d.json' % number)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps({'sha256': row['sha256'], 'chunks': sorted(seen)}) + '\n')
    return {'archive': number, 'chunks': len(seen), 'sha256': row['sha256']}


def finish(workspace, linkage, project):
    target = project / 'external_map_packs/source84_v3'
    spec = inventory()
    if target.exists(): return verify(target, spec)
    rows = json.loads(INPUTS.read_text())['archives']; seen = set()
    for row in rows:
        receipt = json.loads((workspace / 'receipts' / ('%02d.json' % row['number'])).read_text())
        if receipt['sha256'] != row['sha256'] or len(receipt['chunks']) != row['chunks']:
            raise ValueError('Incomplete verified archive receipt')
        if seen.intersection(receipt['chunks']): raise ValueError('Overlapping input chunks')
        seen.update(receipt['chunks'])
    if seen != {p for p in spec['files'] if p.startswith('chunks/')}:
        raise ValueError('Eight archives do not cover the pinned 1920 chunks')
    if digest(linkage) != LINKAGE_SHA: raise ValueError('Linkage v3 ZIP SHA differs')
    # All image bytes and dimensions are independently checked by the original
    # builder. Hardlinks only join its temporary staging directories, never the
    # recipient's original ZIPs or another installed pack.
    assembled = workspace / 'assembled'
    build(linkage, workspace / 'art', assembled, link_assets=True)
    equal_receipt = json.loads((ROOT / 'data/maps/source_map_equal_collision_pack.json').read_text())
    if digest(EQUAL) != equal_receipt['index_sha256']: raise ValueError('Pinned equality index changed')
    equal = json.loads(EQUAL.read_text()); destination = assembled / 'equal-collision-v1'
    (destination / 'grids').mkdir(parents=True)
    with zipfile.ZipFile(linkage) as z:
        for sid, grid in equal['maps'].items():
            packed = z.read('map_source3_links/collision/grids/351/' + sid + '.u8.gz')
            if hashlib.sha256(packed).hexdigest() != grid['sha256'] or hashlib.sha256(gzip.decompress(packed)).hexdigest() != grid['raw_sha256']:
                raise ValueError('Equality collision grid changed: ' + sid)
            (destination / grid['file']).write_bytes(packed)
    shutil.copyfile(EQUAL, destination / 'index.json')
    install_corrections(ROOT / 'external_map_packs/source84_local_v1', assembled)
    result = verify(assembled, spec)
    target.parent.mkdir(parents=True, exist_ok=True)
    assembled.rename(target)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    p = sub.add_parser('ingest'); p.add_argument('--inputs', type=Path, required=True)
    p.add_argument('--number', type=int, choices=range(1, 9), required=True)
    p.add_argument('--workspace', type=Path, required=True)
    for action in ['finish', 'rebuild']:
        p = sub.add_parser(action); p.add_argument('--linkage', type=Path, required=True)
        p.add_argument('--project', type=Path, required=True)
        p.add_argument('--inputs' if action == 'rebuild' else '--workspace', type=Path, required=True)
    args = parser.parse_args()
    if args.action != 'ingest' and importlib.util.find_spec('PIL') is None:
        parser.error('Pillow is required to verify source WebP dimensions; install it in this Python environment first')
    if args.action == 'ingest': result = ingest(args.inputs, args.workspace, args.number)
    elif args.action == 'finish': result = finish(args.workspace, args.linkage, args.project)
    else:
        parent = args.project / 'external_map_packs'; parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.source84-inputs-', dir=parent) as temp:
            work = Path(temp)
            for number in range(1, 9): print(json.dumps(ingest(args.inputs, work, number)), flush=True)
            result = finish(work, args.linkage, args.project)
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__': main()
