from pathlib import Path
import copy,json,shutil,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
c=json.loads((root/'spider-candidate.json').read_text());actor='spider_project_batch16_authored'
r=core.import_sheet(repo,c,actor,[c['key']],False);folder=repo/'assets/actors/eight_direction/original_based'/actor
for p in folder.iterdir():
    if p.suffix in {'.png','.tres'}:assert core.sha(p)==core.sha(root/'Main-project/assets/actors/eight_direction/original_based'/actor/p.name)
portable=copy.deepcopy(c)
for i,s in enumerate(portable['sheets']):s['output_path']='res://'+str((folder/('poses-'+str(i)+'.png')).relative_to(repo))
(out/'spider-candidate.json').write_text(json.dumps(portable,ensure_ascii=False,indent=2)+'\n')
requests=[]
for name in ['spider-front-source-index.json','spider-back-source-index.json']:requests.extend(json.loads((root/name).read_text()))
(out/'spider-source-authoring-requests.json').write_text(json.dumps(requests,ensure_ascii=False,indent=2)+'\n')
(out/'spider-foot-observations.json').write_bytes((root/'spider-foot-observations.json').read_bytes())
rejected=out/'spider-preserved-unapproved';rejected.mkdir(exist_ok=True)
target=rejected/'spider-E_v02.png'
if not target.exists():shutil.copyfile(root/'spider-E_v02.png',target)
assert core.sha(target)==core.sha(root/'spider-E_v02.png')
(rejected/'status.json').write_text(json.dumps({'status':'HOLD_NOT_SELECTED','path':str(target.relative_to(repo)),'sha256':core.sha(target),'reason':'17 separated components instead of16; original E16 remains valid and selected. No threshold/ownership weakening.','completion_added':0},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(r,ensure_ascii=False))
