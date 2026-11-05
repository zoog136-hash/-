"""Bounded classic legacy TIL container and RGB555 renderer (no resizing).

Reference: pinned PakViewer L1Til.cs. TIL type bit1 is a format selector, unlike
TI2 type bit6. A same numeric TileID does not imply equivalent source pixels.
"""
import struct,zlib
from PIL import Image
from base508_ti2 import decompress as brotli

def parse_raw(data):
 if not 8<=len(data)<=8*1024*1024:raise ValueError('TIL size')
 count,=struct.unpack_from('<I',data)
 if not 1<=count<=65536 or 8+count*4>len(data):raise ValueError('TIL offset table')
 offsets=list(struct.unpack_from('<'+'I'*count,data,4));end,=struct.unpack_from('<I',data,4+4*count);body=data[8+count*4:]
 if end>len(body) or any(x>end for x in offsets):raise ValueError('TIL offset outside body')
 unique=sorted(set(offsets+[end]));blocks={a:body[a:b] for a,b in zip(unique,unique[1:])};blocks[end]=b''
 return {'offsets':offsets,'end':end,'body':body,'blocks':[blocks[o] for o in offsets],'container_encoding':'RAW_LEGACY_TIL','pixel_encoding':'RGB555'}

def read_til(data):
 try:return parse_raw(data)
 except ValueError as raw_error:
  if len(data)>1 and data[0]&15==8 and (data[0]*256+data[1])%31==0:
   decoder=zlib.decompressobj();raw=decoder.decompress(data,8*1024*1024+1)
   if len(raw)>8*1024*1024 or not decoder.eof or decoder.unused_data:raise ValueError('TIL zlib boundary')
   encoding='ZLIB'
  else:
   try:raw=brotli(data);encoding='BROTLI'
   except ValueError:raise raw_error
  result=parse_raw(raw);result['container_encoding']=encoding;return result

def write_raw(tile):
 return struct.pack('<I',len(tile['offsets']))+struct.pack('<'+'I'*len(tile['offsets']),*tile['offsets'])+struct.pack('<I',tile['end'])+tile['body']

def render_til(block):
 image=Image.new('RGBA',(24,24))
 if not block:return image
 flag=block[0];at=1
 def take(n):
  nonlocal at
  if at+n>len(block):raise ValueError('TIL truncated RGB555/runs')
  b=block[at:at+n];at+=n;return b
 def paint(x,y):
  value,=struct.unpack('<H',take(2));r,g,b=(value>>10)&31,(value>>5)&31,value&31;alpha=255
  if flag&48:
   alpha=((31-max(r,g,b)) if flag&32 else max(r,g,b))*255//31
   if value in (0,0x421,0x7fff,0x7fe0) or alpha<8:alpha=0
  elif flag&4:alpha=128
  if 0<=x<24 and 0<=y<24:image.putpixel((x,y),(r*255//31,g*255//31,b*255//31,alpha))
 if not flag&2:
  if len(block) not in (577,578):raise ValueError('Non-classic or truncated TIL diamond; no silent cropping')
  widths=list(range(2,25,2))+list(range(22,-1,-2))
  for y,width in enumerate(widths):
   for x in range(width):paint(x+(0 if flag&1 else 24-width),y)
 else:
  x0,y0,width,height=take(4)
  if x0+width>24 or y0+height>24:raise ValueError('Non-classic TIL extent; no silent downscaling')
  for y in range(height):
   count,=take(1);x=x0
   for _ in range(count):
    skip,n=take(2)
    if skip%2:raise ValueError('Odd TIL RGB555 byte skip is unverified')
    x+=skip//2
    for _ in range(n):paint(x,y+y0);x+=1
 # Some original blocks include padding; retain it rather than assigning pixels.
 return image
