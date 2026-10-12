"""Collect Godot captures of reused objects; never treat images as map completion."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/object-placement-20261011/evidence'

def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')

def sheet(phase,records,name,columns=4,width=400):
    height=round(width*720/1280)+26
    result=Image.new('RGB',(width*columns,height*((len(records)+columns-1)//columns)),'#13191f')
    draw=ImageDraw.Draw(result)
    for i,row in enumerate(records):
        pic=Image.open(OUT/phase/row['file']);pic.thumbnail((width,height-26))
        x,y=i%columns*width,i//columns*height
        draw.text((x+6,y+5),row['map_id']+' / '+row['label'],fill='#f0e3c5')
        result.paste(pic,(x+(width-pic.width)//2,y+26))
    result.save(OUT/name,quality=92)

def pair(row):
    result=Image.new('RGB',(1600,476),'#13191f');draw=ImageDraw.Draw(result)
    for i,phase in enumerate(['before','after']):
        pic=Image.open(OUT/phase/row['file']);pic.thumbnail((800,450))
        draw.text((i*800+8,5),row['map_id']+' / '+row['label']+' / '+phase,fill='#f0e3c5')
        result.paste(pic,(i*800,26))
    result.save(OUT/(row['file'].removesuffix('.jpg')+'-before-after.jpg'),quality=94)

def main():
    report=json.loads((ROOT/'data/maps/reference_object_placement.json').read_text())
    phases={phase:json.loads((OUT/phase/'captures.json').read_text()) for phase in ['before','after']}
    baseline={(r['map_id'],r['label']):r for r in phases['before']['captures']}
    captures=[]
    for phase,data in phases.items():
        assert data['engine'].startswith('4.7.2')
        assert len(data['captures'])==45
        for r in data['captures']:
            before=baseline[r['map_id'],r['label']]
            for key in ['position','zoom','camera_center']:assert r[key]==before[key],(r['file'],key)
            path=OUT/phase/r['file']
            captures.append({**r,'phase':phase,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    views=phases['after']['captures']
    towns=[r for r in views if r['map_id']=='aden_world' and r['label'] in
           ['gludio','kent','giran','aden','heine','oren','weldan','windawood','silver_knight','fire_village','elf_village']]
    for phase in phases:
        sheet(phase,towns,phase+'-towns.jpg',columns=3,width=480)
        sheet(phase,[r for r in views if r['label']=='whole'],phase+'-all-25-maps.jpg',columns=5,width=320)
    for r in views:
        if r['map_id'] in ['aden_world','oman_01']:pair(r)
    assets=[]
    for name in ['assets/maps/aden/props.png','assets/maps/reference_expansion_v2/props.png','assets/maps/aden/stone_cottage_v1.png']:
        path=ROOT/name
        assets.append({'path':name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'existing_project_art_reused_unchanged'})
    write(OUT/'manifest.json',{'baseline_sha':report['baseline_sha'],'new_art_files':0,'reused_assets':assets,
        'applied_maps':[r['map_id'] for r in report['maps']],'captures':captures,'same_camera_conditions_verified':True,
        'scope':'Two maps receive placements. All 25 rendered for regression; other 23 layouts are unchanged. Original object coordinates remain unverified.'})
    print('REFERENCE_OBJECT_EVIDENCE_OK',len(captures),'same-camera captures; 0 new art files')

if __name__=='__main__':main()
