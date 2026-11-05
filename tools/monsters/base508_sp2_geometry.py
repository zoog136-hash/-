"""Strict SP2 geometry parser without allocating per-pixel/blank-row Python lists.
Uses the supplied decoder's exact metadata/RLE rules and validates all color bytes.
"""
import struct
from original_sp2 import Reader,require

def candidate(raw,entries):
 r=Reader(raw);require(r.u('B')==254);r.u('B');palette=[r.u('H')for _ in range(entries)];mask=r.u('B');require(0<mask.bit_count()<=8);directions=[];colors=0
 for bit in range(8):
  if not mask&(1<<bit):continue
  frames=[]
  for f in range(r.u('B')):
   bounds=[r.u('h')for _ in range(4)];count=r.u('H');require(count<10000);aa=[r.u('b')for _ in range(count)];bb=[r.u('b')for _ in range(count)];types=list(r.read(count));ids=[];last=0
   for i in range(count):v=r.u('h');last=(v&65535)if i==0 else((last+v+1)&65535);ids.append(last)
   frames.append((bounds,list(zip(aa,bb,types,ids))))
  count=r.u('i');require(0<=count<1000000 and count*3<=len(raw)-r.p);blocks=[]
  for _ in range(count):
   bx,by,n=r.read(3);values=[r.u('H')for _ in range(n)];i=0;y=0;lo=None;hi=None
   while i<len(values):
    value=values[i];blank=value//1024-1 if value>2048 else 0;group=1
    if value>1024:value%=1024
    else:
     if i!=len(values)-1:group+=1
     k=0
     while k<10 and i+k+1<len(values)and i+k!=len(values)-1:
      if i+k+1==len(values)-1 or values[i+k+1]>1024:break
      group+=1;k+=1
    x=0
    for g in range(group):
     require(i<len(values))
     if g:value=values[i]%1024
     x+=value%32;pixels=value//32;colors+=pixels
     if pixels:
      lo=(x,y)if lo is None else(min(lo[0],x),min(lo[1],y));hi=(x+pixels-1,y)if hi is None else(max(hi[0],x+pixels-1),max(hi[1],y))
     x+=pixels;i+=1
    y+=1+blank
   box=()if lo is None else(lo[0],lo[1],hi[0],hi[1]);blocks.append([bx,by,(),(),box])
  for _,refs in frames:
   for a,b,t,index in refs:require(0<=index<len(blocks))
  directions.append((frames,blocks))
 require(r.p+colors==len(raw),(r.p,colors,len(raw),'exact color payload length'))
 if entries<256 and colors:require(max(memoryview(raw)[r.p:])<entries,'palette index')
 return palette,mask,directions,len(raw)
def parse(raw):
 require(len(raw)>=2 and raw[0]==254);marker=raw[1];options=[1,3]if marker==1 else[256 if marker==0 else marker];valid=[];errors=[]
 for entries in options:
  try:valid.append(candidate(raw,entries))
  except(ValueError,IndexError,struct.error)as e:errors.append(str(e))
 require(len(valid)==1,('SP2 geometry layouts passed',len(valid),marker,errors));return valid[0]
