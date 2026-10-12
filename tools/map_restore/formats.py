"""Lossless S32 layers, source-coordinate projection and verified A3 edge rules.
References: supplied L1MapViewer CLI/S32Parser.cs, S32Writer.cs, Other/Struct.cs;
A3 L1V1Map.checkMoveTile. Version-specific EOF after layer 6 is preserved.
"""
import base64
import hashlib
import re
import struct
import numpy as np

def sha(data): return hashlib.sha256(data).hexdigest()
def origin(name):
    stem=name.rsplit('/',1)[-1].split('.')[0]
    if not re.fullmatch(r'[0-9a-fA-F]{8}(?:_\d+)?',stem): return None
    return [(int(stem[i:i+4],16)-0x7fff)*64+0x7fc0 for i in (0,4)]

class Reader:
    def __init__(self,data): self.data,self.pos=data,0
    def take(self,n):
        if n<0 or self.pos+n>len(self.data): raise ValueError(f'Truncated S32 at {self.pos}')
        b=self.data[self.pos:self.pos+n];self.pos+=n;return b
    def unpack(self,fmt):
        r=struct.unpack(fmt,self.take(struct.calcsize(fmt)));return r[0] if len(r)==1 else list(r)
    def count(self,fmt,size):
        n=self.unpack(fmt)
        if n<0 or n>(len(self.data)-self.pos)//size: raise ValueError(f'Invalid S32 count {n} at {self.pos}')
        return n

def read_s32(data,name):
    r=Reader(data)
    floor=r.take(32768)
    covers=[r.unpack('<BBBHB') for _ in range(r.count('<H',6))]
    attrs=r.take(16384)
    objects=[]
    for _ in range(r.count('<i',4)):
        ident=r.unpack('<h'); tiles=[r.unpack('<BBBBhB') for _ in range(r.count('<H',7))]
        objects.append({'id':ident,'tiles':tiles})
    opacity=[]; used=[]; portals=[]; effects=[]; extended=False
    optional=0
    if r.pos<len(data):
        opacity=[list(r.take(5)) for _ in range(r.count('<i',5))];optional=5
    if r.pos<len(data):
        used=[r.unpack('<i') for _ in range(r.count('<i',4))];optional=6
    if r.pos<len(data):
        for _ in range(r.count('<H',9)):
            label=r.take(r.unpack('<B')); x,y,target,ident=r.unpack('<BBHi')
            portals.append({'name_bytes':base64.b64encode(label).decode(),'x':x,'y':y,'target_map_id':target,'portal_id':ident})
        optional=7
    if r.pos<len(data):
        count=r.unpack('<H');extended=bool(count&0x8000);count&=0x7fff
        effects=[r.unpack('<HHHi' if extended else '<HHH') for _ in range(count)];optional=8
    pairs={(struct.unpack_from('<H',floor,i+1)[0],floor[i]) for i in range(0,len(floor),4)}
    pairs.update((c[3],c[2]) for c in covers)
    pairs.update((b[4]&65535,b[3]) for o in objects for b in o['tiles'])
    return {'schema':1,'origin':origin(name),'source_sha256':sha(data),'source_size':len(data),
        'floor_bytes':base64.b64encode(floor).decode(),'attribute_bytes':base64.b64encode(attrs).decode(),
        'covers':covers,'objects':objects,'opacity_raw':opacity,'used_tile_ids':used,'portals':portals,
        'effects':effects,'effects_extended':extended,'optional_through':optional,
        'tail_bytes':base64.b64encode(r.take(len(data)-r.pos)).decode(),'tile_pairs':sorted(pairs),
        'counts':{'floor':8192,'covers':len(covers),'attribute_cells':4096,'groups':len(objects),
        'objects':sum(len(o['tiles']) for o in objects),'opacity':len(opacity),'portals':len(portals),'effects':len(effects)}}

def write_s32(p):
    b=bytearray(base64.b64decode(p['floor_bytes']));b+=struct.pack('<H',len(p['covers']))
    for row in p['covers']: b+=struct.pack('<BBBHB',*row)
    b+=base64.b64decode(p['attribute_bytes']);b+=struct.pack('<i',len(p['objects']))
    for o in p['objects']:
        b+=struct.pack('<hH',o['id'],len(o['tiles']))
        for row in o['tiles']: b+=struct.pack('<BBBBhB',*row)
    through=p['optional_through']
    if through>=5:
        b+=struct.pack('<i',len(p['opacity_raw']))
        for row in p['opacity_raw']: b+=bytes(row)
    if through>=6:
        b+=struct.pack('<i',len(p['used_tile_ids']))
        for tile in p['used_tile_ids']: b+=struct.pack('<i',tile)
    if through>=7:
        b+=struct.pack('<H',len(p['portals']))
        for row in p['portals']:
            label=base64.b64decode(row['name_bytes']);b+=bytes([len(label)])+label+struct.pack('<BBHi',row['x'],row['y'],row['target_map_id'],row['portal_id'])
    if through>=8:
        b+=struct.pack('<H',len(p['effects'])|(0x8000 if p['effects_extended'] else 0))
        for row in p['effects']: b+=struct.pack('<HHHi' if p['effects_extended'] else '<HHH',*row)
    return bytes(b)+base64.b64decode(p['tail_bytes'])

def move_masks(grid):
    h,w=grid.shape; pad=np.pad(grid,1)
    def at(dx,dy): return pad[1+dy:1+dy+h,1+dx:1+dx+w]
    a=grid;n,e,s,west=at(0,-1),at(1,0),at(0,1),at(-1,0)
    sw,nw,se=at(-1,1),at(-1,-1),at(1,1)
    one=lambda v:(v&1)!=0;two=lambda v:(v&2)!=0
    rules=[two(a),(two(a)&one(n))|(one(a)&two(e)),one(a),((s&3)==3)|(one(a)&two(se)),
           two(s),(one(sw)&two(s))|(two(sw)&one(west)),one(west),((west&3)==3)|(two(a)&one(nw))]
    result=np.zeros_like(grid)
    for heading,((dx,dy),r) in enumerate(zip([(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1)],rules)):
        r=r.copy()
        if dx<0:r[:,0]=False
        if dx>0:r[:,-1]=False
        if dy<0:r[0,:]=False
        if dy>0:r[-1,:]=False
        result|=r.astype(np.uint8)<<heading
    return result
