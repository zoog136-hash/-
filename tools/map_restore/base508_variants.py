"""Select S32 geometry per exact source coordinate; preserve legacy variants apart.

All 15 inventoried SEG members also have a same-basename S32 in base508. They
are not necessarily equivalent and must never overwrite or overlay one another.
"""
import re
from collections import defaultdict
from pathlib import PurePosixPath

def unplaced_members(specs):
 return [s for s in specs if not re.fullmatch(r'[0-9a-fA-F]{8}\.(?:s32|seg)',PurePosixPath(s['member']).name)]

def inspect_unplaced_s32(data):
 # Validate bounded core structure without assigning a fabricated coordinate.
 from base508 import Reader
 r=Reader(data);r.take(32768);covers=r.count('H',6);r.take(covers*6);r.take(16384);groups=r.count('I',4)
 for _ in range(groups):
  _,parts=r.unpack('HH');r.take(parts*7)
 opacity=r.count('I',5);r.take(opacity*5);declared=r.count('I',4);r.take(declared*4)
 return {'bounded_core_structure_verified':True,'core_end':r.pos,'uninterpreted_tail_bytes':len(data)-r.pos,'origin':None,'placement':'UNRESOLVED_NONCANONICAL_FILENAME'}

def split_variants(specs):
 by_coordinate=defaultdict(list);unplaced={s['member'] for s in unplaced_members(specs)}
 for spec in specs:
  if spec['member'] not in unplaced:by_coordinate[str(PurePosixPath(spec['member']).with_suffix(''))].append(spec)
 primary=[];alternatives=[]
 for key,rows in sorted(by_coordinate.items()):
  s32=[r for r in rows if r['member'].endswith('.s32')]
  chosen=s32[0] if s32 else rows[0]
  primary.append(chosen);alternatives.extend(r for r in rows if r is not chosen)
 return primary,alternatives
