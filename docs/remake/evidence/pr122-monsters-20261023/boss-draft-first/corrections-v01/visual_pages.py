#!/usr/bin/env python3
"""Inspect changed source sheets only, with alpha composited for honest review."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
HERE=Path(__file__).resolve().parent
B=HERE.parent
ROOT=B.parents[4]
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--final',action='store_true');a=parser.parse_args()
    out=HERE/'visual-pages';out.mkdir(exist_ok=True)
    manifest=read(out/'manifest.json') if (out/'manifest.json').exists() else []
    seen={(x['slug'],x['clip']) for p in manifest for x in p['clips']}
    pending=[j for j in read(HERE/'queue.json')['jobs'] if (j['slug'],j['clip']) not in seen and (B/j['slug']/(j['clip']+'-receipt.json')).exists()]
    while len(pending)>=8 or (a.final and pending):
        group=pending[:8];pending=pending[8:];number=len(manifest)+1
        page=Image.new('RGB',(1536,2240),(55,60,63));draw=ImageDraw.Draw(page);records=[]
        for k,j in enumerate(group):
            rec=read(B/j['slug']/(j['clip']+'-receipt.json'));source=ROOT/rec['source'];assert sha(source)==rec['sha256']
            im=Image.open(source).convert('RGBA');im.thumbnail((752,510));tile=Image.new('RGBA',im.size,(66,71,75,255));tile.alpha_composite(im);x=k%2*768;y=k//2*560
            page.paste(tile.convert('RGB'),(x+(768-im.width)//2,y+32));draw.text((x+8,y+8),j['slug']+' '+j['clip'],fill='white')
            records.append(dict(slug=j['slug'],clip=j['clip'],source=rec['source'],source_sha256=rec['sha256'],corrects=j['corrects']))
        target=out/f'correction-{number:02}.jpg';assert not target.exists();page.save(target,quality=92)
        manifest.append(dict(number=number,path=target.relative_to(ROOT).as_posix(),sha256=sha(target),clips=records))
        (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(pages=len(manifest),sheets=sum(len(p['clips']) for p in manifest),awaiting_page=len(pending))))
if __name__=='__main__':main()
