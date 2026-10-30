import sys,json,subprocess,hashlib
from pathlib import Path
import argparse
parser=argparse.ArgumentParser(description='Export the pinned forty NW hit clips into a read-only QA overlay.')
parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
parser.add_argument('--output',type=Path,required=True)
a=parser.parse_args();root=a.root.resolve();out=a.output.resolve()
out.mkdir()
def overlay(src,dst,opened):
 dst.mkdir(exist_ok=True)
 for p in src.iterdir():
  if p.name.startswith('.'):continue
  if p.name in opened:overlay(p,dst/p.name,opened[p.name])
  else:(dst/p.name).symlink_to(p,target_is_directory=p.is_dir())
overlay(root,out,{'assets':{'actors':{'eight_direction':{}}},'data':{}})
audit=json.load(open(root/'docs/remake/evidence/pr122-final-approval-20261025/legendary-batch/selected-metadata-audit.json'))
rows=[r for r in audit['rows'] if r['slot'][1:]==['NW','hit']];assert len(rows)==40
proc=subprocess.Popen(['git','cat-file','--batch'],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
pins={}
for row in rows:
 for path in [row['selected_frames'],*row['source_textures']]:
  path=path.removeprefix('res://')
  if path in pins:continue
  proc.stdin.write((audit['source_sha']+':'+path+'\n').encode());proc.stdin.flush();h=proc.stdout.readline().split();assert h[-1]!=b'missing'
  raw=proc.stdout.read(int(h[2]));proc.stdout.read(1);p=out/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw);pins[path]=hashlib.sha256(raw).hexdigest()
 assert pins[row['selected_frames'].removeprefix('res://')]==row['sha256']
proc.stdin.close();proc.wait()
(out/'data/pr158_hit_timing_batch.json').write_text(json.dumps({'source_sha':audit['source_sha'],'rows':rows,'pins':pins},indent=2)+'\n')
print('Exported',len(rows),'NW hit clips; source pixels unchanged')
