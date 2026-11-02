#!/usr/bin/env python3
"""Normalize inspected original CSB geometry; never infer resource/grade joins."""
import argparse
import hashlib
import json
from pathlib import Path

PREFIX = 'UI/Change/'
FILES = [PREFIX + 'Change_Card_A_' + grade + '.csb' for grade in
         ('Common', 'Rare', 'Unique', 'Legend', 'Epic', 'Myth', 'Sole')]
FILES += [PREFIX + name + '.csb' for name in
          ('Change_WinTotal', 'Change_DetailView', 'Change_CollectionView',
           'Change_Card_A_Amount')]


def normalize(source):
    nodes = source['nodes']
    lookup = {node['table_offset']: node for node in nodes}
    origins = {}
    visiting = set()

    def origin(key):
        if key in origins:
            return origins[key]
        if key in visiting:
            raise ValueError('Cyclic source node parents')
        visiting.add(key)
        node = lookup[key]
        parent = node['parent_table_offset']
        px, py, sx, sy = origin(parent) if parent is not None else (0, 0, 1, 1)
        scale = node['scale']
        wx, wy = sx * scale[0], sy * scale[1]
        anchor, size, position = node['anchorPoint'], node['size'], node['position']
        result = (px + position[0] * sx - anchor[0] * size[0] * wx,
                  py + position[1] * sy - anchor[1] * size[1] * wy, wx, wy)
        origins[key] = result
        visiting.remove(key)
        return result

    result = []
    for node in nodes:
        x, y, sx, sy = origin(node['table_offset'])
        width, height = node['size'][0] * sx, node['size'][1] * sy
        refs = [{k: ref[k] for k in ('field', 'path', 'plistFile', 'resourceType')}
                for ref in source.get('resource_data', [])
                if ref['owner_node'] == node['table_offset'] and ref.get('path')]
        result.append({**node, 'bounds_y_up': [x, y, width, height], 'resources': refs})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inspection', type=Path, action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sources, evidence = {}, []
    for path in args.inspection:
        raw = path.read_bytes()
        for key, value in json.loads(raw).items():
            if key in sources and sources[key] != value:
                raise ValueError('Conflicting inspection: ' + key)
            sources[key] = value
        evidence.append({'name': path.parent.name + '/' + path.name,
                         'sha256': hashlib.sha256(raw).hexdigest()})
    missing = sorted(set(FILES) - sources.keys())
    if missing:
        raise ValueError('Missing explicit CSB inspection: ' + ', '.join(missing))
    output = {'schema': 1, 'source': 'lineagem_base508', 'design_size': [1200, 675],
              'coordinate_system': 'Cocos y-up; bounds include ancestor anchors/scales',
              'evidence': evidence,
              'screens': {key: normalize(sources[key]) for key in FILES}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    print('Normalized', len(FILES), 'original CSBs;',
          sum(len(v) for v in output['screens'].values()), 'nodes')


if __name__ == '__main__':
    main()
