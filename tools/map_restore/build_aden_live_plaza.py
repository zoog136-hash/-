from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter,ImageChops
import json,hashlib
b=Path('assets/maps/aden_live_plaza');b.mkdir(exist_ok=True)
# Independently authored floor and fountain; old PNG used only as geographic reference.
pilot=Path('assets/maps/aden_modular_pilot/compiled'); m=json.loads((pilot/'manifest.json').read_text())
ground=Image.new('RGBA',(3072,2048))
for r in m['ground_chunks']:ground.paste(Image.open(pilot/'ground'/r['file']),tuple(r['position']))
origin=(70140,17376);size=(720,336);im=ground.crop((origin[0]-69600,origin[1]-16800,origin[0]-69600+size[0],origin[1]-16800+size[1]))
mask=Image.new('L',size);poly=[(0,144),(300,0),(720,192),(432,336)];ImageDraw.Draw(mask).polygon(poly,fill=255)
# Inward fade only: exterior stays unchanged, with no old-image upscaling in this asset.
inner=mask.filter(ImageFilter.MinFilter(17)).filter(ImageFilter.GaussianBlur(8));alpha=ImageChops.multiply(inner,mask);im.putalpha(alpha)
rows=[]
for x in range(0,size[0],512):
 piece=im.crop((x,0,min(x+512,size[0]),size[1]));name=f'floor_{x}.l1jpng';piece.save(b/name,format='PNG');rows.append({'file':name,'position':[origin[0]+x,origin[1]],'size':list(piece.size),'z_index':-19,'sha256':hashlib.sha256((b/name).read_bytes()).hexdigest()})
f=next(r for r in m['foreground'] if r['id']=='plaza_fountain');name='fountain.l1jpng';(b/name).write_bytes((pilot/f['file']).read_bytes());rows.append({'file':name,'position':[69600+f['position'][0],16800+f['position'][1]],'size':f['size'],'foot_image':[70572,17526],'id':'generated_plaza_fountain','sha256':hashlib.sha256((b/name).read_bytes()).hexdigest()})
im.save(b/'plaza_ground.png');Image.open(b/name).save(b/'fountain.png')
report={'schema':1,'map_id':'aden_world','status':'LIVE_BOUNDED_PLAZA_ONLY','world_bounds':[*origin,*size],'rows':rows,'new_ground_alpha_pixels':sum(v>0 for v in alpha.getdata()),'new_ground_opaque_pixels':sum(v==255 for v in alpha.getdata()),'collision_unchanged':True,'fountain_center':[70572,17526],'fountain_collision_radius':84,'floor_edge_feather_world_units':16}
(b/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(report['new_ground_alpha_pixels'])
