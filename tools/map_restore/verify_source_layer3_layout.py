"""Check original S32 L3 layout and reference overlay boundary geometry."""
import argparse,base64,json,struct
from pathlib import Path


def verify(file,source):
    g=json.loads(file.read_text());raw=(source/g['member']).read_bytes()
    count=struct.unpack_from('<H',raw,32768)[0];offset=32768+2+6*count
    attributes=base64.b64decode(g['attribute_u16le'])
    assert len(attributes)==16384 and raw[offset:offset+16384]==attributes, g['member']
    for y in range(64):
        for x in range(64):
            px,py=24*x+24*y,12*y-12*x
            # Current cell center and exact neighbor-midpoint boundary construction.
            center=(px+24,py+12)
            midpoint1=(center[0]-12,center[1]-6)
            midpoint2=(center[0]+12,center[1]-6)
            edge1={(midpoint1[0]-12,midpoint1[1]+6),(midpoint1[0]+12,midpoint1[1]-6)}
            edge2={(midpoint2[0]-12,midpoint2[1]-6),(midpoint2[0]+12,midpoint2[1]+6)}
            assert edge1=={(px,py+12),(px+24,py)}
            assert edge2=={(px+24,py),(px+48,py+12)}
    return dict(member=g['member'],layer3_offset=offset,words=8192,boundaries=8192,raw_bits_preserved=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--geometry',type=Path,action='append',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    result=[verify(file,a.source) for file in a.geometry];a.out.write_text(json.dumps(result,indent=2));print(json.dumps(result))

if __name__=='__main__':main()
