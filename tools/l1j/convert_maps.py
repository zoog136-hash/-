"""Validate A3 and JP cache headers; convert x-major bytes to explicit row-major grids."""
import argparse, collections, hashlib, json, pathlib, re, struct, zipfile
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
    p=argparse.ArgumentParser();p.add_argument('--a3',type=pathlib.Path,required=True);p.add_argument('--jp',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True)
    p.add_argument('--all',action='store_true',help='Convert every supplied A3 map cache, without selecting example maps')
    a=p.parse_args()
    output=a.out;rawdir=output/'raw';rawdir.mkdir(parents=True,exist_ok=True)
    maps=[]
    with zipfile.ZipFile(a.a3) as source,zipfile.ZipFile(a.jp) as jp:
        ids=sorted(int(match.group(1)) for name in source.namelist()
                   if (match:=re.fullmatch(r'data/mapcache/(\d+)\.map',name))) if a.all else IDS
        if len(set(ids))!=len(ids): raise ValueError('duplicate map cache IDs')
        jp_members={int(match.group(1)):name for name in jp.namelist()
                    if (match:=re.search(r'/data/mapcache/(\d+)\.map$',name))}
        for id in ids:
            if id<0 or id>99999: raise ValueError('unsupported source map ID')
            blob=source.read(f'data/mapcache/{id}.map');meta,row=read_cache(blob,id)
            other_name=jp_members.get(id)
            status='MISSING';count=0
            if other_name:
                ometa,other=read_cache(jp.read(other_name),id)
                if ometa['dimensions']==meta['dimensions'] and ometa['source_origin']==meta['source_origin']:
                    count=int(np.count_nonzero(row!=other));status='IDENTICAL' if count==0 else 'SOURCE_VARIANT'
                else: status='HEADER_VARIANT'
            data=row.tobytes();(rawdir/f'{id}.bin').write_bytes(data)
            maps.append(meta|{'source_sha256':hashlib.sha256(blob).hexdigest(),'row_major_sha256':hashlib.sha256(data).hexdigest(),'jp_comparison':status,'jp_different_tiles':count,'terrain_graphics':'MISSING','navigation_rules':'A3 L1V1Map.checkMoveTile; no dynamic objects or door state','gameplay_collision_applied':False})
    (output/'source_maps.json').write_text(json.dumps({'maps':maps,'selection':'all' if a.all else 'legacy selected IDs'},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'converted_maps':len(maps),'jp_status_counts':dict(collections.Counter(r['jp_comparison'] for r in maps))}))
if __name__=='__main__':main()
