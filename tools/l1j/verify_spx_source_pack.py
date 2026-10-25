#!/usr/bin/env python3
"""Verify every packed frame against the SHA-pinned private audit, no decoding."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def verify(pack, audit, source):
    manifest = json.loads((pack/'data/external_spx/source_motion.json').read_text())
    expected = [r for r in json.loads(audit.read_text()) if r['path'].endswith('.spx')]
    by_group = {}
    for file in expected:
        group, sequence = Path(file['path']).stem.split('-')
        with (source/Path(file['path']).name).open('rb') as stream:
            assert hashlib.file_digest(stream,'sha256').hexdigest() == file['source_sha256']
        by_group.setdefault(group,{})[sequence] = file
    checked = empty = 0
    memory = {}
    for group, sequences in by_group.items():
        layer = manifest['groups'][group]
        pages = [Image.open(pack/'assets/external_spx/source_motion'/group/name).convert('RGBA') for name in layer['atlases']]
        memory[group] = sum(p.width*p.height*4 for p in pages)
        for sequence, file in sequences.items():
            for original in file['frames']:
                frame = layer['frames'][sequence+'/'+str(original['index'])]
                assert frame['empty'] == original['empty']
                assert frame['source_types'] == original['source_types']
                x,y,w,h = frame['rect']
                image = pages[frame['page']].crop((x,y,x+w,y+h))
                if original['empty']:
                    assert image.getchannel('A').getbbox() is None
                    empty += 1
                    continue
                restored = Image.new('RGBA',tuple(original['size']))
                restored.paste(image,tuple(frame['alpha_crop'][:2]))
                assert hashlib.sha256(restored.tobytes()).hexdigest() == original['rgba_sha256'], (group,sequence,original['index'])
                assert frame['offset'] == [original['xy_offset'][i]+frame['alpha_crop'][i] for i in range(2)]
                checked += 1
        for p in pages: p.close()
    assert len(expected)==1700 and len(by_group)==44
    assert checked==14304 and empty==230
    return {'spx_files':len(expected),'groups':len(by_group),'pixel_roundtrip_frames':checked,
            'preserved_empty_records':empty,'source_SHA':'PASS','offsets':'PASS','source_types':'PASS',
            'atlas_RGBA_bytes_by_group':memory,'all_groups_resident_RGBA_bytes':sum(memory.values()),
            'Android_device_memory':'NOT_RUN','original_blending':'HOLD_UNVERIFIED'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--pack',type=Path,required=True)
    p.add_argument('--audit',type=Path,required=True)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--report',type=Path,required=True)
    a=p.parse_args()
    result=verify(a.pack,a.audit,a.source)
    a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
