"""Lossless bounded legacy SEG core; byte attributes keep their own encoding.

Layout reference: pinned L1MapViewer SegParser.cs / segFileToBmp source. Cover
order is corrected from 24 actual base508 paired S32 cover observations.
No terrain or height semantics are assigned; uninterpreted tails are retained.
"""
import base64,hashlib,re,struct
from base508 import Reader,origin

class SegReader(Reader):
 def __init__(self,data):
  if not 24582<=len(data)<=8*1024*1024:raise ValueError('SEG bounded size')
  self.data,self.pos=data,0

def read_seg(data,member):
 if not re.fullmatch(r'[0-9a-fA-F]{8}\.seg',member.rsplit('/',1)[-1]):raise ValueError('SEG filename')
 r=SegReader(data)
 floor=r.take(16384);covers=[list(r.unpack('BBBB')) for _ in range(r.count('H',4))];attrs=r.take(8192)
 objects=[]
 for _ in range(r.count('I',4)):
  group,count=r.unpack('HH')
  if count>(len(data)-r.pos)//5:raise ValueError('SEG object count')
  objects.append({'group':group,'raw_parts':[list(r.unpack('BBBBB')) for _ in range(count)]})
 encode=lambda b:base64.b64encode(b).decode('ascii')
 refs=list(struct.unpack('<8192H',floor));normalized_covers=[[x,y,(tid<<8)|index] for x,y,index,tid in covers]
 normalized_objects=[{'group':g['group'],'parts':[[x,y,layer,(tid<<8)|index] for x,y,layer,index,tid in g['raw_parts']]} for g in objects]
 refs.extend(c[2] for c in normalized_covers);refs.extend(p[3] for g in normalized_objects for p in g['parts'])
 return {'schema':1,'edition':'LineageM_base508','source_format':'SEG','member':member,'origin':origin(member[:-4]+'.s32'),'source_sha256':hashlib.sha256(data).hexdigest(),'source_bytes':len(data),'seg_floor_u16le':encode(floor),'seg_covers_raw':covers,'seg_attribute_u8':encode(attrs),'seg_objects_raw':objects,'floor_u32le':encode(struct.pack('<8192I',*struct.unpack('<8192H',floor))),'covers':normalized_covers,'attribute_u16le':encode(struct.pack('<8192H',*attrs)),'attribute_encoding':'SEG_U8_HALF_CELL_VALUES_EXPANDED_LOSSLESSLY_TO_U16_STORAGE','objects':normalized_objects,'core_end':r.pos,'uninterpreted_tail':encode(data[r.pos:]),'tile_pairs':sorted([v>>8,v&255] for v in set(refs)),'terrain_collision':'UNKNOWN','height':'UNKNOWN','visual_semantics':'INDEPENDENT_LEGACY_VARIANT; NOT_EQUIVALENT_TO_PAIRED_S32; ENGINE_RULES_UNVERIFIED','cover_reference_order':'INDEX_BYTE_THEN_TILE_BYTE; VERIFIED_AGAINST_24_BASE508_PAIRED_S32_COVERS'}

def write_seg(row):
 decode=base64.b64decode;b=bytearray(decode(row['seg_floor_u16le']));b+=struct.pack('<H',len(row['seg_covers_raw']))
 for c in row['seg_covers_raw']:b+=bytes(c)
 b+=decode(row['seg_attribute_u8']);b+=struct.pack('<I',len(row['seg_objects_raw']))
 for g in row['seg_objects_raw']:
  b+=struct.pack('<HH',g['group'],len(g['raw_parts']))
  for p in g['raw_parts']:b+=bytes(p)
 b+=decode(row['uninterpreted_tail']);return bytes(b)
