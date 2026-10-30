from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image,ImageDraw
B=Path('/workspace/scratch/mythic413-N-run-author-fresh-20261020-v01');D=Path(__file__).parent
p=B/'actual-six-native-articulation-v07/actual-N-run-six-source-contract-v07.json';d=json.loads(p.read_text());old=json.loads((B/'actual-six-native-articulation-v06/actual-N-run-six-source-contract-v06.json').read_text())
assert hashlib.sha256(p.read_bytes()).hexdigest()=='f2d4f7f1be5f0d068562edc4d4771763aa6830a40c954ab18e0e24ad4f8af812'
ims=[];checks=[]
for f,o in zip(d['frames'],old['frames']):
 q=Path(f['path']);im=Image.open(q).convert('RGBA');a=np.array(im);b=np.array(Image.open(o['path']).convert('RGBA'));z=np.any(a!=b,axis=2);yy,xx=np.where(z);assert hashlib.sha256(q.read_bytes()).hexdigest()==f['sha256'];box=im.getchannel('A').getbbox();ims.append(im)
 checks.append(dict(phase=f['phase'],source_sha256=f['sha256'],size=im.size,alpha_nonzero_bbox=list(box),v06_changed_pixels=int(z.sum()),v06_change_bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)] if len(xx) else None))
# Undo identical storage padding, keep one common raw crop and fixed scale.
unp=[im.crop((128,128,1408,1408)) for im in ims];boxes=[im.getchannel('A').getbbox() for im in unp];cb=(min(x[0] for x in boxes)-12,min(x[1] for x in boxes)-12,max(x[2] for x in boxes)+12,max(x[3] for x in boxes)+12)
for ids,name in [([5,0,1],'N-run-v07-private-fixed-root-seam5-contact0-load1.jpg'),([2,3,4],'N-run-v07-private-fixed-root-air2-contact3-load4.jpg')]:
 W,H=cb[2]-cb[0],cb[3]-cb[1];h=700;w=round(W*h/H);out=Image.new('RGB',(w*3,h+26),(220,220,220));draw=ImageDraw.Draw(out)
 for i,j in enumerate(ids):
  tile=Image.new('RGBA',(W,H),(220,220,220,255));tile.alpha_composite(unp[j].crop(cb));tile=tile.convert('RGB').resize((w,h),Image.Resampling.LANCZOS);out.paste(tile,(w*i,26));draw.text((w*i+4,4),f'{j} '+d['frames'][j]['name'],fill=(20,20,20))
 for quality in [82,76,68,60]:
  out.save(D/name,quality=quality)
  if (D/name).stat().st_size<=150000:break
 assert (D/name).stat().st_size<=150000
# Actual visible joint/calf/sole crops all six (same-scale, unpadded).
out=Image.new('RGB',(3*330,2*330),(220,220,220));draw=ImageDraw.Draw(out)
for j in range(6):
 c=(530,690,780,1015) if j in [1,4] else (530,550,780,875)
 tile=Image.new('RGBA',(250,325),(220,220,220,255));tile.alpha_composite(unp[j].crop(c));tile=tile.convert('RGB');out.paste(tile,(330*(j%3)+40,330*(j//3)+5));draw.text((330*(j%3)+3,330*(j//3)+3),str(j),fill=(20,20,20))
for quality in [85,78,70,62]:
 out.save(D/'N-run-v07-private-actual-calf-ankle-sole-six-ROIs.jpg',quality=quality)
 if (D/'N-run-v07-private-actual-calf-ankle-sole-six-ROIs.jpg').stat().st_size<=150000:break
report=dict(contract=str(p),contract_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),actual6_source_checks=checks,preview_common_unpadded_crop=cb,only_storage_undone=[128,128],actual_source_pixels_mutated=False,preview_names=[x.name for x in D.glob('*.jpg')]);(D/'N-run-v07-input-pins-and-preview-transform-proof-v01.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(status='PINNED',sources=checks,previews=[dict(name=x.name,bytes=x.stat().st_size) for x in D.glob('*.jpg')]),separators=(',',':')))
