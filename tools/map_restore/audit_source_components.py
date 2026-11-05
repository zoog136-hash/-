"""Audit disconnected source components against explicit original entries."""
import argparse, base64, collections, json, struct
from pathlib import Path


def audit(root, row):
    words = {}
    for file in (root / ('base508_asset_' + row['asset']) / 'geometry').glob('*.json'):
        g = json.loads(file.read_text()); raw = base64.b64decode(g['attribute_u16le']); ox, oy = g['origin']
        for y in range(64):
            for x in range(64):
                pair = struct.unpack_from('<HH', raw, (y * 128 + x * 2) * 2)
                if any(v not in (0, 1) for v in pair):
                    raise ValueError('Unreviewed profile; no bit masking permitted')
                words[ox + x, oy + y] = pair
    def neighbors(cell):
        x, y = cell
        for target, channel, at in [((x+1,y),1,cell),((x-1,y),1,(x-1,y)),((x,y+1),0,(x,y+1)),((x,y-1),0,cell)]:
            if target in words and words[at][channel] == 0:
                yield target
    labels = {}; components = []
    for cell in words:
        if cell in labels or not list(neighbors(cell)):continue
        index = len(components); labels[cell] = index; queue = collections.deque([cell]); cells = []
        while queue:
            current = queue.popleft(); cells.append(current)
            for target in neighbors(current):
                if target not in labels:labels[target] = index; queue.append(target)
        components.append(dict(id=index,cells=len(cells),bounds=[min(x for x,y in cells),min(y for x,y in cells),max(x for x,y in cells),max(y for x,y in cells)],entries=[]))
    rejected = []
    for entry in row['entries']:
        label = labels.get((entry['x'],entry['y']))
        if label is None:rejected.append(entry)
        else:components[label]['entries'].append(entry)
    return dict(asset=row['asset'],land=row['land'],components=components,rejected_entries=rejected,interpretation='ZERO_ONE_REVIEW_POLICY_NOT_NATIVE_M_PROOF')


def main():
    p=argparse.ArgumentParser();p.add_argument('--assets',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--asset',action='append',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    rows=json.loads(a.catalog.read_text())['maps'];results=[audit(a.assets,r) for r in rows if r['asset'] in a.asset]
    a.out.write_text(json.dumps(results,ensure_ascii=False,indent=2))
    for r in results:print(r['asset'],[(c['cells'],len(c['entries'])) for c in r['components']], 'rejected',len(r['rejected_entries']))

if __name__=='__main__':main()
