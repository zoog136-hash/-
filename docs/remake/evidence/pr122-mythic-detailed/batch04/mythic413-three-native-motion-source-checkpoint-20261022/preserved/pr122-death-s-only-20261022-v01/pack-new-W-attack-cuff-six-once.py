from pathlib import Path
import json,hashlib,subprocess,numpy as np
from PIL import Image
L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');T=L/'retained-profile-tools-policy-synced-v02';cp=Path('/workspace/scratch/mythic413-W-attack-author-fresh-20261020-v01/actual-W-ATTACK6-native-profile-rig-v04-distal-cuff-bind-20261022/W-ATTACK6-actual-native-profile-RIGHT-fullstaff-LEFTguard-realcloth-candidate-v04.json');j=json.loads(cp.read_text());assert len(j['frames'])==6 and j['C']==2560
out=L/'W-attack-distal-cuff-six-exact-packed-candidate-v01';out.mkdir();frames=[];checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(cp)=='4939a867923efc11cf2145c2266cd407a9e8abd43635d53138714305cbc42779'
for f in j['frames']:
 p=Path(f['source']['path']);assert sha(p)==f['source']['sha256'];im=Image.open(p).convert('RGBA');assert im.size==(1792,1792);carrier=Image.new('RGBA',(2304,2304));carrier.paste(im,(0,0));assert carrier.crop((0,0,1792,1792)).tobytes()==im.tobytes();a=np.array(carrier);assert not a[1792:,:,:].any() and not a[:,1792:,:].any();dest=out/('phase-'+str(f['phase'])+'-exact-2304.png');carrier.save(dest);frames.append(dict(phase=f['phase'],path=str(dest),sha256=sha(dest),storage_translation=j['storage_translation']));checks.append(dict(phase=f['phase'],source=str(p),source_sha256=sha(p),carrier=str(dest),carrier_sha256=sha(dest),all_original_RGBA_preserved=True,added_padding_RGBA_zero=True))
plan=out/'packing-plan.json';plan.write_text(json.dumps(dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',role='attack',direction='W',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,physical_canvas=2560,rig_root_in_unpadded_frame=j['common_rig_root_unpadded'],tile_size=[2304,2304],source_contract_sha256=sha(cp),frames=frames),indent=2)+'\n');raw=out/'thunder_female-W-attack-cuff-real-six-v04.png';request=out/'request-WattackCuffNative04.json';builder=Path('/workspace/scratch/mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07/pr122-build-authored-clip-request-v05.py')
steps=[('pack',[str(T/'pr122-author-six-pose-atlas-v04.py'),'--plan',str(plan),'--expected-plan-sha256',sha(plan),'--output',str(raw)]),('request',[str(builder),'--packing',str(raw.with_suffix('.packing.json')),'--expected-packing-sha256',None,'--version','WattackCuffNative04','--output',str(request)])]
for name,args in steps:
 if None in args:args[args.index(None)]=sha(raw.with_suffix('.packing.json'))
 with (out/(name+'.log')).open('x') as log:r=subprocess.run(['python3','-B',*args],cwd='/workspace/twilight',stdout=log,stderr=subprocess.STDOUT)
 assert r.returncode==0,name+' HOLD; preserve files without retries'
proof=dict(status='ACTUAL_NEW_W_ATTACK_SIX_EXACT_PACK_AND_GEOMETRY_READY_SOURCE_QUALITY_HOLD',source_contract=dict(path=str(cp),sha256=sha(cp)),frames=checks,source_visual_status='HOLD_NOT_REVIEWED',actor_approvals_added=0,game_clips_adopted=0,source_RGBA_scaled=False,perpose_root_or_C_fit=False)
(out/'six-source-to-packed-candidate-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(dict(status=proof['status'],raw_sha256=sha(raw),raw_bytes=raw.stat().st_size,poses=6,approvals_added=0)))
