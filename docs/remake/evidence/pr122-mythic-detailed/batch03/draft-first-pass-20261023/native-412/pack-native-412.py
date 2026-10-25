import sys,json,hashlib,subprocess,copy
from pathlib import Path
from PIL import Image
root=Path('/workspace/twilight');sys.path.insert(0,str(root/'tools'))
import stage_pr122_native_locomotion as stage
import import_original_based_motion as imp
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
versions=stage._analysis_versions(root)
code=root/'tools/stage_pr122_native_locomotion.py'
s=code.read_text();old="'transform:413': 'thunder_female_413'}";new="'transform:413': 'thunder_female_413', 'transform:412': 'transform_412'}"
assert old in s;code.write_text(s.replace(old,new,1));assert versions==stage._analysis_versions(root)
mp=root/stage.SOURCE_MANIFEST;m=json.loads(mp.read_text());original=copy.deepcopy(m)
base=root/'docs/remake/evidence/pr122-mythic-detailed/batch03'
out=base/'draft-first-pass-20261023/native-412';out.mkdir(exist_ok=True)
fresh={};holds=[];saved=[]
for src in sorted(base.glob('transform_412-*-draft-v01.png')):
 _,direction,role,*_=src.stem.split('-');dst=out/f'{direction}-{role}-native-v01.png'
 assert not dst.exists(),str(dst)
 image=Image.open(src).convert('RGBA');assert image.size==(1536,1024)
 packed=Image.new('RGBA',(1024,1536));hashes=[]
 for i in range(6):
  cell=image.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512));packed.paste(cell,((i%2)*512,(i//2)*512));hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
 packed.save(dst)
 check=Image.open(dst).convert('RGBA')
 assert hashes==[hashlib.sha256(check.crop(((i%2)*512,(i//2)*512,(i%2+1)*512,(i//2+1)*512)).tobytes()).hexdigest() for i in range(6)]
 try:
  geometry=imp.analyze(dst,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',canvas_size=1024,directions=[direction]);imp.require_complete_pose_regions(dst,geometry)
 except Exception as e:
  holds.append({'source':str(dst.relative_to(root)),'reason':str(e)[:500]});continue
 write(dst.with_suffix('.geometry.json'),geometry)
 source=str(dst.relative_to(root));record=dict(key='transform:412',direction=direction,role=role,version='native-v01',source=source,bytes=dst.stat().st_size,sha256=sha(dst),requested_poses=6,geometry=dict(status='GEOMETRY_PASS',frames=6,distinct_pixel_frames=6,canvas=1024),production_connected=False,detailed_completed=False,original_source=str(src.relative_to(root)),original_source_sha256=sha(src),lossless_cell_sha256=hashes,packing='3x2 to 2x3; unchanged RGBA cells and row-major order')
 m['raw_images'].append(record);selection='selected_locomotion_sheets' if role=='run' else 'selected_detailed_action_sheets';m[selection][f'transform:412:{direction}:{role}']=source
 m.setdefault('reviewed_runtime_layouts',{})[source]=dict(status='REVIEWED_LAYOUT_PROPOSAL',review_basis='Technical artboard-coordinate preservation only; visual anatomy, ground contact and runtime scale remain NOT_REVIEWED. Fixed cell anchors preserve authored vertical displacement instead of bottom-aligning every phase.',canvas_size=1024,source_sha256=sha(dst),direction=direction,source_anchors=[[512*(i%2)+256,512*(i//2)+512] for i in range(6)])
 fresh[source]=stage.preserved_source_analysis(root,record,geometry);saved.extend([source,str(dst.with_suffix('.geometry.json').relative_to(root))])
assert all(m[k].get(a)==b for k in ('selected_locomotion_sheets','selected_detailed_action_sheets','reviewed_runtime_layouts') for a,b in original[k].items())
write(out/'packing-summary.json',dict(actor='transform:412',geometry_pass=len(fresh),holds=holds,final_approved=0,Main_Player='NOT_RUN',analysis_versions_unchanged=True));write(mp,m)
subprocess.run(['git','add','-f','--',*saved,str((out/'packing-summary.json').relative_to(root))],cwd=root,check=True,stdout=subprocess.DEVNULL)
if fresh:stage.stage(root,'transform:412','native001',analyzed_sources=fresh)
print(json.dumps({'geometry_pass':len(fresh),'holds':len(holds),'final_approved':0}))
