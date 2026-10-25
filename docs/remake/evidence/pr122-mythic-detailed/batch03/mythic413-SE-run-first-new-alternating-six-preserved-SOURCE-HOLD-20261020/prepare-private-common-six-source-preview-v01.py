from pathlib import Path
import sys,json,hashlib
from PIL import Image,ImageDraw
cp=Path(sys.argv[1]);c=json.loads(cp.read_text());D=cp.parent;fs=c['frames'];boxes=[r['stored_alpha_bbox']for r in fs]
box=[min(r[0]for r in boxes)-18,min(r[1]for r in boxes)-18,max(r[2]for r in boxes)+19,max(r[3]for r in boxes)+19]
board=Image.new('RGB',(1080,1000),'#3c4e60');dr=ImageDraw.Draw(board)
for i,r in enumerate(fs):
 im=Image.open(r['path']).crop(box);im.thumbnail((355,465));x=i%3*360;y=i//3*500;board.paste(im,(x+(355-im.width)//2,y+28),im);dr.text((x+5,y+8),str(i)+' '+r['name'],fill='white')
bp=D/('private-'+c['direction']+'-RUN-common-whole-six-source-v01.jpg');board.save(bp,quality=76);assert bp.stat().st_size<150000
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
r=dict(status='BOUNDED_PREVIEW_ONLY_ALL_SIX_SAME_STORED_CROP_NO_NATIVE_SOURCE_CHANGE',contract=pin(cp),preview=pin(bp),common_stored_crop=box,actual_source_PNGs=[{k:f[k]for k in['path','bytes','sha256']}for f in fs]);pp=bp.with_suffix('.json');pp.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['preview']|dict(common_crop=box,preview_provenance=str(pp))))
