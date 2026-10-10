#!/usr/bin/env python3
"""SPX 48px-tile sprite converter, adapted to source format described by L1SPX.cs.
Reads original bytes as data, no executable/JAR execution. Includes bounds guards.
Outputs RGBA PNG, metadata (original offsets + frame types), and Godot4 SpriteFrames.

For very large sprites, use --max-source-bytes and --max-frames to constrain resource usage.
"""
from __future__ import annotations
import struct, io, json, sys, argparse, pathlib
from PIL import Image
import numpy as np

class SPXError(ValueError):pass

def decode_spx(data:bytes, max_pixels_per_frame:int=3000000, max_frames:int=254):
 n=len(data);pos=0
 def pull(fmt):
  nonlocal pos
  sz=struct.calcsize(fmt)
  if pos+sz>n:raise SPXError('truncated frame/header')
  out=struct.unpack_from(fmt,data,pos);pos+=sz;return out[0] if len(out)==1 else out
 count=pull('<B');palette=None
 if count==255:
  palette_count=pull('<B') or 256
  palette=[pull('<H') for _ in range(palette_count)]
  count=pull('<B')
 if count>max_frames:raise SPXError('too many frames')
 frames=[]
 for fi in range(count):
  x1,y1,x2,y2= pull('<hhhh');unk1,unk2=pull('<HH');nb=pull('<i')
  if not 0<=nb<=20000:raise SPXError('bad frame block count')
  defs=[]
  for _ in range(nb):
   a,b,typ,idx=pull('<bbBi');defs.append((a,b,typ,idx))
  frames.append({'index':fi,'source_rect':[x1,y1,x2,y2],'unknown':[unk1,unk2],'defs':defs,'type':defs[0][2] if defs else 0})
 nblocks=pull('<i')
 if not 0<=nblocks<=120000:raise SPXError('bad block count')
 offsets=[pull('<i') for _ in range(nblocks+1)]
 data_start=pos
 blocks_needed=set(idx for fr in frames for _a,_b,_t,idx in fr['defs'])
 if any(idx<0 or idx>=nblocks for idx in blocks_needed):raise SPXError('block ref OOB')
 if len(blocks_needed)>30000:raise SPXError('excessive referenced blocks')
 blocks={}
 for i in sorted(blocks_needed):
  loc=data_start+offsets[i]
  if loc<0 or loc+4>n:raise SPXError('block offset OOB')
  startx,starty,_unused,line_count=data[loc:loc+4];loc+=4
  if line_count>48:raise SPXError('block line count >48')
  arr=np.full((48,48),0x8000,dtype=np.uint16)
  for line in range(line_count):
   if loc>=n:raise SPXError('truncated seg count')
   seg_count=data[loc];loc+=1;x=startx
   if seg_count>48:raise SPXError('bad seg count')
   for _ in range(seg_count):
    if loc+2>n:raise SPXError('truncated seg')
    skip,ct=data[loc:loc+2];loc+=2;x+=skip//2
    width=(ct if x < 48 else 0)
    if palette is None:
     if loc+ct*2>n:raise SPXError('truncated color bytes')
     vals=np.frombuffer(data,dtype='<u2',count=ct,offset=loc);loc+=ct*2
    else:
     if loc+ct>n:raise SPXError('truncated palette index')
     vals=np.array([palette[inx] for inx in data[loc:loc+ct]],dtype=np.uint16);loc+=ct
    if starty+line<48 and x<48:
     visible=max(0,min(ct,48-x))
     if visible:arr[starty+line,x:x+visible]=vals[:visible]
    x+=ct
  blocks[i]=arr
 out=[]
 for fr in frames:
  defs=fr.pop('defs')
  if not defs:
   fr.update({'empty':True,'size':[0,0],'xy_offset':[0,0]});out.append((fr,None));continue
  placements=[]
  for a,b,t,idx in defs:
   adj=a-1 if a<0 else a;q=int(adj/2)  # matches C# truncation toward zero
   x=48*(b+a-q);y=24*(b-q)
   placements.append((x,y,idx))
  minx=min(x for x,y,j in placements);miny=min(y for x,y,j in placements)
  maxx=max(x+48 for x,y,j in placements);maxy=max(y+48 for x,y,j in placements)
  w=maxx-minx;h=maxy-miny
  if w<=0 or h<=0 or w*h>max_pixels_per_frame:raise SPXError(f'frame too large {w}x{h}')
  canvas=np.full((h,w),0x8000,dtype=np.uint16)
  for x,y,idx in placements:
   dst=canvas[y-miny:y-miny+48,x-minx:x-minx+48]
   blk=blocks[idx]
   np.copyto(dst,blk,where=blk!=0x8000)
  rgba=np.empty((h,w,4),dtype=np.uint8)
  # classic RGB555; 0x8000 is transparent in SPX base block data.
  rgba[:,:,0]=((canvas>>10)&31)*255//31
  rgba[:,:,1]=((canvas>>5)&31)*255//31
  rgba[:,:,2]=(canvas&31)*255//31
  rgba[:,:,3]=np.where(canvas==0x8000,0,255)
  fr.update({'empty':False,'size':[w,h],'xy_offset':[minx,miny],'opaque_pixels':int(np.count_nonzero(rgba[:,:,3]))})
  out.append((fr,Image.fromarray(rgba,'RGBA')))
 return out

def spriteframes_tres(frame_paths):
 ext=[];fr=[]
 for i,p in enumerate(frame_paths,1):
  ext.append(f'[ext_resource type="Texture2D" path="{p}" id="{i}"]')
  fr.append('{"duration": 1.0, "texture": ExtResource("'+str(i)+'")}')
 return ('[gd_resource type="SpriteFrames" load_steps='+str(len(fr)+2)+' format=3]\n\n'+'\n'.join(ext)+'\n\n[resource]\nanimations = [{"frames": ['+', '.join(fr)+'], "loop": true, "name": &"default", "speed": 8.0}]\n')

def export_one(blob, name, outroot, max_pixels=3000000):
 frames=decode_spx(blob,max_pixels)
 stem=pathlib.Path(name).stem
 outdir=outroot/stem;outdir.mkdir(parents=True,exist_ok=True)
 metadata=[];links=[]
 for i,(m,img) in enumerate(frames):
  if img is not None:
   fn=f'frame_{i:03}.png';img.save(outdir/fn)
   link=f'res://assets/l1j/candidates/spx_converted/{stem}/{fn}';m['path']=link;links.append(link)
  metadata.append(m)
 (outdir/'frames.json').write_text(json.dumps({'source':name,'frames':metadata},ensure_ascii=False,indent=2))
 if links:(outdir/'SpriteFrames.tres').write_text(spriteframes_tres(links))
 return {'name':name,'frames':len(frames),'decoded_png':len(links),'size':len(blob)}

if __name__=='__main__':
 import zipfile
 p=argparse.ArgumentParser();p.add_argument('--source',default='/mnt/data/a2(1).zip');p.add_argument('--out',default='/mnt/data/twilight_spx_test');p.add_argument('--take',type=int,default=5);a=p.parse_args()
 with zipfile.ZipFile(a.source) as src:
  with zipfile.ZipFile(io.BytesIO(src.read('appcenter/connector/patch/patch_1.zip'))) as z:
   names=[n for n in z.namelist() if n.endswith('.spx')]
   for name in names[:a.take]:
    try: print(export_one(z.read(name),name,pathlib.Path(a.out)),flush=True)
    except Exception as e:print('ERROR',name,str(e),flush=True)
