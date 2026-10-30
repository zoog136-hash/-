from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
from scipy import ndimage
Image.MAX_IMAGE_PIXELS=None
b=Path('assets/maps/aden_world_draft');src=Path('/workspace/map-originals/Aden.png')
# Semantic coordinates only. No reference RGB is passed to the art compiler.
origin=(1967,369);size=(12040,7618);step=2
im=Image.open(src).convert('RGB').crop((*origin,origin[0]+size[0],origin[1]+size[1])).resize((6020,3809),Image.Resampling.BOX)
a=np.asarray(im).astype(np.float32);r,g,blue=a[:,:,0],a[:,:,1],a[:,:,2]
valid=ndimage.binary_fill_holes(ndimage.binary_closing(a.max(2)>18,iterations=1))
water=valid&(blue>r*1.17)&(g>r*1.12)&(blue>g*.92)&(blue>45)
water=ndimage.binary_closing(water,iterations=2)
vegetation=valid&~water&(g>r*1.015)&(g>blue*1.13)&(g>27)
forest=ndimage.uniform_filter(vegetation.astype(np.float32),size=7)>.37
snow=(a.min(2)>135)&((a.max(2)-a.min(2))<65)
# Labels: void/water/grass/soil/snow/mountain/sand/basalt/lava/marsh.
labels=np.full(valid.shape,3,dtype=np.uint8);labels[forest]=2
zones=[('snow',4,[(5650,1050),(6650,550),(7350,970),(8600,369),(10900,1530),(9700,2120),(8000,2100),(7100,1640)]),('volcano',7,[(6100,1300),(8000,1940),(6980,2560),(5450,2100)]),('mountain',5,[(5290,2200),(6410,2340),(6200,2920),(5460,3220),(5130,2910)]),('eastern_highland',5,[(10800,1510),(11700,1900),(11200,2390),(10100,2100)]),('desert',6,[(6700,4820),(8100,4730),(9000,5400),(8420,6100),(7410,6260),(6110,5590)]),('southern_desert',6,[(7400,6140),(10100,6980),(8280,7987),(6100,7000)]),('marsh_west',9,[(3650,4050),(4870,3880),(5940,4370),(5640,4920),(4520,4920),(3580,4450)])]
for name,code,poly in zones:
 mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon([((x-origin[0])/step,(y-origin[1])/step) for x,y in poly],fill=1);z=np.asarray(mask).astype(bool)&valid&~water
 if code==4:labels[z]=np.where(snow[z],4,5)
 elif code in (5,6,9):labels[z&~forest]=code
 else:
  labels[z]=7;labels[z&(r>g*1.5)&(r>90)]=8
labels[water&valid]=1;labels[~valid]=0
# Median cleans single-pixel color errors; labels remain semantic, not RGB art.
labels=ndimage.median_filter(labels,size=3);labels[~valid]=0
Image.fromarray(labels).save(b/'semantic_labels.png')
# Keep known gameplay corridors clear of decorative placement; never edit their data.
nav=json.load(open('data/maps/aden_faith_png_plan.json'))['maps']['aden_world']
blocked=Image.new('L',im.size);d=ImageDraw.Draw(blocked)
for poly in nav['walk_polygons']:d.polygon([((x-origin[0])/step,(y-origin[1])/step) for x,y in poly],fill=255)
protected=ndimage.maximum_filter(np.asarray(blocked),size=25)>0
for portal in nav['portals']:
 x,y=portal['position'];px,py=round((x-origin[0])/step),round((y-origin[1])/step)
 protected[max(0,py-20):py+21,max(0,px-20):px+21]=True
Image.fromarray(protected.astype('uint8')*255).save(b/'protected_placement_mask.png')
metadata={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'reference_origin':origin,'reference_size':size,'semantic_step_source_pixels':step,'world_bounds':[11802,2214,72240,45708],'classes':['void','water','grass','soil','snow','mountain','sand','basalt','lava','marsh'],'zones':[{'id':n,'class':c,'polygon_source':p} for n,c,p in zones],'status':'AUTOMATIC_SEMANTIC_DRAFT_NOT_COLLISION_DATA','limits':['classification can confuse roofs, cliffs, road details; visual review pending','source colors are converted only to class IDs; no original RGB goes to output'],'source_mask_counts':{str(i):int((labels==i).sum()) for i in range(10)}}
(b/'geography.json').write_text(json.dumps(metadata,indent=2)+'\n');print(metadata['source_mask_counts'])
