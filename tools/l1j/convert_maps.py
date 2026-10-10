"""Validate A3 and JP cache headers; convert x-major bytes to explicit row-major grids."""
import argparse, hashlib, json, pathlib, struct, zipfile
import numpy as np

IDS=[4,*range(101,111)]
def read_cache(blob, expected):
    if len(blob)<20: raise ValueError('truncated map header')
    id,x,y,w,h=struct.unpack('>5i',blob[:20])
    if id != expected or w<=0 or h<=0 or w>4096 or h>4096 or len(blob)!=20+w*h:
        raise ValueError('invalid dimensions, ID or exact payload length')
    row=np.frombuffer(blob[20:],np.uint8).reshape(w,h).T.copy()
    return {'map_id':id,'source_origin':[x,y],'dimensions':[w,h]}, row

def main():
    p=argparse.ArgumentParser();p.add_argument('--a3',type=pathlib.Path,required=True);p.add_argument('--jp',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args()
    output=a.out;rawdir=output/'raw';rawdir.mkdir(parents=True,exist_ok=True)
    maps=[]
    with zipfile.ZipFile(a.a3) as source,zipfile.ZipFile(a.jp) as jp:
        for id in IDS:
            blob=source.read(f'data/mapcache/{id}.map');meta,row=read_cache(blob,id)
            other_name=next((n for n in jp.namelist() if n.endswith(f'/data/mapcache/{id}.map')),None)
            status='MISSING';count=0
            if other_name:
                ometa,other=read_cache(jp.read(other_name),id)
                if ometa['dimensions']==meta['dimensions'] and ometa['source_origin']==meta['source_origin']:
                    count=int(np.count_nonzero(row!=other));status='IDENTICAL' if count==0 else 'SOURCE_VARIANT'
                else: status='HEADER_VARIANT'
            data=row.tobytes();(rawdir/f'{id}.bin').write_bytes(data)
            maps.append(meta|{'source_sha256':hashlib.sha256(blob).hexdigest(),'row_major_sha256':hashlib.sha256(data).hexdigest(),'jp_comparison':status,'jp_different_tiles':count,'terrain_graphics':'MISSING','navigation_rules':'A3 L1V1Map.checkMoveTile; no dynamic objects or door state','gameplay_collision_applied':False})
    (output/'source_maps.json').write_text(json.dumps({'maps':maps},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'converted_maps':len(maps),'jp_status':{r['map_id']:r['jp_comparison'] for r in maps}}))
if __name__=='__main__':main()
