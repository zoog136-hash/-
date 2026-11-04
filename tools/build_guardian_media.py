#!/usr/bin/env python3
"""Keep original UI128 atlas bytes private; publish exact frame/CSB bindings only."""
import argparse,gzip,hashlib,io,json,plistlib,re,zipfile
from PIL import Image
from pathlib import Path

PREFIX='UI/UI_Resource/Atlas_Z_Fx_Seet_Skilltree_EnchantActive'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def numbers(value):return [int(x) for x in re.findall(r'-?\d+',value)]
def build(source,output):
    source=Path(source);container=source/'originals/Client/Data/UI128.dat';raw=container.read_bytes()
    assert sha(raw)=='d99c4d98453cfde8e7fd768754e6e2e42325013150b25058c51ed1d8ceaacb23'
    with zipfile.ZipFile(container) as archive:files={PREFIX+ext:archive.read(PREFIX+ext)for ext in ['.plist','.png']}
    plist=files[PREFIX+'.plist'];definition=plistlib.loads(plist[:plist.rfind(b'</plist>')+8]);frames={}
    for key,spec in definition['frames'].items():frames[key]={'rect':numbers(spec['frame']),'rotated':spec['rotated'],'source_rect':numbers(spec['sourceColorRect']),'source_size':numbers(spec['sourceSize'])}
    page=Image.open(io.BytesIO(files[PREFIX+'.png'])).convert('RGBA')
    assert page.size==(1024,1024)
    for spec in frames.values():
        x,y,w,h=spec['rect'];crop=page.crop((x,y,x+w,y+h));original=Image.new('RGBA',tuple(spec['source_size']))
        original.paste(crop,tuple(spec['source_rect'][:2]));spec['rgba_sha256']=sha(original.tobytes())
    trees=json.load(gzip.open(source/'combined_results/all551_csb_trees.json.gz','rt'))
    member='UI/SkillTree/SkillTree_Icon_SkillEnchant.csb';tree=trees[member];tag=1572849955
    node=next(n for n in tree['nodes']if n['action_tag']==tag)
    tracks=[t for t in tree['timelines']if t['action_tag']==tag]
    clip=next(c for c in tree['animation_list']if c['name']=='Fx_Active')
    assert clip=={'name':'Fx_Active','start':305,'end':383}
    assert all(not f['rotated']for f in frames.values())
    # Deterministic pack; no pixel conversion/recompression of the contained PNG.
    output=Path(output);output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED)as archive:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,(2026,11,4,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;archive.writestr(info,data)
    return {'schema':1,'source_version':523,'library_file_id':'libfile_0ba507ea27888191b60532f6aa6b6ff0','container':'Client/Data/UI128.dat','container_sha256':sha(raw),'container_bytes':len(raw),'source_archive':{'name':'TWILIGHT_UI551_binding_animation_evidence_20261104.zip','bytes':25261734,'sha256':'6e5c636cabe48ab8d4aa4a5d6d26122c3300ca65789568668335b71fdb386d91','member':'originals/Client/Data/UI128.dat'},'pack':{'name':output.name,'bytes':output.stat().st_size,'sha256':sha(output.read_bytes())},'members':{k:{'bytes':len(v),'sha256':sha(v)}for k,v in files.items()},'page':PREFIX+'.png','frames':frames,'animation':{'member':member,'clip':clip,'fps':60,'speed':tree['action']['speed'],'node':node,'tracks':tracks},'local_presentation_policy':'Replay original Fx_Active layer once on successfully enchanted source skill node; current UI adapter, not a claim of full original scene reconstruction. No synthetic replacement art.'}
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',required=True);parser.add_argument('--private-pack',required=True);parser.add_argument('--check',action='store_true');a=parser.parse_args();j=build(a.source,a.private_pack);p=Path(__file__).resolve().parents[1]/'data/growth/guardian_media.json';text=json.dumps(j,ensure_ascii=False,indent=2)+'\n'
    if a.check:assert p.read_text()==text
    else:p.write_text(text)
    print('GUARDIAN_ORIGINAL_MEDIA',j['pack'],len(j['frames']),'frames')
