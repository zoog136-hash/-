from pathlib import Path
import hashlib,json,subprocess,sys
role=sys.argv[1];assert role in ('idle','hit')
S=Path('/workspace/scratch');base=S/'mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07'
packer=base/'pr122-author-six-pose-atlas-v04.py';builder=base/'pr122-build-authored-clip-request-v05.py'
for p,h in [(packer,'297cf390779e3e60e65b242335dfab307c106dc421df3bb46250bc929ddc3938'),(builder,'d20c10d0c11978a16e70e5a68600b174e7cfe47c9f3b39095701647cd319b66d')]:assert hashlib.sha256(p.read_bytes()).hexdigest()==h
if role=='idle':
 p=S/'mythic413-SW-idle-author-20261020-v01/actual-SW-IDLE6-native-breath-relax-v01/SW-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v01.json';expected='453395a134a4cb2df2f5b9a2cbd147435e7f838d089e0eec556f965d3d5f2877'
else:
 p=S/'mythic413-SW-hit-author-20261020-v01/actual-SW-HIT6-own-native-articulated-v01/SW-HIT6-actual-own-native-body-head-LEFTguard-source-contract-v01.json';expected='11ba41ccff621d14d71733ad856bfd4d9269ce13a20d507f38b9fa917de9fbfb'
b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==expected;d=json.loads(b)
C=d.get('physical_canvas_fixed',d.get('C'));assert C==2496;C=int(C)
root=d.get('common_rig_root_in_unpadded_frame',d.get('common_rig_root_unpadded'));assert root==[667.65625,1003.5996691442447]
tr=d['storage_translation'];assert tr==[128,128];tr=list(map(int,tr))
frames=[]
for i,e in enumerate(d['frames']):
 s=e.get('source',e);f=Path(s['path']);assert e['phase']==i
 fb=f.read_bytes();assert hashlib.sha256(fb).hexdigest()==s['sha256'] and len(fb)==s['bytes']
 frames.append(dict(phase=i,path=str(f),sha256=s['sha256'],storage_translation=tr))
assert len(frames)==6
out=S/f'mythic413-SW-{role}-actual-packed-r001-20261020';out.mkdir()
plan=out/'packing-plan.json';pb=(json.dumps(dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',role=role,direction='SW',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,physical_canvas=C,rig_root_in_unpadded_frame=root,tile_size=[1536,1536],source_contract_sha256=expected,frames=frames),indent=2)+'\n').encode()
with plan.open('xb') as f:f.write(pb)
raw=out/f'thunder_female-SW-{role}-six-actual-poses-r001.png'
with (out/'lossless-packing-v01.log').open('x') as log:
 r=subprocess.run(['python3','-B',str(packer),'--plan',str(plan),'--expected-plan-sha256',hashlib.sha256(pb).hexdigest(),'--output',str(raw)],stdout=log,stderr=subprocess.STDOUT)
assert r.returncode==0,'PACK_HOLD see saved log'
packing=raw.with_suffix('.packing.json');req=out/f'request-SW{role}SixActualRig01.json'
with (out/'request-build-v01.log').open('x') as log:
 r=subprocess.run(['python3','-B',str(builder),'--packing',str(packing),'--expected-packing-sha256',hashlib.sha256(packing.read_bytes()).hexdigest(),'--version',f'SW{role}SixActualRig01','--output',str(req)],stdout=log,stderr=subprocess.STDOUT)
assert r.returncode==0,'REQUEST_HOLD see saved log'
print(json.dumps({'status':'LOSSLESS_PACKET_READY_INDEPENDENT_EXACT_QC_PENDING','role':role,'files':[dict(path=str(x),bytes=x.stat().st_size,sha256=hashlib.sha256(x.read_bytes()).hexdigest()) for x in [req,raw,packing]]}))
