#!/usr/bin/env python3
"""Build a private UI dependency closure from an explicitly verified source index.

No archive discovery, network access, replacement art or gameplay rules. A pack
with unresolved references is an inspection result; the runtime must refuse it.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import zipfile
from xml.parsers.expat import ExpatError

from read_source_csb import Reader


def source_path(value):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        raise ValueError('Invalid source path')
    parts = PurePosixPath(value)
    if parts.is_absolute() or any(p in ('', '.', '..') for p in value.split('/')):
        raise ValueError('Unsafe source path: ' + value)
    return value if value.startswith('UI/') else 'UI/' + value


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def particle_dictionary(raw):
    """Match Cocos 3.6's first complete plist, preserving the original bytes.

    Its pinned v3-deps-47 TinyXML2 accepts some source files with trailing
    non-document data. A complete, strictly parseable root remains required.
    Atlas parsing deliberately remains unchanged.
    """
    try:
        value = plistlib.loads(raw)
        mode = 'strict_plist'
    except ExpatError:
        end = raw.find(b'</plist>')
        if end < 0:
            raise
        value = plistlib.loads(raw[:end + len(b'</plist>')])
        mode = 'cocos36_first_complete_plist'
    if not isinstance(value, dict):
        raise ValueError('Particle plist must contain a dictionary')
    return value, mode


class Builder:
    def __init__(self, source_index):
        self.index = source_index
        self.files = {}
        self.scenes = {}
        self.atlases = {}
        self.source_compatibility = []
        self.blockers = []
        self.active = set()

    def read(self, member):
        member = source_path(member)
        if member in self.files:
            return self.files[member]['raw']
        entry = self.index.get(member)
        if entry is None:
            self.blockers.append({'member': member, 'reason': 'source_not_received'})
            return None
        origin = Path(entry['origin'])
        if origin.suffix.lower() == '.dat':
            with zipfile.ZipFile(origin) as archive:
                if archive.namelist().count(member) != 1:
                    raise ValueError('Ambiguous original member: ' + member)
                raw = archive.read(member)
        else:
            raw = origin.read_bytes()
        if digest(raw) != entry['sha256']:
            raise ValueError('Original source hash mismatch: ' + member)
        self.files[member] = {'raw': raw, 'sha256': digest(raw), 'bytes': len(raw)}
        return raw

    def resource(self, ref, owner):
        if not ref.get('path'):
            return
        if ref.get('plistFile'):
            plist = source_path(ref['plistFile'])
            atlas = self.atlas(plist)
            if atlas is not None and ref['path'] not in atlas['frames']:
                self.blockers.append({'scene': owner, 'member': plist, 'frame': ref['path'], 'reason': 'exact_frame_absent'})
        elif ref.get('resourceType', 0) == 0:
            path = source_path(ref['path'])
            raw = self.read(path)
            if raw is not None and path.endswith('.plist'):
                # Particle PLISTs must retain their texture dependencies too.
                try:
                    particle, mode = particle_dictionary(raw)
                    if mode != 'strict_plist':
                        self.source_compatibility.append({'member': path, 'sha256': digest(raw), 'mode': mode})
                    texture = particle.get('textureFileName')
                    if texture and not particle.get('textureImageData'):
                        page = str(PurePosixPath(path).parent / texture)
                        self.read(page)
                except (ValueError, plistlib.InvalidFileException, ExpatError) as error:
                    self.blockers.append({'member': path, 'reason': 'unreadable_particle_plist', 'detail': str(error)})
        else:
            self.blockers.append({'scene': owner, 'reference': ref, 'reason': 'resource_type_without_plist_unverified'})

    def atlas(self, member):
        if member in self.atlases:
            return self.atlases[member]
        raw = self.read(member)
        if raw is None:
            return None
        try:
            data = plistlib.loads(raw)
        except (ValueError, plistlib.InvalidFileException, ExpatError) as error:
            self.blockers.append({'member': member, 'reason': 'unreadable_atlas', 'detail': str(error)})
            return None
        meta = data.get('metadata', {})
        if meta.get('format') != 2 or not meta.get('textureFileName'):
            self.blockers.append({'member': member, 'reason': 'unsupported_atlas_metadata'})
            return None
        page = source_path(str(PurePosixPath(member).parent / meta['textureFileName']))
        pixels = self.read(page)
        frames = {}
        for key, spec in data['frames'].items():
            numbers = lambda name: [int(x) for x in re.findall(r'-?\d+', spec[name])]
            frame = {'rect': numbers('frame'), 'source_rect': numbers('sourceColorRect'),
                     'source_size': numbers('sourceSize'), 'rotated': spec['rotated']}
            if [len(frame[x]) for x in ('rect', 'source_rect', 'source_size')] != [4, 4, 2]:
                raise ValueError('Invalid original frame geometry: ' + member + ':' + key)
            frames[key] = frame
        self.atlases[member] = {'page': page, 'page_sha256': digest(pixels) if pixels is not None else '',
                               'plist_sha256': digest(raw), 'frames': frames}
        return self.atlases[member]

    def scene(self, member):
        member = source_path(member)
        if member in self.active:
            self.blockers.append({'member': member, 'reason': 'cyclic_project_node'})
            return
        if member in self.scenes:
            return
        raw = self.read(member)
        if raw is None:
            return
        self.active.add(member)
        tree = Reader(raw).parse()
        self.scenes[member] = tree
        self.blockers.extend({'scene': member, 'reason': 'unsupported_source_field', 'detail': b}
                             for b in tree['_decode_blockers'])

        def walk(value):
            if isinstance(value, dict):
                if value.get('_type') == 'ResourceData':
                    self.resource(value, member)
                if value.get('_type') == 'ProjectNodeOptions' and value.get('fileName'):
                    self.scene(value['fileName'])
                for item in value.values():
                    walk(item)
            elif isinstance(value, list):
                for item in value:
                    walk(item)
        walk(tree)
        self.active.remove(member)

    def build(self, entries, output):
        output = Path(output)
        if output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
            raise ValueError('Original UI packs must stay outside the public checkout')
        if output.exists():
            raise ValueError('Use a new private output directory; existing packs are preserved')
        for member in entries:
            self.scene(member)
        blockers = list({json.dumps(b, sort_keys=True): b for b in self.blockers}.values())
        manifest = {'schema': 'twilight-original-ui-v1', 'entries': entries,
                    'scenes': self.scenes, 'atlases': self.atlases,
                    'files': {k: {n: v for n, v in item.items() if n != 'raw'} for k, item in self.files.items()},
                    'blockers': blockers, 'runtime_verified': False}
        if self.source_compatibility:
            manifest['source_compatibility'] = list({json.dumps(x, sort_keys=True): x for x in self.source_compatibility}.values())
        output.mkdir(parents=True)
        for member, item in self.files.items():
            target = output / 'originals' / member
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(item['raw'])
        raw = (json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
        (output / 'original_ui.json').write_bytes(raw)
        receipt = {'manifest_sha256': digest(raw), 'scenes': len(self.scenes), 'files': len(self.files),
                   'blockers': len(blockers), 'status': 'DEPENDENCIES_RESOLVED_NOT_RENDERED' if not blockers else 'BLOCKED'}
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-index', type=Path, required=True)
    parser.add_argument('--scene', action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        parser.error('Original UI packs must stay outside the public checkout')
    index = json.loads(args.source_index.read_text())
    print(json.dumps(Builder(index.get('source_files', index)).build(args.scene, args.output)))


if __name__ == '__main__':
    main()
