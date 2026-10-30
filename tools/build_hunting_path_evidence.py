"""Assemble unretouched Godot before/after viewports and physical map diagrams."""
import hashlib
import json
import subprocess
from html import escape
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/hunting-paths-20261012/evidence'
BASELINE='bab7ba5aa1a074bc1d37c6b2500e2c0fcd11bc91'


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')


def pair(record):
    name=record['file']
    result=Image.new('RGB',(1920,570),'#111820')
    draw=ImageDraw.Draw(result)
    for i,phase in enumerate(['before','after']):
        image=Image.open(OUT/phase/name)
        image.thumbnail((960,540))
        draw.text((i*960+10,8),record['map_id']+' / '+record['label']+' / '+phase,fill='#eee3c8')
        result.paste(image,(i*960,30))
    result.save(OUT/'pairs'/name,quality=94)


def sheet(phase,records,filename,columns=5,width=400):
    height=round(width*720/1280)+28
    result=Image.new('RGB',(columns*width,height*((len(records)+columns-1)//columns)),'#111820')
    draw=ImageDraw.Draw(result)
    for i,record in enumerate(records):
        x,y=i%columns*width,i//columns*height
        image=Image.open(OUT/phase/record['file'])
        image.thumbnail((width,height-28))
        draw.text((x+6,y+8),record['map_id']+' / '+phase,fill='#eee3c8')
        result.paste(image,(x,y+28))
    result.save(OUT/filename,quality=93)


def diagram(d,metric):
    """Use real collision footprints and the recorded CharacterBody2D walk."""
    w,h=d['bounds'][2:]
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="1280" height="{round(1280*h/w)}">',
         '<rect width="100%" height="100%" fill="#111820"/>']
    for p in d['navigable_polygons']:
        coords=' '.join(f'{x},{y}' for x,y in p)
        out.append(f'<polygon points="{coords}" fill="#64715e"/>')
    for c in d['collision']:
        new=c.get('placement_group')=='hunting_paths_v1'
        color='#d79b49' if c.get('hunting_lane') else ('#373741' if new else '#30313b')
        if c['shape']=='circle':
            x,y=c['center'];out.append(f'<circle cx="{x}" cy="{y}" r="{c["radius"]}" fill="{color}"/>')
        elif c['shape']=='rect':
            x,y,a,b=c['rect'];out.append(f'<rect x="{x}" y="{y}" width="{a}" height="{b}" fill="{color}"/>')
        else:
            coords=' '.join(f'{x},{y}' for x,y in c['points'])
            out.append(f'<polygon points="{coords}" fill="{color}"/>')
    for portal in d['portal']:
        x,y=portal['position'];out.append(f'<circle cx="{x}" cy="{y}" r="65" fill="#76e2df"><title>{escape(portal["id"])}</title></circle>')
    probe=metric.get('movement_probe',{})
    if probe:
        a,b=probe['from'],probe['to']
        out.append(f'<path d="M {a[0]} {a[1]} L {b[0]} {b[1]}" stroke="#e5a3b2" stroke-width="18" stroke-dasharray="35 20" fill="none"/>')
    coords=' '.join(f'{x},{y}' for x,y in metric.get('actual_walk_trace',[]))
    if coords:out.append(f'<polyline points="{coords}" stroke="#f0ff8b" stroke-width="23" fill="none"/>')
    out.append('</svg>')
    (OUT/'collision'/f'{d["map_id"]}.svg').write_text('\n'.join(out)+'\n')


def main():
    (OUT/'pairs').mkdir(parents=True,exist_ok=True)
    (OUT/'collision').mkdir(parents=True,exist_ok=True)
    phases={phase:json.loads((OUT/phase/'captures.json').read_text()) for phase in ['before','after']}
    baseline={(r['map_id'],r['label']):r for r in phases['before']['captures']}
    captures=[]
    for phase,data in phases.items():
        assert data['engine'].startswith('4.7.2') and len(data['captures'])==75
        for record in data['captures']:
            previous=baseline[record['map_id'],record['label']]
            for key in ['position','zoom','camera_center','camera_zoom']:assert record[key]==previous[key],(record['file'],key)
            p=OUT/phase/record['file'];assert Image.open(p).size==(1280,720)
            captures.append({**record,'phase':phase,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    views=phases['after']['captures']
    for record in views:pair(record)
    for phase in phases:
        for label in ['whole','hunting','boundary']:
            sheet(phase,[r for r in views if r['label']==label],phase+'-'+label+'-all-25.jpg')
    # Every tile is an actual viewport pair, so all 25 can be compared directly.
    selected=[r for r in views if r['label']=='hunting']
    comparison=Image.new('RGB',(2400,5*177),'#111820')
    labels=ImageDraw.Draw(comparison)
    for i,record in enumerate(selected):
        image=Image.open(OUT/'pairs'/record['file'])
        image.thumbnail((480,150))
        x,y=(i%5)*480,(i//5)*177
        labels.text((x+6,y+5),record['map_id']+' / before - after',fill='#eee3c8')
        comparison.paste(image,(x,y+25))
    comparison.save(OUT/'hunting-all-25-before-after.jpg',quality=94)
    validation=json.loads((OUT/'validation.json').read_text())
    assert not validation['failures'] and len(validation['maps'])==25
    metrics={m['map_id']:m for m in validation['maps']}
    index=json.loads((ROOT/'data/maps/field_index.json').read_text())
    paths=[ROOT/e['path'].removeprefix('res://') for e in index]
    preservation=[]
    for path in paths:
        d=json.loads(path.read_text())
        prior=json.loads(subprocess.check_output(['git','show',BASELINE+':'+path.relative_to(ROOT).as_posix()],cwd=ROOT))
        assert d['props'][:len(prior['props'])]==prior['props'],path
        for key in ['bounds','portal','npc_spawn','spawn_position','route_checks','regions','monster_spawn','roads','water','bridges']:
            assert d[key]==prior[key],(path,key)
        old_non_boundary=[c for c in prior['collision'] if c['kind'] not in ('cliff','dungeon_wall')]
        for c in old_non_boundary:assert c in d['collision'],(path,c)
        for c in prior['collision']:
            if c['kind']=='cliff' and d['map_id'] not in ['aden_world','domination_summit'] and d.get('family')!='escaros': assert c in d['collision']
        diagram(d,metrics[d['map_id']])
        preservation.append({'map_id':d['map_id'],'original_props_retained':len(prior['props']),
            'all_original_actor_and_travel_coordinates_unchanged':True,'actual_bounds_unchanged':True,
            'hunting_obstacles':metrics[d['map_id']]['physical_hunting_objects']})
    assets=[]
    for folder in ['assets/maps','assets/effects']:
        for path in sorted((ROOT/folder).rglob('*')):
            if path.is_file() and path.suffix not in ['.import','.uid']:
                rel=path.relative_to(ROOT).as_posix()
                old=subprocess.check_output(['git','show',BASELINE+':'+rel],cwd=ROOT)
                assert old==path.read_bytes(),rel
                if path.suffix in ['.png','.webp','.gdshader']:assets.append({'path':rel,'sha256':hashlib.sha256(old).hexdigest()})
    write(OUT/'manifest.json',{'baseline_sha':BASELINE,'new_art_files':0,'all_existing_map_art_and_shaders_unchanged':True,
        'same_camera_conditions_verified':True,'captures':captures,'map_preservation':preservation,'reused_assets':assets,
        'scope':'All 25 receive real object collision pathways and boundary geometry. Reference-style local placements; original exact maps and coordinates remain unverified.'})
    print('HUNTING_EVIDENCE_OK',len(captures),'same-camera captures;',len(preservation),'physically tested maps; 0 new art assets')


if __name__=='__main__':main()
