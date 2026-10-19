from pathlib import Path
import copy
import json
import shutil
import sys

repo=Path('/workspace/twilight');work=Path('/workspace/runtime/batch16')
out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
c=json.loads((work/'deer-candidate.json').read_text())
actor='albino_deer_batch16_authored'
result=core.import_sheet(repo,c,actor,[c['key']],False)
folder=repo/'assets/actors/eight_direction/original_based'/actor
for f in folder.iterdir():
    if f.suffix in {'.png','.tres'}:
        assert core.sha(f)==core.sha(work/'Main-project/assets/actors/eight_direction/original_based'/actor/f.name)
portable=copy.deepcopy(c)
for i,sheet in enumerate(portable['sheets']):
    sheet['output_path']='res://'+str((folder/('poses-'+str(i)+'.png')).relative_to(repo))
(out/'deer-candidate.json').write_text(json.dumps(portable,ensure_ascii=False,indent=2)+'\n')
requests=[]
for file in sorted(work.glob('deer-*-request.json')):
    requests.append({'request_path':file.name,'request':json.loads(file.read_text())})
(out/'deer-source-authoring-requests.json').write_text(json.dumps(requests,ensure_ascii=False,indent=2)+'\n')
rejected=out/'deer-preserved-unapproved';rejected.mkdir(exist_ok=True)
proof=[]
for version,reason in [('v01','Identity drift from broad source antlers'),('v02','Foreign-body rectangle overlap; unchanged importer rejected whole source')]:
    for file in sorted(work.glob('deer-attack-*-'+version+'.png')):
        target=rejected/file.name
        if target.exists():assert core.sha(target)==core.sha(file)
        else:shutil.copyfile(file,target)
        proof.append({'path':str(target.relative_to(repo)),'sha256':core.sha(target),'status':'UNAPPROVED_PRESERVED','reason':reason})
(out/'deer-unapproved-preservation.json').write_text(json.dumps({'completion_added':0,'files':proof},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
