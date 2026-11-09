#!/usr/bin/env python3
"""Build a private UI dependency closure from an explicitly verified source index.

No archive discovery, network access, replacement art or gameplay rules. A pack
with unresolved references is an inspection result; the runtime must refuse it.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import os
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
    def __init__(self, source_index, link_originals=False):
        self.index = source_index
        # Hardlink unchanged originals from plain-file origins (for example
        # client523_ui_inputs.py members) instead of copying their bytes.
        self.link_originals = link_originals
        self.files = {}
        self.scenes = {}
        self.layout_sources = {}
        self.node_scopes = {}
        self.external_texture_nodes = {}
        self.atlases = {}
        self.source_compatibility = []
        self.blockers = []
        self.active = set()
        self.touched = set()
        self._trees = {}

    def _parse(self, raw):
        # Identical original bytes decode to the same read-only tree.
        key = digest(raw)
        if key not in self._trees:
            self._trees[key] = Reader(raw).parse()
        return self._trees[key]

    def read(self, member):
        member = source_path(member)
        if member in self.files:
            self.touched.add(member)
            item = self.files[member]
            return item['raw'] if item['raw'] is not None else item['origin'].read_bytes()
        entry = self.index.get(member)
        if entry is None:
            self.blockers.append({'member': member, 'reason': 'source_not_received'})
            return None
        origin = Path(entry['origin'])
        linked = False
        if origin.suffix.lower() == '.dat':
            with zipfile.ZipFile(origin) as archive:
                if archive.namelist().count(member) != 1:
                    raise ValueError('Ambiguous original member: ' + member)
                raw = archive.read(member)
        else:
            raw = origin.read_bytes()
            linked = self.link_originals
        if digest(raw) != entry['sha256']:
            raise ValueError('Original source hash mismatch: ' + member)
        self.files[member] = {'raw': None if linked else raw, 'sha256': digest(raw), 'bytes': len(raw)}
        if linked:
            self.files[member]['origin'] = origin
        self.touched.add(member)
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
            if raw is not None and path.endswith('.fnt'):
                self.bitmap_font_pages(raw, path)
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

    def bitmap_font_pages(self, raw, member):
        # BMFont page images are external dependencies of the source .fnt.
        # Only the actually observed text format is accepted here.
        try:
            text = raw.decode('utf-8-sig')
            common = next(line for line in text.splitlines() if line.startswith('common '))
            expected = int(re.search(r'\bpages=(\d+)\b', common).group(1))
            pages = [re.fullmatch(r'page\s+id=(\d+)\s+file="([^"]+)"\s*', line)
                     for line in text.splitlines() if line.startswith('page ')]
            if expected < 1 or len(pages) != expected or any(p is None for p in pages):
                raise ValueError('Invalid source font page count/record')
            if {int(p.group(1)) for p in pages} != set(range(expected)):
                raise ValueError('Invalid source font page identities')
            for page in pages:
                self.read(source_path(str(PurePosixPath(member).parent / page.group(2))))
        except (UnicodeError, StopIteration, AttributeError, ValueError) as error:
            self.blockers.append({'member': member, 'reason': 'unsupported_bitmap_font_dependencies', 'detail': str(error)})

    def atlas(self, member):
        if member in self.atlases:
            # Shared caches still record this closure's plist/page use and
            # an absent page as its own blocker.
            self.read(member)
            self.read(self.atlases[member]['page'])
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
        tree = self._parse(raw)
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

    def layout_source(self, member):
        """Keep original parent geometry without activating its other screens.

        This is not an entry scene or a resolved child closure. Consumers use
        it only to place the independently packaged original components.
        """
        member = source_path(member)
        raw = self.read(member)
        if raw is None:
            return
        tree = Reader(raw).parse()
        if tree['_decode_blockers']:
            self.blockers.append({'member': member, 'reason': 'layout_source_fields_unsupported'})
            return
        self.layout_sources[member] = tree

    def node_scene(self, member, offsets):
        """Package an explicit partial original-node scope, never a full UI.

        Keep the raw original and full read-only metadata separately. Only
        selected nodes and their ancestors supply this scope's dependencies.
        """
        member = source_path(member)
        if not offsets or len(set(offsets)) != len(offsets):
            raise ValueError('Node scope requires distinct original offsets')
        self.layout_source(member)
        tree = self.layout_sources.get(member)
        if tree is None:
            return
        requested = set(offsets)
        found = set()
        tags = set()

        def prune(node):
            children = [kept for child in node.get('children', [])
                        if (kept := prune(child)) is not None]
            offset = node['_offset']
            if offset not in requested and not children:
                return None
            if offset in requested:
                found.add(offset)
            kept = copy.deepcopy(node)
            kept['children'] = children
            opts = node['options']
            widget = opts.get('widgetOptions', opts.get('nodeOptions', opts))
            tags.add(widget.get('actionTag', 0))
            return kept

        scoped = copy.deepcopy(tree)
        scoped['nodeTree'] = prune(tree['nodeTree'])
        if found != requested:
            raise ValueError('Original node scope offset not present: ' + member)
        external = set(self.external_texture_nodes.get(member, []))
        if not external.issubset(requested):
            raise ValueError('External texture input must be in the explicit node scope: ' + member)

        def external_sprites(node):
            if node['_offset'] in external and node.get('classname') != 'Sprite':
                raise ValueError('External texture input requires an original Sprite: ' + member)
            for child in node.get('children', []):
                external_sprites(child)
        external_sprites(scoped['nodeTree'])
        if isinstance(scoped.get('action'), dict):
            scoped['action']['timeLines'] = [t for t in scoped['action'].get('timeLines', [])
                                            if t.get('actionTag') in tags]
        scoped['_selected_source_offsets'] = offsets
        scoped['_partial_source_scene'] = True
        self.scenes[member] = scoped
        self.node_scopes[member] = offsets

        def dependencies(value):
            if isinstance(value, dict):
                if value.get('classname') == 'Sprite' and value.get('_offset') in external:
                    # Keep the original node/CSB/reference intact. Only its
                    # editor preview is not a required runtime dependency:
                    # an explicit existing image owner supplies these pixels.
                    for key, item in value.items():
                        if key == 'options':
                            for option, payload in item.items():
                                if option != 'fileNameData':
                                    dependencies(payload)
                        else:
                            dependencies(item)
                    return
                if value.get('_type') == 'ResourceData':
                    self.resource(value, member)
                if value.get('_type') == 'ProjectNodeOptions' and value.get('fileName'):
                    self.scene(value['fileName'])
                for child in value.values():
                    dependencies(child)
            elif isinstance(value, list):
                for child in value:
                    dependencies(child)
        dependencies(scoped)

    def closure(self, member):
        """One scene's own dependency closure, sharing verified read caches."""
        probe = Builder(self.index, self.link_originals)
        probe.files, probe.atlases, probe._trees = self.files, self.atlases, self._trees
        probe.scene(member)
        return probe

    def complete_scenes(self, entries):
        """Keep only entry scenes whose whole closure resolves.

        A scene whose closure names a member absent from the source index (or
        an absent atlas frame) is listed with its own blockers and left out;
        nothing is substituted. Returns the kept entries and the exclusions.
        """
        if self.node_scopes or self.layout_sources or self.external_texture_nodes:
            raise ValueError('Complete-scene selection does not combine with partial scopes')
        kept, excluded, touched, scenes, compatibility = [], {}, set(), {}, []
        for member in entries:
            probe = self.closure(member)
            blockers = list({json.dumps(b, sort_keys=True): b for b in probe.blockers}.values())
            if blockers:
                excluded[source_path(member)] = blockers
                continue
            kept.append(member)
            touched |= probe.touched
            scenes.update(probe.scenes)
            compatibility.extend(probe.source_compatibility)
        self.scenes = scenes
        self.files = {k: v for k, v in self.files.items() if k in touched}
        self.atlases = {k: v for k, v in self.atlases.items() if k in touched}
        self.source_compatibility = compatibility
        self.blockers = []
        self.excluded_scenes = excluded
        return kept, excluded

    def build(self, entries, output):
        output = Path(output)
        if output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
            raise ValueError('Original UI packs must stay outside the public checkout')
        if output.exists():
            raise ValueError('Use a new private output directory; existing packs are preserved')
        for member in entries:
            self.scene(member)
        for member, offsets in self.external_texture_nodes.items():
            if member not in self.node_scopes or not set(offsets).issubset(self.node_scopes[member]):
                raise ValueError('External texture input requires an explicit partial scene: ' + member)
        blockers = list({json.dumps(b, sort_keys=True): b for b in self.blockers}.values())
        manifest = {'schema': 'twilight-original-ui-v1', 'entries': entries,
                    'scenes': self.scenes, 'atlases': self.atlases,
                    'files': {k: {n: v for n, v in item.items() if n not in ('raw', 'origin')}
                             for k, item in self.files.items()},
                    'blockers': blockers, 'runtime_verified': False}
        if self.layout_sources:
            manifest['layout_sources'] = self.layout_sources
        if self.node_scopes:
            manifest['node_scopes'] = self.node_scopes
        if self.external_texture_nodes:
            manifest['externally_bound_texture_nodes'] = self.external_texture_nodes
        if self.source_compatibility:
            manifest['source_compatibility'] = list({json.dumps(x, sort_keys=True): x for x in self.source_compatibility}.values())
        excluded = getattr(self, 'excluded_scenes', None)
        if excluded is not None:
            # Entry scenes left out because their closure names members the
            # source index does not hold. Not loaded and not blockers.
            manifest['incomplete_source_scenes'] = excluded
        output.mkdir(parents=True)
        for member, item in self.files.items():
            target = output / 'originals' / member
            target.parent.mkdir(parents=True, exist_ok=True)
            if item['raw'] is None:
                os.link(item['origin'], target)
                if digest(target.read_bytes()) != item['sha256']:
                    raise ValueError('Linked original changed: ' + member)
            else:
                target.write_bytes(item['raw'])
        raw = (json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
        (output / 'original_ui.json').write_bytes(raw)
        receipt = {'manifest_sha256': digest(raw), 'scenes': len(self.scenes), 'files': len(self.files),
                   'blockers': len(blockers), 'status': 'DEPENDENCIES_RESOLVED_NOT_RENDERED' if not blockers else 'BLOCKED'}
        if excluded is not None:
            receipt['entries'] = len(entries)
            receipt['incomplete_source_scenes'] = len(excluded)
        if self.node_scopes:
            receipt['partial_node_scopes'] = self.node_scopes
            receipt['whole_scene_completion_claimed'] = False
        if self.external_texture_nodes:
            receipt['externally_bound_texture_nodes'] = self.external_texture_nodes
            receipt['status'] = 'STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER' if not blockers else 'BLOCKED'
            receipt['external_pixels_received_or_used_claimed'] = False
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-index', type=Path, required=True)
    parser.add_argument('--scene', action='append', default=[])
    parser.add_argument('--scene-list', type=Path,
                        help='file with one original scene member per line (for example csb-scenes.txt)')
    parser.add_argument('--complete-scenes-only', action='store_true',
                        help='keep only entry scenes whose whole closure resolves; list the others')
    parser.add_argument('--link-originals', action='store_true',
                        help='hardlink unchanged originals from plain-file origins instead of copying')
    parser.add_argument('--layout-source', action='append', default=[],
                        help='Original parent CSB geometry only; not an activated scene closure')
    parser.add_argument('--node-scene', action='append', default=[],
                        help='Explicit partial original scope: UI/path.csb:offset,offset')
    parser.add_argument('--external-texture-node', action='append', default=[],
                        help='Exact scoped Sprite receiving existing image-owner pixels at runtime: UI/path.csb:offset')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        parser.error('Original UI packs must stay outside the public checkout')
    scenes = list(args.scene)
    if args.scene_list:
        scenes += [line.strip() for line in args.scene_list.read_text(encoding='utf-8').splitlines() if line.strip()]
    if not scenes:
        parser.error('at least one --scene or --scene-list entry is required')
    if len(set(scenes)) != len(scenes):
        parser.error('duplicate scene entry')
    index = json.loads(args.source_index.read_text())
    builder = Builder(index.get('source_files', index), link_originals=args.link_originals)
    for spec in args.external_texture_node:
        member, separator, offset = spec.rpartition(':')
        if not separator:
            parser.error('--external-texture-node requires an original member and offset')
        member = source_path(member)
        offsets = builder.external_texture_nodes.setdefault(member, [])
        value = int(offset)
        if value in offsets:
            parser.error('Duplicate external texture node')
        offsets.append(value)
    for member in args.layout_source:
        builder.layout_source(member)
    for spec in args.node_scene:
        member, separator, values = spec.rpartition(':')
        if not separator:
            parser.error('--node-scene requires an original member and offsets')
        builder.node_scene(member, [int(value) for value in values.split(',')])
    if args.complete_scenes_only:
        if args.output.exists():
            parser.error('Use a new private output directory; existing packs are preserved')
        scenes, _ = builder.complete_scenes(scenes)
    print(json.dumps(builder.build(scenes, args.output)))


if __name__ == '__main__':
    main()
