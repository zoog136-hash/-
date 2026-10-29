import json,pathlib,numpy as np,gzip,hashlib
from PIL import Image,ImageDraw
from scipy import ndimage

def apply_variants(root,out,index):
 # Polygons are traced from each variant's own full-resolution inspection view.
 # They are local walk areas, never inferred original map IDs.
 polys={
  'source_variant_614_7786':{'focus':[32800,32864],'floor':[[120,350],[155,282],[345,225],[390,165],[500,138],[620,166],[760,195],[880,238],[930,290],[945,420],[905,505],[775,565],[640,615],[480,625],[330,570],[175,530],[140,465]],'holes':[[[490,350],[580,315],[680,350],[680,420],[590,450],[490,415]],[[310,450],[380,425],[450,460],[445,515],[380,540],[310,505]],[[715,270],[785,240],[860,270],[860,325],[785,355],[715,325]],[[177,248],[213,230],[250,250],[250,284],[212,300],[177,281]]]},
  'source_variant_614_7785':{'focus':[32832,32864],'floor':[[285,375],[350,340],[390,285],[500,263],[570,225],[680,215],[770,180],[865,145],[945,115],[1050,95],[1160,105],[1250,135],[1250,560],[1170,590],[1110,645],[965,645],[910,615],[820,595],[770,560],[690,552],[620,580],[550,585],[415,650],[140,650],[115,620],[190,560],[218,485],[280,440]],'holes':[]}
 }
 for x,y in [(373,387),(470,315),(565,282),(665,233),(793,400),(700,465),(604,516)]:polys['source_variant_614_7785']['holes'].append([[x-25,y],[x,y-15],[x+25,y],[x,y+15]])
 polys['source_variant_614_7785']['holes'] += [[[970,190],[1030,160],[1100,190],[1100,230],[1030,260],[970,230]],[[215,530],[280,495],[350,530],[350,575],[280,607],[215,575]]]
 polys['source_variant_7002_7785']=json.loads(json.dumps(polys['source_variant_614_7785']))
 def sig(m):return sorted((tuple(c['world_bounds']),tuple(c['position']),tuple(c['size']),c['sha256']) for c in m['chunks'])
 for mid,row in index['maps'].items():
  if not mid.startswith('source_variant_'):continue
  m=json.load(open(root/'maps'/(mid+'.json')));c=row['collision'];ox,oy=m['origin_source'];w,h=c['width'],c['height'];a=np.zeros((h,w),np.uint8)
  if mid=='source_variant_54_25':
   template=json.load(open(root/'maps/source_25.json'));assert sig(m)==sig(template)
   a=np.frombuffer(gzip.decompress((root/template['collision']['file']).read_bytes()),np.uint8).reshape(h,w).copy();row['geometry_policy']='exact all-chunk pixel/hash/coordinate proof against reference25; own stable ID, no source identity claim';row['entry_source']=[32809,32810]
  elif mid=='source_variant_4_0':
   template=json.load(open(root/'maps/aden_world.json'));raw=np.frombuffer(gzip.decompress((root/template['collision']['file']).read_bytes()),np.uint8).reshape(h,w)
   refs={tuple(v['world_bounds']):(tuple(v['position']),tuple(v['size']),v['sha256']) for v in template['chunks']};matched=[]
   for v in m['chunks']:
    b=v['world_bounds']
    if refs.get(tuple(b))==(tuple(v['position']),tuple(v['size']),v['sha256']):
     x0,y0,x1,y1=b;a[y0-oy:y1-oy+1,x0-ox:x1-ox+1]=raw[y0-oy:y1-oy+1,x0-ox:x1-ox+1];matched.append(b)
   # The inspected Giran landing is independently authored in this version.
   x,y=33430,32800;a[y-oy-5:y-oy+6,x-ox-5:x-ox+6]=3
   yy,xx=np.indices(a.shape);xx+=ox;yy+=oy
   a[(xx<32520)|(yy<32070)|((yy<32190)&(xx<33950))]=0
   floor=((a&3)!=0)&((a&128)==0)
   labels,count=ndimage.label(floor);sizes=np.bincount(labels.ravel());sizes[0]=0
   main=labels==int(sizes.argmax());interior=ndimage.binary_erosion(main)
   cy,cx=np.where(interior);score=(cx+ox-33430)**2+(cy+oy-32800)**2
   j=int(score.argmin());row['entry_source']=[int(cx[j]+ox),int(cy[j]+oy)]
   row['geometry_policy']='only145 coordinate-and-pixel-identical chunk footprints transferred as local geometry, plus inspected own Giran landing; unmatched terrain remains solid; no base source ID inheritance';row['pixel_identical_chunk_bounds']=matched
  else:
   design=polys[mid];mask=Image.new('L',(w,h));draw=ImageDraw.Draw(mask)
   def source(q):
    dx=(q[0]-640)*2;dy=(q[1]-360)*2
    return (design['focus'][0]+dx/48-dy/24-ox,design['focus'][1]+dx/48+dy/24-oy)
   draw.polygon([source(v) for v in design['floor']],fill=1)
   for hole in design['holes']:draw.polygon([source(v) for v in hole],fill=0)
   a[np.array(mask)!=0]=3;row['geometry_policy']='independent manual floor/island polygon trace from own variant pixels; lava, columns and altars excluded; no original topology claim';row['authored_polygons_screen']=design
   if mid.endswith('614_7786'):row['entry_source']=[32798,32875]
  b=a.tobytes();packed=gzip.compress(b,mtime=0);(out/c['file']).write_bytes(packed);c['sha256']=hashlib.sha256(packed).hexdigest();c['raw_sha256']=hashlib.sha256(b).hexdigest();c['basis']=row['geometry_policy'];row.pop('authored_floor_rectangle',None)
