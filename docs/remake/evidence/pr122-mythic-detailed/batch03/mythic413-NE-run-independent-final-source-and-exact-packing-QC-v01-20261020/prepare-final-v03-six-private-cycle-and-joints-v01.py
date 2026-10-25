from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,numpy as np
D=Path(__file__).parent;B=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/actual-NE-run-six-common-material-finish-v03');p=B/'NE-run-common-finished-six-actual-source-roster-v03.json';r=json.loads(p.read_text());assert hashlib.sha256(p.read_bytes()).hexdigest()=='64cfc1d121ad9e63619cfeb0ef07aae2fae194083a7085812e199f8a6fe5d850';o=json.loads(Path(r['exact_original_physical_rig']['path']).read_text());ims=[];checks=[]
for f,g in zip(r['frames'],o['frames']):
 q=Path(f['source']['path']);assert hashlib.sha256(q.read_bytes()).hexdigest()==f['source']['sha256'];assert f['joint_controls_and_shoes']==g['legs'];assert f['body_node_XYZ']==g['body_node_XYZ'];assert f['C']==2432 and f['bodyunit']==2.375;im=Image.open(q).convert('RGBA');a=np.array(im);assert im.size==(1536,1536);assert not np.any(a[[0,-1],:,3]>0) and not np.any(a[:,[0,-1],3]>0);ims.append(im);checks.append(dict(phase=f['phase'],source_sha256=f['source']['sha256'],source_bytes=q.stat().st_size,unchanged_all_1c1717_leg_and_shoe_controls=True,no_alpha_positive_source_canvas_edge_clipping=True))
raw=[im.crop((128,128,1408,1408))for im in ims];boxes=[]
for im in raw:
 a=np.array(im);yy,xx=np.where(a[:,:,3]>16);boxes.append([int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)])
cb=(min(x[0]for x in boxes)-12,min(x[1]for x in boxes)-12,max(x[2]for x in boxes)+12,max(x[3]for x in boxes)+12)
for ids,name in [([5,0,1],'NE-run-v03-private-fixed-root-seam5-contact0-load1.jpg'),([2,3,4],'NE-run-v03-private-fixed-root-air2-contact3-load4.jpg')]:
 w,h=cb[2]-cb[0],cb[3]-cb[1];height=760;width=round(w*height/h);out=Image.new('RGB',(width*3,height+26),(225,225,225));dr=ImageDraw.Draw(out)
 for j,i in enumerate(ids):
  tile=Image.new('RGBA',(w,h),(225,225,225,255));tile.alpha_composite(raw[i].crop(cb));out.paste(tile.convert('RGB').resize((width,height),Image.Resampling.LANCZOS),(j*width,26));dr.text((j*width+4,4),f'{i} '+r['frames'][i]['role'],fill='black')
 for qual in [86,80,74,68,60]:
  out.save(D/name,quality=qual)
  if(D/name).stat().st_size<150000:break
 assert(D/name).stat().st_size<150000
# All ten NEW phase1..5 tarsal attachments in actual source at native preview scale.
out=Image.new('RGB',(5*160,2*185),(225,225,225));dr=ImageDraw.Draw(out)
for i in range(1,6):
 for j,side in enumerate(['R','L']):
  x,y=r['frames'][i]['joint_controls_and_shoes'][side]['actual_joint_controls_unpadded'][2];rect=(round(x)-75,round(y)-80,round(x)+75,round(y)+85);tile=Image.new('RGBA',(150,165),(225,225,225,255));tile.alpha_composite(raw[i].crop(rect));out.paste(tile.convert('RGB'),((i-1)*160,j*185+20));dr.text(((i-1)*160+3,j*185+3),f'{i} {side} A',fill='black')
pv=D/'NE-run-v03-private-remaining-ten-actual-tarsal-joints.jpg';out.save(pv,quality=90);assert pv.stat().st_size<150000
report=dict(roster_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),source_checks=checks,preview_common_raw_crop=cb,one_common_preview_scale=True,storage_only_undone=[128,128],source_pixels_mutated=False)
p=D/'NE-run-v03-final-six-source-pins-and-private-preview-transform-v01.json';p.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(checks=len(checks),all_same_controls=True,no_edge_clipping=True,previews=[dict(name=(D/n).name,bytes=(D/n).stat().st_size)for n in ['NE-run-v03-private-fixed-root-seam5-contact0-load1.jpg','NE-run-v03-private-fixed-root-air2-contact3-load4.jpg','NE-run-v03-private-remaining-ten-actual-tarsal-joints.jpg']])))
