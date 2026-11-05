"""Verify row-major RGBA from bounded sparse chunks, without a full-map image."""
import hashlib,math,tempfile
from pathlib import Path
from PIL import Image

def pixel_digest(root,art,edge=1024):
 if not 24<=edge<=1024:raise ValueError('Invalid bounded raster edge')
 root=Path(root);width,height=art['size'];nx,ny=math.ceil(width/edge),math.ceil(height/edge);indexed={};digest=hashlib.sha256()
 for row in art['chunks']:
  x,y=row['position'];w,h=row['size']
  if x<0 or y<0 or x%edge or y%edge or (w,h)!=(min(edge,width-x),min(edge,height-y)):raise ValueError('Invalid raster chunk grid')
  key=x//edge,y//edge
  if key in indexed:raise ValueError('Duplicate raster chunk position')
  indexed[key]=row
 with tempfile.TemporaryDirectory(prefix='verify-raster-',dir=root.parent) as work:
  for by in range(ny):
   opened={};h=min(edge,height-by*edge)
   for bx in range(nx):
    row=indexed.get((bx,by))
    if row is None:continue
    with Image.open(root/row['file']) as image:
     if image.mode not in ('RGB','RGBA') or list(image.size)!=row['size']:raise ValueError('Raster chunk mode/extent')
     image=image.convert('RGBA')
     path=Path(work)/str(bx);path.write_bytes(image.tobytes());opened[bx]=path.open('rb')
   for _ in range(h):
    for bx in range(nx):
     size=min(edge,width-bx*edge)*4;digest.update(opened[bx].read(size) if bx in opened else bytes(size))
   for bx,handle in opened.items():handle.close();(Path(work)/str(bx)).unlink()
 return digest.hexdigest()
