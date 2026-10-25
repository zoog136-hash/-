from pathlib import Path
import json,hashlib,subprocess
L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');B=L/'retained-profile-tools-policy-synced-v02';proof=L/'S-death-new-actual-six-lossless-2304/S-death-actual-six-fixed-C-floor-and-lossless-storage-proof.json';j=json.loads(proof.read_text());assert j['actor_approvals_added']==0
out=L/'S-death-real-six-packed-candidate-v01';out.mkdir();frames=[dict(phase=f['phase'],path=f['path'],sha256=f['sha256'],storage_translation=j['storage_translation']) for f in j['frames']]
plan=out/'packing-plan.json';p=dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',role='death',direction='S',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,physical_canvas=2560,rig_root_in_unpadded_frame=j['common_unpadded_root'],tile_size=[2304,2304],source_contract_sha256=j['source_contract']['sha256'],frames=frames)
plan.write_text(json.dumps(p,indent=2)+'\n');raw=out/'thunder_female-S-death-real-six-candidate.png'
for label,args in [('lossless-pack',[str(B/'pr122-author-six-pose-atlas-v04.py'),'--plan',str(plan),'--expected-plan-sha256',hashlib.sha256(plan.read_bytes()).hexdigest(),'--output',str(raw)]),('fixed-canonical-request',[str(B/'pr122-build-authored-clip-request-v07.py'),'--packing',str(raw.with_suffix('.packing.json')),'--expected-packing-sha256',None,'--version','SdeathRelaxedNative01','--output',str(out/'request-SdeathRelaxedNative01.json')])]:
 if None in args:args[args.index(None)]=hashlib.sha256(raw.with_suffix('.packing.json').read_bytes()).hexdigest()
 with (out/(label+'.log')).open('x') as f:r=subprocess.run(['python3','-B',*args],cwd='/workspace/twilight',stdout=f,stderr=subprocess.STDOUT)
 assert r.returncode==0,label+' HOLD; original files preserved'
print(json.dumps(dict(status='NEW_S_ACTUAL_SOURCE_PACKED_AND_GEOMETRY_REQUEST_READY_NOT_SOURCE_VISUAL_APPROVED',raw_sha256=hashlib.sha256(raw.read_bytes()).hexdigest(),raw_bytes=raw.stat().st_size,request=str(out/'request-SdeathRelaxedNative01.json'),actor_approvals_added=0)))
