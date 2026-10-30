from pathlib import Path
import hashlib,json,math,subprocess
import numpy as np
from PIL import Image
S=Path('/workspace/scratch');helpers=S/'mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07'
contract=S/'mythic413-SE-attack-author-20261020-v01/actual-SE-ATTACK6-native-articulated-rig-v05/SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v07.json'
source_sha='f7f9b8475a5dce8995b4a12d52f772bac1aca777178239f2cd63b4400c17b43c'
cert=S/'mythic413-nw-n-walk-independent-qc-20261020/SEattack-v05-f7f9b8-independent-final-actual-source-one-shot-cycle-PASS-v01.json'
assert hashlib.sha256(cert.read_bytes()).hexdigest()=='41fd83fc688327f780c1d8cd8540b88d8a14407ed8c2855dd877d379527289f3'
assert hashlib.sha256(contract.read_bytes()).hexdigest()==source_sha
d=json.loads(contract.read_text());C=d['C'];assert C==2816;C=int(C)
root=d['common_rig_root_in_unpadded_frame'];assert root==[723.7916666666666,1067.2150113422247]
oldtr=d['storage_translation'];assert oldtr==[128,128]
dx=1152-(math.floor(root[0]+.5)+oldtr[0]);assert dx==300;dy=0
out=S/'mythic413-SE-attack-fixed-storage-r001-20261020';out.mkdir()
proof=[];frames=[]
for i,e in enumerate(d['frames']):
 assert e['phase']==i
 p=Path(e['path']);b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==e['sha256']
 with Image.open(p) as im:
  assert im.mode=='RGBA' and im.size==(1792,1792)
  a=np.asarray(im);can=Image.new('RGBA',(2304,2304),(0,0,0,0));can.paste(im,(dx,dy))
  assert can.crop((dx,dy,dx+im.width,dy+im.height)).tobytes()==im.tobytes()
  arr=np.asarray(can);assert not arr[:,:dx].any() and not arr[:,dx+im.width:].any() and not arr[im.height:,:].any()
  assert np.count_nonzero(a[:,:,3])==np.count_nonzero(arr[:,:,3])
  f=out/f'phase{i}-fixed-storage-only-original-RGBA-v01.png'
  with f.open('xb') as w:can.save(w,format='PNG',compress_level=6)
  fb=f.read_bytes();h=hashlib.sha256(fb).hexdigest()
  proof.append(dict(phase=i,original_path=str(p),original_sha256=e['sha256'],original_size=list(im.size),stored_path=str(f),stored_sha256=h,stored_bytes=len(fb),stored_size=[2304,2304],inverse_full_original_RGBA_exact=True,outside_full_original_rectangle_all_RGBA_zero=True,alpha_positive_count_unchanged=True))
  frames.append(dict(phase=i,path=str(f),sha256=h,storage_translation=[428,128]))
assert len(frames)==6
P=dict(status='LOSSLESS_UNIFORM_STORAGE_ONLY_NO_POSE_CHANGE',original_contract=str(contract),original_contract_sha256=source_sha,physical_canvas=C,common_rig_root_unpadded=root,original_storage_translation=oldtr,uniform_extra_storage_translation=[dx,dy],stored_translation=[428,128],method='dx = 2304 tile center minus declared rounded rig root plus old storage, same for all six; y unchanged; no alpha/foot/perpose bound used; original physical C,root,pose,clock unchanged',actor_approvals_added=0,frames=proof)
def save(p,j):
 b=(json.dumps(j,indent=2)+'\n').encode()
 with p.open('xb') as f:f.write(b)
 return hashlib.sha256(b).hexdigest()
proofsha=save(out/'uniform-rig-root-storage-translation-proof-v01.json',P)
plan=out/'packing-plan.json';h=save(plan,dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',role='attack',direction='SE',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,physical_canvas=C,rig_root_in_unpadded_frame=root,tile_size=[2304,2304],source_contract_sha256=source_sha,frames=frames))
packer=helpers/'pr122-author-six-pose-atlas-v04.py';builder=helpers/'pr122-build-authored-clip-request-v05.py'
for p,hv in [(packer,'297cf390779e3e60e65b242335dfab307c106dc421df3bb46250bc929ddc3938'),(builder,'d20c10d0c11978a16e70e5a68600b174e7cfe47c9f3b39095701647cd319b66d')]:assert hashlib.sha256(p.read_bytes()).hexdigest()==hv
raw=out/'thunder_female-SE-attack-six-actual-poses-r001.png'
with (out/'lossless-packing-v01.log').open('x') as f:r=subprocess.run(['python3','-B',str(packer),'--plan',str(plan),'--expected-plan-sha256',h,'--output',str(raw)],stdout=f,stderr=subprocess.STDOUT)
assert r.returncode==0,'PACK_HOLD'
packing=raw.with_suffix('.packing.json');req=out/'request-SEattackSixActualRig01.json'
with (out/'request-build-v01.log').open('x') as f:r=subprocess.run(['python3','-B',str(builder),'--packing',str(packing),'--expected-packing-sha256',hashlib.sha256(packing.read_bytes()).hexdigest(),'--version','SEattackSixActualRig01','--output',str(req)],stdout=f,stderr=subprocess.STDOUT)
assert r.returncode==0,'REQUEST_HOLD'
print(json.dumps(dict(status='LOSSLESS_PACKET_READY_EXACT_QC_PENDING',proof_sha256=proofsha,files=[dict(path=str(p),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in [req,raw,packing]])))
