from pathlib import Path
import copy,json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
c=json.loads((root/'tomb-repaired-candidate.json').read_text());actor='tomb_guardian269_batch16_repaired'
r=core.import_mixed_sources(repo,c,actor,[c['key']],False)
dest=repo/'assets/actors/eight_direction/original_based'/actor;test=root/'Main-project/assets/actors/eight_direction/original_based'/actor
for p in dest.iterdir():
    if p.suffix in {'.png','.tres'}:assert core.sha(p)==core.sha(test/p.name)
proof=json.loads((dest/'provenance.json').read_text())
portable=copy.deepcopy(c)
by_sha={s['sha256']:s['path'] for s in proof['source_files']}
for spec in portable['sheets']+portable['pose_files']:
    digest=core.sha(core.candidate_image(repo,spec['output_path']))
    spec['output_path']=by_sha[digest]
(out/'tomb-repaired-candidate.json').write_text(json.dumps(portable,ensure_ascii=False,indent=2)+'\n')
receipts={}
for name in ['tomb-base-restore.json','tomb-delta-restore.json','restored-batch03-restore-proof.json']:
    receipts[name]=json.loads((root/name).read_text())
(out/'tomb-source-restoration.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
requests=[json.loads(p.read_text()) for p in sorted(root.glob('tomb-NE-walk*-request.json'))]
(out/'tomb-palette-authoring-requests.json').write_text(json.dumps(requests,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(r,ensure_ascii=False))
