"""Export only complete, semantically registered candidates into a QA overlay."""
import argparse,hashlib,json,subprocess
from pathlib import Path

def prepare(root,out,ref):
    out.mkdir(parents=True,exist_ok=False)
    def overlay(src,dst,open_paths):
        dst.mkdir(exist_ok=True)
        for p in src.iterdir():
            if p.name.startswith('.'):continue
            if p.name in open_paths:overlay(p,dst/p.name,open_paths[p.name])
            else:(dst/p.name).symlink_to(p,target_is_directory=p.is_dir())
    overlay(root,out,{'assets':{'actors':{'eight_direction':{}}},'data':{}})
    # Open the legendary subtree only; never write through an existing symlink.
    target=out/'assets/actors/eight_direction/legendary_parallel'
    assert not target.exists() and not target.is_symlink()
    proc=subprocess.Popen(['git','cat-file','--batch'],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    def blob(path):
        path=path.removeprefix('res://');proc.stdin.write((ref+':'+path+'\n').encode());proc.stdin.flush();h=proc.stdout.readline().split()
        if h[-1]==b'missing':raise FileNotFoundError(path)
        data=proc.stdout.read(int(h[2]));proc.stdout.read(1);return data
    manifest=json.loads(blob('data/pr122_legendary_parallel_staging.json'))
    lib=json.loads(blob(manifest['corrections']['active_revision_library']))
    eligible={tuple(r['slot']):r for r in lib['revisions'] if r.get('registration_status')=='REVIEWED_ANCHORS_AND_SCALE'}
    actors={};blocked=[];pins={}
    import re
    def export(path,expected=None):
        path=path.removeprefix('res://');data=blob(path);sha=hashlib.sha256(data).hexdigest()
        if expected:assert sha==expected,path
        dest=out/path;dest.parent.mkdir(parents=True,exist_ok=True);assert not dest.is_symlink();dest.write_bytes(data);pins[path]=sha
        return data
    for a in manifest['actors']:
        slots=[(a['key'],d,r) for d,r in manifest['production_order']]
        if not all(s in eligible for s in slots):
            blocked.append({'key':a['key'],'required':33,'reviewed_registered_slots':sum(s in eligible for s in slots),'reason':'Incomplete reviewed anatomical anchor/scale coverage; no feet inferred from raster centers'});continue
        tracks=[]
        for key,direction,role in slots:
            r=eligible[(key,direction,role)];raw=export(r['SpriteFrames'],r['SpriteFrames_sha256'])
            for texture in re.findall(r'path="(res://[^\"]+\.png)"',raw.decode()):export(texture)
            reg=json.loads(export(r['registration'],r['registration_sha256']))
            tracks.append({'role':role,'direction':direction,'animation':role+'_'+str(manifest['directions'].index(direction)),'frames':r['SpriteFrames'],'registration':reg})
        actors[a['key']]={'grade':'전설','tracks':tracks,'frames':'res://data/pr158_legendary_'+a['key'].split(':')[1]+'_QA.tres'}
    proc.stdin.close();proc.wait()
    plan={'source_sha':ref,'scope':'QA overlay only; complete reviewed registration coverage required. No default installation or final approval.','actors':actors,'blocked':blocked,'pins':pins}
    (out/'data/pr158_legendary_reviewed_batch.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
    print('eligible actors',len(actors),'eligible clips',sum(len(a['tracks']) for a in actors.values()),'blocked actors',len(blocked))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--ref',required=True);a=p.parse_args();prepare(a.root.resolve(),a.output.resolve(),a.ref)
