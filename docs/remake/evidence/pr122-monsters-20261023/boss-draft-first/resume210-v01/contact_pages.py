#!/usr/bin/env python3
"""Pinned whole-sheet previews for the single post-draft visual pass.

Alpha is composited over a neutral background. Every supplied source pose is
shown, including structurally held sheets; a failed crop is never hidden.
"""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

HERE=Path(__file__).resolve().parent
PRODUCTION=HERE.parent
ROOT=PRODUCTION.parents[4]
ORDER=['E','SE','S','SW','W','NW','N','NE']

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    review=HERE/'whole-review-v01'
    inventory=json.loads((review/'structural-inventory.json').read_text())
    assert inventory['summary']['fully_authored_first_pass']
    out=review/'visual-pages';out.mkdir(exist_ok=True)
    assert not (out/'manifest.json').exists(),'This whole visual pass is already prepared'
    grouped=defaultdict(list)
    for row in inventory['clips']:grouped[(row['slug'],row['role'])].append(row)
    pages=[]
    for (slug,role),rows in grouped.items():
        rows.sort(key=lambda r:ORDER.index(r['direction']))
        tilew,tileh=768,710
        image=Image.new('RGB',(tilew*2,tileh*((len(rows)+1)//2)+48),(58,62,65))
        draw=ImageDraw.Draw(image)
        draw.text((16,12),f'{slug}  {role.upper()}  | all six original phases per source; fixed camera',fill='white')
        sources=[]
        for index,row in enumerate(rows):
            source=ROOT/row['source'];assert sha(source)==row['source_sha256']
            shown=source;status=row['status']
            proof=review/'owned-parts-repair'/slug/(row['clip']+'.json')
            if proof.exists():
                repaired=json.loads(proof.read_text())
                if repaired['status']=='LOSSLESS_OWNED_PARTS_PASS':
                    assert repaired['source_sha256']==row['source_sha256']
                    shown=ROOT/repaired['texture'];assert sha(shown)==repaired['texture_sha256']
                    status='LOSSLESS_OWNED_PARTS_FIXED'
            original=Image.open(shown).convert('RGBA')
            background=Image.new('RGBA',original.size,(66,70,73,255));background.alpha_composite(original)
            background.thumbnail((tilew-16,502),Image.Resampling.LANCZOS)
            x=tilew*(index%2)+(tilew-background.width)//2;y=48+tileh*(index//2)
            image.paste(background.convert('RGB'),(x,y+26))
            draw.text((tilew*(index%2)+12,y+5),row['direction']+'  '+row['clip']+'  '+status,fill='white')
            native=[]
            pattern=f'{role}-{row["direction"]}-action-*.png'
            for capture in (HERE/'minimum-batches').glob('*/runtime/*/captures/'+pattern):
                if capture.parent.parent.name not in (slug,slug+'_'+role):continue
                if not capture.stem.rsplit('-',1)[-1].isdigit():continue
                native.append(capture)
            native.sort(key=lambda p:int(p.stem.rsplit('-',1)[-1]))
            # Existing normal-speed viewport captures are reused, not replayed.
            # Include the visible game floor and root marker beneath every pose.
            for phase,capture in enumerate(native[:6]):
                scene=Image.open(capture).convert('RGB').crop((320,160,640,480))
                scene.thumbnail((128,128),Image.Resampling.LANCZOS)
                image.paste(scene,(tilew*(index%2)+128*phase,y+560))
            draw.text((tilew*(index%2)+12,y+539),f'Godot normal speed: {len(native[:6])}/6 existing frame captures' if native else 'Native playback pending grouped source-geometry repair',fill=(210,220,225))
            sources.append(dict(source=row['source'],sha256=row['source_sha256'],clip=row['clip'],direction=row['direction'],display_texture=shown.relative_to(ROOT).as_posix(),display_texture_sha256=sha(shown),status=status,native_previews=[dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in native[:6]]))
        path=out/(slug+'-'+role+'.jpg')
        if path.exists():
            # Resume the same preparation after a failed page, preserving all
            # completed previews and native playback rather than repeating them.
            with Image.open(path) as saved:
                assert saved.size==image.size
                saved.verify()
        else:image.save(path,quality=94)
        pages.append(dict(slug=slug,role=role,path=path.relative_to(ROOT).as_posix(),sha256=sha(path),sources=sources))
    manifest=dict(source_sheets=sum(len(p['sources']) for p in pages),source_poses=6*sum(len(p['sources']) for p in pages),whole_visual_review='AWAITING_INSPECTION',pages=pages)
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(pages=len(pages),source_sheets=manifest['source_sheets'],source_poses=manifest['source_poses'])))
if __name__=='__main__':main()
