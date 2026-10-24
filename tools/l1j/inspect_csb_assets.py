#!/usr/bin/env python3
"""Bounded read-only Cocos Studio FlatBuffer/PLIST metadata inspection.

Field layout reference: cocos2d-x/v3 CSParseBinary.fbs. This reads ordinary
FlatBuffers, never decrypts XML/JSON/BIN, and never executes archive content.
Unknown UI option types and easing remain unapproved, not invented nodes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct
import shutil


class Buffer:
    def __init__(self, data):
        if not 4 <= len(data) <= 16 * 1024 * 1024:
            raise ValueError('CSB size out of bounds')
        self.data = data

    def read(self, fmt, pos):
        size = struct.calcsize('<' + fmt)
        if pos < 0 or pos + size > len(self.data):
            raise ValueError('FlatBuffer offset out of bounds')
        result = struct.unpack_from('<' + fmt, self.data, pos)
        return result[0] if len(result) == 1 else list(result)

    def field(self, table, index):
        vt = table - self.read('i', table)
        size = self.read('H', vt)
        offset = self.read('H', vt + 4 + index * 2) if 4 + index * 2 < size else 0
        return table + offset if offset else 0

    def scalar(self, table, index, fmt='i', default=0):
        pos = self.field(table, index)
        return self.read(fmt, pos) if pos else default

    def pointer(self, pos):
        return pos + self.read('I', pos) if pos else 0

    def table(self, table, index):
        return self.pointer(self.field(table, index))

    def string_at(self, pos):
        if not pos:
            return ''
        count = self.read('I', pos)
        if count > 65536 or pos + count + 4 > len(self.data):
            raise ValueError('FlatBuffer string length out of bounds')
        return self.data[pos + 4:pos + 4 + count].decode('utf-8')

    def string(self, table, index):
        return self.string_at(self.table(table, index))

    def vector(self, table, index):
        pos = self.table(table, index)
        if not pos:
            return []
        count = self.read('I', pos)
        if count > 20000:
            raise ValueError('FlatBuffer vector budget exceeded')
        return [self.pointer(pos + 4 + i * 4) for i in range(count)]

    def resource(self, table):
        return {'path': self.string(table, 0), 'plist': self.string(table, 1),
                'resource_type': self.scalar(table, 2)} if table else {}

    def node(self, table, depth=0):
        if depth > 40:
            raise ValueError('Node depth exceeded')
        kind = self.string(table, 0)
        result = {'class': kind, 'children': [self.node(t, depth + 1) for t in self.vector(table, 1)]}
        if kind not in ('Node', 'SingleNode', 'Sprite'):
            result['options_status'] = 'HOLD_UNSUPPORTED_UI_CLASS'
            return result
        options = self.table(self.table(table, 2), 0)
        widget = options if kind == 'Node' else self.table(options, 0)
        result.update(name=self.string(widget, 0), action_tag=self.scalar(widget, 1),
                      z=self.scalar(widget, 3), visible=bool(self.scalar(widget, 4, '?', True)),
                      alpha=self.scalar(widget, 5, 'B', 255))
        color = self.field(widget, 10)
        result['color_ARGB'] = self.read('BBBB',color) if color else [255]*4
        for name, index, default in [('rotation', 2, [0, 0]), ('position', 7, [0, 0]),
                                     ('scale', 8, [1, 1]), ('anchor', 9, [0, 0]), ('size', 11, [0, 0])]:
            pos = self.field(widget, index)
            result[name] = self.read('ff', pos) if pos else default
        if kind == 'Sprite':
            result['resource'] = self.resource(self.table(options, 1))
            pos = self.field(options, 2)
            result['blend'] = self.read('ii', pos) if pos else None
        return result

    def action(self, table):
        timelines = []
        for t in self.vector(table, 2):
            timeline = {'property': self.string(t, 0), 'action_tag': self.scalar(t, 1), 'frames': []}
            for f in self.vector(t, 2):
                populated = [(i, self.table(f, i)) for i in range(9) if self.field(f, i)]
                if len(populated) != 1:
                    raise ValueError('Ambiguous timeline union')
                kind, value = populated[0]
                item = {'kind': kind, 'index': self.scalar(value, 0),
                        'tween': bool(self.scalar(value, 1, '?', True))}
                pos = self.field(value, 2)
                if kind in (0, 1): item['value'] = self.read('ff', pos) if pos else [0, 0]
                elif kind == 2: item['value'] = self.read('BBBB', pos) if pos else [255] * 4
                elif kind == 3: item['value'] = self.resource(self.table(value, 2))
                elif kind == 4: item['value'] = self.string(value, 2)
                elif kind == 5: item['value'] = self.scalar(value, 2)
                elif kind == 6: item['value'] = bool(self.scalar(value, 2, '?', True))
                else: item['status'] = 'HOLD_UNSUPPORTED_INNER_OR_BLEND_TRACK'
                easing = self.table(value, 3) if kind != 7 else 0
                item['easing_type'] = self.scalar(easing, 0, default=-1) if easing else -1
                timeline['frames'].append(item)
            timelines.append(timeline)
        return {'duration': self.scalar(table, 0), 'speed': self.scalar(table, 1, 'f', 1.0),
                'timelines': timelines}


def inspect(source):
    report = {'csb': [], 'atlases': [], 'sounds': [], 'missing_sounds': ['10831', '10832'],
              'protected_xml_json_bin': 'UNVERIFIED_NOT_DECRYPTED', 'production_approved': False}
    for p in sorted(source.glob('*.csb')):
        entry = {'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
        try:
            b = Buffer(p.read_bytes())
            root = b.read('I', 0)
            entry.update(version=b.string(root, 0), node_tree=b.node(b.table(root, 3)),
                         action=b.action(b.table(root, 4)),
                         textures=[b.string_at(s) for s in b.vector(root, 1)],
                         status='PARSED_NOT_RUNTIME_APPROVED')
        except (ValueError, struct.error, UnicodeError) as e:
            entry.update(status='HOLD', reason=str(e))
        report['csb'].append(entry)
    for p in sorted(source.glob('*.plist')):
        data = plistlib.loads(p.read_bytes())
        report['atlases'].append({'file': p.name, 'frames': data['frames'], 'metadata': data['metadata'],
                                 'status': 'PARSED_NOT_RUNTIME_APPROVED'})
    for p in sorted(source.glob('*.ogg')):
        report['sounds'].append({'id': p.stem, 'bytes': p.stat().st_size,
                                 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'connected': False})
    return report


def export_fx(source, output, report):
    """Only the verified single Sprite/FileData subset, with exact key indices.

    60 frames/s is an explicit Cocos preview clock. Native blend constants are
    retained as metadata; no claim of independently approved compositing.
    """
    from PIL import Image
    checkout = Path(__file__).resolve().parents[2]
    if output.resolve() == checkout or output.resolve().is_relative_to(checkout):
        raise ValueError('Third-party output must remain outside the checkout')
    dest = output / 'assets/external_spx/csb_effects'
    dest.mkdir(parents=True, exist_ok=True)
    atlases = {x['file']: x for x in report['atlases']}
    for entry in report['csb']:
        if not entry['file'].startswith('FX_') or entry['status'] == 'HOLD':
            continue
        try:
            root = entry['node_tree']
            def walk(node):
                return [node] + [n for c in node['children'] for n in walk(c)]
            nodes = walk(root)
            if root['position'] != [0,0] or root['scale'] != [1,1] or root['rotation'] != [0,0]:
                raise ValueError('Nonidentity CSB root requires separate review')
            sprites = [n for n in nodes if n['class'] == 'Sprite']
            tracks = entry['action']['timelines']
            if (len(sprites) != 1 or len(tracks) != 1 or tracks[0]['property'] != 'FileData'
                    or tracks[0]['action_tag'] != sprites[0]['action_tag']
                    or any(n['class'] not in ('Node', 'SingleNode', 'Sprite') for n in nodes)):
                raise ValueError('Not the supported single-Sprite CSB subset')
            sprite = sprites[0]
            timeline = tracks[0]['frames']
            frames = {}
            textures = {}
            for f in timeline:
                if f['kind'] != 3 or f['tween'] or f['easing_type'] not in (-1, 0):
                    raise ValueError('Unsupported texture easing/union')
                name = f['value']['path']
                atlas = atlases[Path(f['value']['plist']).name]
                frame = atlas['frames'][name]
                if frame['rotated']:
                    raise ValueError('Rotated PLIST region requires separate review')
                png = Path(atlas['metadata']['realTextureFileName']).name
                textures[png] = source / png
                frames[name] = (png, frame)
            ext = {name: f'T{i}' for i, name in enumerate(textures)}
            sub = {name: f'F{i}' for i, name in enumerate(frames)}
            lines = [f'[gd_scene load_steps={len(ext)+len(sub)+4} format=3]', '']
            for name, path in textures.items():
                shutil.copyfile(path, dest / name)
                lines.append(f'[ext_resource type="Texture2D" path="{name}" id="{ext[name]}"]')
            for name, (png, frame) in frames.items():
                rect = [int(n) for n in re.findall(r'-?\d+', frame['frame'])]
                crop = [int(n) for n in re.findall(r'-?\d+', frame['sourceColorRect'])]
                size = [int(n) for n in re.findall(r'-?\d+', frame['sourceSize'])]
                with Image.open(source / png) as image:
                    if not (0 <= rect[0] <= image.width-rect[2] and 0 <= rect[1] <= image.height-rect[3]):
                        raise ValueError('PLIST rectangle outside image')
                lines += ['', f'[sub_resource type="AtlasTexture" id="{sub[name]}"]',
                          f'atlas = ExtResource("{ext[png]}")', 'region = Rect2('+', '.join(map(str, rect))+')',
                          f'margin = Rect2({crop[0]}, {crop[1]}, {size[0]-rect[2]}, {size[1]-rect[3]})']
            names = {id(n): f'N{i}' for i, n in enumerate(nodes)}
            parents = {}
            def parents_for(n, parent='.'):
                for child in n['children']:
                    parents[id(child)] = parent
                    parents_for(child, names[id(child)] if parent == '.' else parent+'/'+names[id(child)])
            parents_for(root)
            sprite_path = parents[id(sprite)] + '/' + names[id(sprite)] if parents[id(sprite)] != '.' else names[id(sprite)]
            times = ', '.join(str(f['index']/60.0) for f in timeline)
            values = ', '.join(f'SubResource("{sub[f["value"]["path"]]}")' for f in timeline)
            lines += ['', '[sub_resource type="Animation" id="Motion"]', 'resource_name = "source"',
                      f'length = {entry["action"]["duration"]/60.0}', 'tracks/0/type = "value"',
                      f'tracks/0/path = NodePath("{sprite_path}:texture")', 'tracks/0/interp = 0',
                      'tracks/0/keys = {"times": PackedFloat32Array('+times+'), "transitions": PackedFloat32Array('+', '.join('1' for _ in timeline)+'), "update": 1, "values": ['+values+']}',
                      '', '[sub_resource type="AnimationLibrary" id="Library"]', '_data = {&"source": SubResource("Motion")}',
                      '', '[node name="CSBEffect" type="Node2D"]', 'metadata/production_approved = false',
                      'metadata/source_clock = "60 frames/s preview; unverified absolute clock"']
            for n in nodes[1:]:
                kind = 'Sprite2D' if n['class'] == 'Sprite' else 'Node2D'
                lines += ['', f'[node name="{names[id(n)]}" type="{kind}" parent="{parents[id(n)]}"]',
                          f'position = Vector2({n["position"][0]}, {-n["position"][1]})',
                          f'scale = Vector2({n["scale"][0]}, {n["scale"][1]})',
                          'rotation = '+str(-n['rotation'][0]*3.141592653589793/180),
                          'modulate = Color('+', '.join(str(v/255.0) for v in n['color_ARGB'][1:])+f', {n["alpha"]/255.0})',
                          'visible = '+str(n['visible']).lower(), 'z_index = '+str(n['z'])]
                if n['rotation'][0] != n['rotation'][1]:
                    raise ValueError('Skew requires separate review')
                if kind == 'Sprite2D':
                    lines += [f'texture = SubResource("{sub[timeline[0]["value"]["path"]]}")',
                              'centered = false',
                              f'offset = Vector2({-n["anchor"][0]*n["size"][0]}, {-(1-n["anchor"][1])*n["size"][1]})',
                              'metadata/source_blend = '+json.dumps(n['blend'])]
            lines += ['', '[node name="AnimationPlayer" type="AnimationPlayer" parent="."]',
                      'libraries = {&"": SubResource("Library")}', 'autoplay = "source"', '']
            name = Path(entry['file']).stem + '.tscn'
            (dest / name).write_text('\n'.join(lines))
            entry['godot_candidate'] = 'res://assets/external_spx/csb_effects/' + name
            entry['runtime_status'] = 'NOT_RUN'
        except (KeyError, ValueError, OSError) as error:
            entry['export_HOLD'] = str(error)
    index = {Path(x['file']).stem: {'scene':x['godot_candidate'], 'production_approved':False,
             'source_csb_sha256':x['sha256'], 'blend_status':'HOLD'} for x in report['csb'] if x.get('godot_candidate')}
    data = output/'data/external_spx'
    data.mkdir(parents=True,exist_ok=True)
    (data/'csb_effects.json').write_text(json.dumps(index,indent=2)+'\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--private-output', type=Path)
    args = p.parse_args()
    report = inspect(args.source)
    if args.private_output:
        export_fx(args.source, args.private_output, report)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print([(x['file'], x['status']) for x in report['csb']])
