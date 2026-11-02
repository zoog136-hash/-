"""Wrap worker-provided original PNGs without decoding, resizing or altering bytes."""
import argparse,json,pathlib,sys,zipfile
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'lineagem_original'))
from package_install_zip import encoded,digest,safe

def build(source,output):
    manifest=json.loads((source/'manifest.json').read_text())
    if manifest.get('kind')!='base508_monster_pack' or manifest.get('source_snapshot')!='base508':raise ValueError('Unsupported source monster pack')
    paths={}
    for actor in manifest['records'].values():
        for track in actor['tracks'].values():
            for frames in track['directions']:
                for frame in frames:
                    for layer in frame['layers']:
                        path=layer['path']
                        if not safe(path) or not path.startswith('pixels/'):raise ValueError('Unsafe original pixel path')
                        if path in paths and paths[path]!=layer['sha256']:raise ValueError('Conflicting pixel receipt')
                        paths[path]=layer['sha256']
    files=['manifest.json']+sorted(paths)
    chunks=[];rows=[];blob=bytearray();total=0
    if output.exists():raise FileExistsError(output)
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        def flush():
            if not rows:return
            i=len(chunks);index=f'inventory/{i:04d}.json';payload=f'payload/{i:04d}.bin';data=encoded(rows)
            z.writestr(index,data);z.writestr(payload,blob)
            chunks.append({'path':index,'bytes':len(data),'sha256':digest(data),'count':len(rows),'payload':payload,'payload_bytes':len(blob),'payload_sha256':digest(blob)})
            rows.clear();blob.clear()
        for name in files:
            data=(source/name).read_bytes()
            if name in paths and digest(data)!=paths[name]:raise ValueError('Original pixel differs: '+name)
            if rows and (len(rows)>=1024 or len(blob)+len(data)>32*1024*1024):flush()
            rows.append({'path':name,'bytes':len(data),'offset':len(blob),'sha256':digest(data)});blob.extend(data);total+=len(data)
        flush()
        header={'schema':2,'kind':'twilight-lineagem-offline-monsters','source_snapshot':'base508','release_id':'base508-four-monsters-v1','files':len(files),'bytes':total,'npc_ids':sorted(map(int,manifest['records'])),'chunks':chunks,'provenance_library_id':'libfile_2798754f816c8191a1800f2055f49204','handoff_sha256':'5c8fca8f1a837332400c434b2d7fec04d63fbb239529ff559a57c5384a08542d','limits':'Exact source context with host Aden slot placement; native geographic spawns0. Unspecified clocks remain unverified compatible playback. No source server combat/drop formula inferred.'}
        z.writestr('pack.json',encoded(header))
    receipt={'file':str(output),'bytes':output.stat().st_size,'sha256':digest(output.read_bytes()),'files':len(files),'unchanged_original_pngs':len(paths),'installed_bytes':total,'npc_ids':header['npc_ids'],'requires_collectible_full_pack':False}
    output.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();build(a.source,a.output)
