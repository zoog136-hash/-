#!/usr/bin/env python3
"""Generate original 2D dungeon flagstones: no proprietary tile images included."""
import math, random, struct, zlib
from pathlib import Path
W,H,NX,NY=96,48,8,4

def generate(target):
    target=Path(target)
    target.parent.mkdir(parents=True,exist_ok=True)
    width,height=W*NX,H*NY
    pixels=bytearray(width*height*4)
    def distance(px,py,p,q):
        dx=q[0]-p[0];dy=q[1]-p[1];u=dx*dx+dy*dy
        t=max(0,min(1,((px-p[0])*dx+(py-p[1])*dy)/max(1,u)))
        return math.hypot(px-p[0]-t*dx,py-p[1]-t*dy)
    for tile in range(32):
        rng=random.Random(101024+tile*7331)
        breaks=[]
        for _ in range(rng.randint(2,5)):
            a=(rng.randint(6,36),rng.randint(3,22))
            b=(rng.randint(50,91),rng.randint(18,45))
            mid=((a[0]+b[0])*.5+rng.randint(-13,13),(a[1]+b[1])*.5+rng.randint(-10,10))
            breaks.extend([(a,mid),(mid,b)])
        ox=(tile%NX)*W;oy=(tile//NX)*H
        for y in range(H):
            for x in range(W):
                v=abs((x-47.5)/47.5)+abs((y-23.5)/23.5)
                if v>1:continue
                grit=math.sin((x+tile*11)*.47+(y+tile)*.38)*5+math.sin(x*.17+y*.14+tile*9)*6
                grit+=rng.randint(-10,10)
                color=[54+grit,53+grit,48+grit*.8]
                if v>.90:color=[t-7 for t in color]
                d=min(distance(x,y,a,b) for a,b in breaks)
                if d<1:color=[t*.48 for t in color]
                elif d<2.2:color=[t*.82 for t in color]
                pos=((oy+y)*width+ox+x)*4
                pixels[pos:pos+4]=bytes([*(max(2,min(254,int(z))) for z in color),255])
    def chunk(key,data):
        return struct.pack('>I',len(data))+key+data+struct.pack('>I',zlib.crc32(key+data)&0xffffffff)
    rows=b''.join(b'\0'+pixels[y*width*4:(y+1)*width*4] for y in range(height))
    image=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b'')
    target.write_bytes(image)
    return len(image)

if __name__=='__main__':
    import sys
    print(generate(sys.argv[1]))
