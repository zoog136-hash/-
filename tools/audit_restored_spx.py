#!/usr/bin/env python3
"""Audit every restored source sequence, without treating layers as actors."""
import argparse, hashlib, json, pathlib
from collections import Counter
from PIL import Image, ImageDraw

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=pathlib.Path,required=True)
    p.add_argument('--out',type=pathlib.Path,required=True)
    a=p.parse_args(); a.out.mkdir(parents=True,exist_ok=True)
    source=a.root/'assets/l1j/candidates/spx_converted'
    rows=[]; errors=[]; prefixes=Counter(); frames=0
    for folder in sorted(source.iterdir()):
        meta_path=folder/'frame_metadata.json'
        if not meta_path.is_file(): continue
        meta=json.loads(meta_path.read_text()); unique=set(); prefixes[folder.name.split('-')[0]]+=1
        for frame in meta['frames']:
            path=a.root/frame['path'].removeprefix('res://')
            try:
                im=Image.open(path).convert('RGBA'); digest=hashlib.sha256(im.tobytes()).hexdigest()
                if list(im.size)!=meta['canvas_size']: errors.append(f'{folder.name}: canvas {frame["index"]}')
                if digest!=frame['pixel_sha256']: errors.append(f'{folder.name}: pixel digest {frame["index"]}')
                if list(im.getchannel('A').getbbox() or (0,0,0,0))!=list(frame.get('alpha_bbox') or (0,0,0,0)):
                    errors.append(f'{folder.name}: alpha bounds {frame["index"]}')
                unique.add(digest); frames+=1
            except (OSError, ValueError, KeyError) as exc:
                errors.append(f'{folder.name}: {exc}')
        rows.append({'sequence_id':folder.name,'frames':len(meta['frames']), 'distinct_frames':len(unique),
            'source_sha256':meta['source_sha256'],'source_origin':meta['source_origin'],
            'canvas_size':meta['canvas_size'],'semantic_status':'UNREVIEWED_SOURCE_SEQUENCE'})
    report={'sequences':len(rows),'png_frames':frames,'prefix_sequence_counts':dict(prefixes),
        'independent_reviewed_bodies':2,'body_ids':['21624','21653'],
        'shadow_ids':['21625','21654'],'effect_ids':['21626','21655'],
        'mask_light_ids':['21627','21656'],'errors':errors,'records':rows}
    (a.out/'all_sequences.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    for body in ('21624','21653'):
        for start in (0,13):
            cell=(144,160); sheet=Image.new('RGB',(cell[0]*7,cell[1]*13),(23,29,36)); draw=ImageDraw.Draw(sheet)
            for row,group in enumerate(range(start,start+13)):
                folder=source/f'{body}-{group*8+4}'
                meta=json.loads((folder/'frame_metadata.json').read_text())
                draw.text((8,row*cell[1]+7),f'{body}\nbase {group*8}\n{meta["frame_count"]} frames',fill=(240,240,240))
                for col in range(6):
                    i=round(col*(len(meta['frames'])-1)/5)
                    im=Image.open(a.root/meta['frames'][i]['path'].removeprefix('res://')).convert('RGBA')
                    im.thumbnail((cell[0],cell[1]-12),Image.Resampling.LANCZOS)
                    sheet.paste(im,((col+1)*cell[0]+(cell[0]-im.width)//2,row*cell[1]+12),im)
            sheet.save(a.out/f'{body}_actions_{start}.png')
    print('RESTORED_SPX_AUDIT',len(rows),frames,'errors',len(errors),flush=True)
    raise SystemExit(bool(errors))

if __name__=='__main__': main()
