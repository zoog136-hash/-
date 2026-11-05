#!/usr/bin/env python3
"""Bounded, read-only CSB decoder using the inspected upstream 3.6 field schema.

Preserves class options and easing rather than projecting just node rectangles.
Unknown nonempty fields/classes remain explicit blockers for a renderer. The
output is private source data and must never be written inside the checkout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

SCHEMA = json.loads(Path(__file__).with_name('cocos36_schema.json').read_text())
CLASSES = {
    'Node': 'WidgetOptions', 'SingleNode': 'SingleNodeOptions',
    'Sprite': 'SpriteOptions', 'Particle': 'ParticleSystemOptions',
    'GameMap': 'GameMapOptions', 'Button': 'ButtonOptions',
    'CheckBox': 'CheckBoxOptions', 'ImageView': 'ImageViewOptions',
    'TextAtlas': 'TextAtlasOptions', 'TextBMFont': 'TextBMFontOptions',
    'Text': 'TextOptions', 'TextField': 'TextFieldOptions',
    'LoadingBar': 'LoadingBarOptions', 'Slider': 'SliderOptions',
    'Panel': 'PanelOptions', 'ScrollView': 'ScrollViewOptions',
    'PageView': 'PageViewOptions', 'ListView': 'ListViewOptions',
    'ProjectNode': 'ProjectNodeOptions', 'Component': 'ComponentOptions',
}


class DecodeError(ValueError):
    pass


class Reader:
    def __init__(self, raw: bytes):
        if not 8 <= len(raw) <= 64 * 1024 * 1024:
            raise DecodeError('CSB size outside bounded input range')
        self.raw = raw
        self.stack = set()
        self.count = 0
        self.blockers = []

    def unpack(self, fmt, offset):
        size = struct.calcsize('<' + fmt)
        if offset < 0 or offset + size > len(self.raw):
            raise DecodeError(f'Out-of-bounds {fmt} at {offset}')
        values = struct.unpack_from('<' + fmt, self.raw, offset)
        if any(isinstance(v, float) and not math.isfinite(v) for v in values):
            raise DecodeError('Nonfinite source number')
        return values[0] if len(values) == 1 else list(values)

    def pointer(self, position):
        target = position + self.unpack('I', position)
        if target < position + 4 or target >= len(self.raw):
            raise DecodeError('Invalid forward offset')
        return target

    def fields(self, offset):
        vtable = offset - self.unpack('i', offset)
        length = self.unpack('H', vtable)
        object_size = self.unpack('H', vtable + 2)
        if length < 4 or length % 2 or object_size < 4 or offset + object_size > len(self.raw):
            raise DecodeError('Invalid vtable or object size')
        result = []
        for index in range((length - 4) // 2):
            relative = self.unpack('H', vtable + 4 + index * 2)
            if relative and not 4 <= relative < object_size:
                raise DecodeError('Field is outside its object')
            result.append(offset + relative if relative else None)
        return result

    def string(self, offset):
        length = self.unpack('I', offset)
        if length > 1024 * 1024 or offset + 4 + length >= len(self.raw):
            raise DecodeError('Invalid string length')
        if self.raw[offset + 4 + length] != 0:
            raise DecodeError('Missing string terminator')
        return self.raw[offset + 4:offset + 4 + length].decode('utf-8', 'strict')

    def value(self, kind, position, depth):
        if kind in ('i', 'B', 'f'):
            return self.unpack(kind, position)
        if kind.startswith('struct:'):
            return self.unpack(SCHEMA['structs'][kind.split(':', 1)[1]], position)
        target = self.pointer(position)
        if kind == 'string':
            return self.string(target)
        if kind.startswith('table:'):
            return self.table(kind.split(':', 1)[1], target, depth + 1)
        vector_kind, item_kind = kind.split(':', 1)
        count = self.unpack('I', target)
        fmt = SCHEMA['structs'][item_kind] if vector_kind == 'vector_struct' else 'I'
        stride = struct.calcsize('<' + fmt)
        if count > 100000 or target + 4 + count * stride > len(self.raw):
            raise DecodeError('Invalid vector length')
        values = []
        for index in range(count):
            item = target + 4 + index * stride
            if vector_kind == 'vector_struct':
                values.append(self.unpack(fmt, item))
            elif item_kind == 'string':
                values.append(self.string(self.pointer(item)))
            else:
                values.append(self.table(item_kind, self.pointer(item), depth + 1))
        return values

    def table(self, kind, offset, depth=0):
        if depth > 128 or offset in self.stack:
            raise DecodeError('Cyclic or excessive source nesting')
        self.count += 1
        if self.count > 250000:
            raise DecodeError('Source table budget exceeded')
        self.stack.add(offset)
        fields = self.fields(offset)
        definition = SCHEMA['tables'][kind]
        result = {'_type': kind, '_offset': offset}
        unknown = [i for i in range(len(definition), len(fields)) if fields[i] is not None]
        if unknown:
            issue = {'table': kind, 'offset': offset, 'unknown_field_indices': unknown}
            self.blockers.append(issue)
            result['_unknown_fields'] = unknown
        for index, (name, field_kind, default) in enumerate(definition):
            position = fields[index] if index < len(fields) else None
            if position is None:
                result[name] = [] if field_kind.startswith('vector') else default
            elif kind == 'NodeTree' and name == 'options':
                wrapper = self.pointer(position)
                wrapper_fields = self.fields(wrapper)
                if any(wrapper_fields[1:]):
                    self.blockers.append({'table': 'Options', 'offset': wrapper, 'reason': 'unknown_option_wrapper_fields'})
                data = wrapper_fields[0] if wrapper_fields else None
                option_kind = CLASSES.get(result['classname'])
                if option_kind is None:
                    self.blockers.append({'class': result['classname'], 'offset': offset, 'reason': 'unknown_node_class'})
                    result[name] = None
                else:
                    result[name] = self.table(option_kind, self.pointer(data), depth + 1) if data else None
            else:
                result[name] = self.value(field_kind, position, depth)
        self.stack.remove(offset)
        return result

    def parse(self):
        root = self.unpack('I', 0)
        result = self.table('CSParseBinary', root)
        if result['version'] != '2.1.0.0':
            raise DecodeError('Unverified CSB version: ' + str(result['version']))
        result['_source_sha256'] = hashlib.sha256(self.raw).hexdigest()
        result['_schema_blob_sha'] = SCHEMA['blob_sha']
        result['_decode_blockers'] = self.blockers
        result['_render_status'] = 'NOT_RENDERED'
        return result


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('source', type=Path)
    args.add_argument('output', type=Path)
    options = args.parse_args()
    checkout = Path(__file__).resolve().parents[2]
    if options.output.resolve().is_relative_to(checkout):
        args.error('Decoded original data must stay outside the public checkout')
    if options.output.resolve() == options.source.resolve():
        args.error('Cannot overwrite source')
    result = Reader(options.source.read_bytes()).parse()
    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'source_sha256': result['_source_sha256'], 'blockers': result['_decode_blockers']}))


if __name__ == '__main__':
    main()
