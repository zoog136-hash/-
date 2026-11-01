"""Two painted armor planes with changing occlusion, no chest-width morph.
The source key is newly authored; existing source sheets are never modified.
"""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageChops
R=Path(__file__).resolve().parents[2];D=R/'assets/actors/shared_skin_pilot/girtas_267/torso_occlusion';size=(427,495)
s=json.loads((R/'data/animation/girtas_shared_skin.json').read_text())['skin']
def read(p):return Image.open(R/p.removeprefix('res://')).convert('RGBA')
def mask(points):
 m=Image.new('L',size);ImageDraw.Draw(m).polygon(points,fill=255);return m
def cut(im,points):
 out=im.copy();out.putalpha(ImageChops.multiply(out.getchannel('A'),mask(points)));return out
def shifted(im,x,y):
 out=Image.new('RGBA',size);out.alpha_composite(im,(round(x),round(y)));return out
def path(p):return 'res://'+str(p.relative_to(R))
def save(im,p):
 # Keep transparent RGB clean without changing visible authored pixels.
 clear=Image.new('RGBA',size);clear.alpha_composite(im);clear.save(p)
old=read(s['parts']['torso']['texture']);guard=read(s['parts']['shoulder_armor']['texture'])
key=Image.open(D/'authored_source.png').convert('RGBA').resize(size,Image.Resampling.LANCZOS)
# Neck/head is not used. These masks select newly painted side armor and the
# forward-facing shoulder cap; its underlying chest/legs/weapon are discarded.
cap_poly=[(238,131),(258,116),(277,119),(297,132),(310,151),(313,172),(308,192),(291,202),(269,195),(249,179),(236,157)]
side_poly=[(245,155),(277,158),(300,180),(312,215),(312,246),(252,246),(229,216),(230,186)]
cap=cut(key,cap_poly);side=cut(key,side_poly)
# Fixed-size side plane sits behind the rigid original chest. It only fills the
# joint area uncovered by the forward-moving shoulder, never the outside spikes.
backing=shifted(side,-30,0);backing=cut(backing,[(193,143),(241,130),(270,153),(274,217),(249,239),(206,227),(191,191)])
save(cap,D/'forward_shoulder_plane.png');save(backing,D/'side_armor_plane.png')
frames=[]
for n in range(17):
 q=n/16;dx=40*q;dy=-12*q
 if n==0:
  frames.append({'q':q,'torso':s['parts']['torso']['texture'],'shoulder_armor':s['parts']['shoulder_armor']['texture'],'guard_pivot':[226,178],'near_offset':s['rig']['shoulder_offset'],'far_offset':[(351-304)*s['body_scale'],(195-235)*s['body_scale']]});continue
 torso=Image.new('RGBA',size);torso.alpha_composite(backing);torso.alpha_composite(old)
 # Both painted planes keep their dimensions. A moving opaque edge reveals the
 # cap's front face over its original rear face; it is not an opacity crossfade.
 base=shifted(guard,dx,dy)
 front=shifted(cap,dx-40,dy+12)
 reveal=Image.new('L',size);edge=round(315-95*q+dx-40);ImageDraw.Draw(reveal).rectangle((edge,0,426,494),fill=255)
 front.putalpha(ImageChops.multiply(front.getchannel('A'),reveal));base.alpha_composite(front)
 tp=D/'torso_01.png';gp=D/f'pauldron_{n:02}.png'
 if n==1:save(torso,tp)
 save(base,gp)
 near=[226+dx,178+dy];far=[351-12*q,195+2*q]
 frames.append({'q':q,'torso':path(tp),'shoulder_armor':path(gp),'guard_pivot':near,'near_offset':[(near[0]-304)*s['body_scale'],(near[1]-235)*s['body_scale']],'far_offset':[(far[0]-304)*s['body_scale'],(far[1]-235)*s['body_scale']]})
for f in frames:
 for k in ['torso','shoulder_armor']:f[k+'_sha256']=hashlib.sha256((R/f[k].removeprefix('res://')).read_bytes()).hexdigest()
meta={'schema':1,'direction':'E','method':'Rigid painted side/back armor and forward shoulder planes; moving opaque occlusion boundary; no torso mesh morph or crossfade','source_sha256':hashlib.sha256((D/'authored_source.png').read_bytes()).hexdigest(),'source_authorship':'New 2D pose, not original-game motion','cap_polygon':cap_poly,'side_polygon':side_poly,'original_source_sha256':s['source_sha256'],'frames':frames}
(R/'data/animation/girtas_torso_occlusion.json').write_text(json.dumps(meta,indent=2)+'\n')
print('Authored occlusion attachments saved; chest pixels and dimensions retained.')
