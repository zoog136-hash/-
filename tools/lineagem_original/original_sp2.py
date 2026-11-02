"""SP2 decoder adapted from the user-supplied linm-sp2-evidence/decode.py.
Native pixels/offsets are retained. Marker1 layouts are distinguished by full
structure validation; cumulative references wrap at u16. This does not infer
SPR layer attributes, world origins or blending semantics.
"""
import struct
import brotli
from PIL import Image
def require(value, detail='Invalid SP2 structure'):
 if not value:raise ValueError(detail)

class Reader:
 def __init__(self,b):self.b=b;self.p=0
 def read(self,n):
  require(0<=n<=len(self.b)-self.p,(self.p,n,len(self.b)))
  v=self.b[self.p:self.p+n];self.p+=n;return v
 def u(self,f):return struct.unpack('<'+f,self.read(struct.calcsize('<'+f)))[0]
def _parse_candidate(b,entries):
 r=Reader(b);require(r.u('B')==254)
 n=r.u('B');n=entries
 pal=[r.u('H') for _ in range(n)]
 mask=r.u('B');nd=mask.bit_count()
 require(0<nd<=8)
 dirs=[]
 for d in range(nd):
  fs=[]
  for f in range(r.u('B')):
   bounds=[r.u('h') for _ in range(4)];n=r.u('H');require(n<10000)
   a=[r.u('b') for _ in range(n)];bb=[r.u('b') for _ in range(n)];ty=list(r.read(n));ids=[];last=0
   for i in range(n):
    v=r.u('h');last=(v&65535) if i==0 else ((last+v+1)&65535);ids.append(last)
   fs.append((bounds,list(zip(a,bb,ty,ids))))
  nb=r.u('i');require(0<=nb<1000000)
  bs=[]
  for _ in range(nb):
   x,y,n=r.read(3);vals=[r.u('H') for _ in range(n)];bs.append([x,y,vals])
  for bounds,refs in fs:
   for a,bb,t,idx in refs:require(0<=idx<len(bs),(idx,len(bs),'block reference'))
  dirs.append((fs,bs))
 for fs,bs in dirs:
  for block in bs:
   vals=block[2];i=0;rows=[]
   while i<len(vals):
    v=vals[i];blank=v//1024-1 if v>2048 else 0;group=1
    if v>1024:v%=1024
    else:
     if i!=len(vals)-1:group+=1
     k=0
     while k<10 and i+k+1<len(vals) and i+k!=len(vals)-1:
      if i+k+1==len(vals)-1 or vals[i+k+1]>1024:break
      group+=1;k+=1
    row=[];x=0
    for g in range(group):
     require(i<len(vals))
     if g:v=vals[i]%1024
     x+=v%32;count=v//32
     for c in r.read(count):
      require(c<len(pal))
      row.append((x,c));x+=1
     i+=1
    rows.append(row);rows.extend([[] for _ in range(blank)])
   block.append(rows)
 require(r.p==len(b),(r.p,len(b),'trailing'))
 return pal,mask,dirs,len(b)
def render(pal,fs,bs,f):
 bounds,refs=fs[f];points=[]
 for a,b,t,idx in refs:
  require(0<=idx<len(bs))
  bx,by,vals,rows=bs[idx];xx=24*(b+a-a//2)+bx;yy=12*(b-a//2)+by
  for y,row in enumerate(rows):
   for x,c in row:points.append((xx+x,yy+y,c))
 if not points:return Image.new('RGBA',(1,1)),(0,0)
 minx=min(x for x,y,c in points);miny=min(y for x,y,c in points)
 w=max(x for x,y,c in points)-minx+1;h=max(y for x,y,c in points)-miny+1
 require(0<w<4096 and 0<h<4096)
 im=Image.new('RGBA',(w,h));px=im.load()
 for x,y,c in points:
  p=pal[c];px[x-minx,y-miny]=((p>>11)*255//31,((p>>5)&63)*255//63,(p&31)*255//31,255)
 return im,(minx,miny)

def parse(raw):
 """Require an unambiguous complete layout, valid references and exact EOF."""
 if not raw:raise ValueError('empty SP2')
 if raw[0]!=254:
  decoder=brotli.Decompressor();parts=[];size=0
  for pos in range(0,len(raw),1024):
   part=decoder.process(raw[pos:pos+1024]);size+=len(part)
   if size>256*1024**2:raise ValueError('decoded SP2 exceeds 256MiB')
   parts.append(part)
  if not decoder.is_finished():raise ValueError('incomplete brotli')
  raw=b''.join(parts)
 if len(raw)<2 or raw[0]!=254:raise ValueError('not FE SP2')
 marker=raw[1];layouts=[1,3] if marker==1 else [256 if marker==0 else marker]
 results=[];errors=[]
 for entries in layouts:
  try:results.append(_parse_candidate(raw,entries))
  except (ValueError,IndexError,struct.error) as e:errors.append(str(e))
 if len(results)!=1:raise ValueError(f'SP2 layouts passed {len(results)}; marker {marker}; {errors}')
 return results[0]
