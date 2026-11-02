"""Falsifiable movement hypotheses; output is evidence and never runtime navigation."""
import argparse,base64,hashlib,json,struct
from collections import Counter
from pathlib import Path

def compare(root):
 m=json.loads((root/'map.json').read_text());cells={}
 for row in m['geometry']:
  data=(root/row['file']).read_bytes()
  if hashlib.sha256(data).hexdigest()!=row['sha256']:raise ValueError('geometry hash')
  chunk=json.loads(data);words=struct.unpack('<8192H',base64.b64decode(chunk['attribute_u16le']));ox,oy=chunk['origin']
  for y in range(64):
   for x in range(64):cells[ox+x,oy+y]=words[y*128+x*2:y*128+x*2+2]
 def edges(p,mask,blocked_set):
  x,y=p;out=[]
  # PC MapTool candidate: each cell owns the up/right edges, neighbors own down/left.
  for d,owner,half in [('up',(x,y),0),('down',(x,y+1),0),('left',(x-1,y),1),('right',(x,y),1)]:
   neighbor={'up':(x,y-1),'down':(x,y+1),'left':(x-1,y),'right':(x+1,y)}[d]
   if owner in cells and neighbor in cells and bool(cells[owner][half]&mask)!=blocked_set:out.append(d)
  return out
 hypotheses=[]
 portals=json.loads((root/m['portals_file']).read_text())
 for name,mask,blocked_set in [('PC_EDGE_BIT0_SET_BLOCKED',1,True),('INVERTED_EDGE_BIT0',1,False),('EDGE_BIT2_SET_BLOCKED',4,True)]:
  observations=[]
  for portal in portals:
   p=portal['SourceX'],portal['SourceY'];observations.append({'portal_id':portal['ID'],'source':p,'raw_words':cells.get(p),'candidate_outgoing_cardinal_edges':edges(p,mask,blocked_set)})
  degrees=Counter(len(edges(p,mask,blocked_set)) for p in cells)
  hypotheses.append({'name':name,'status':'UNVERIFIED_M_DO_NOT_ENABLE','candidate_cell_degree_counts':dict(sorted(degrees.items())),'portal_source_observations':observations,'falsifier_needed':'Original M successful/blocked step with exact source cell, direction, actor state and dynamic occupancy; portal anchor alone is insufficient.'})
 return {'schema':1,'land_id':m['land']['ID'],'cell_count':len(cells),'hypotheses':hypotheses,'height':{'status':'UNIDENTIFIED','reason':'Words 1/4/5 cannot identify elevation; no independent original height reference.'},'whole_cell_bit0_rejection':'Two halfwords can differ (4,5)/(5,4); dropping the other half or using a per-cell L1J byte loses directional evidence.','runtime_terrain_changes':0}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('pack',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.write_text(json.dumps(compare(a.pack),indent=2)+'\n')
