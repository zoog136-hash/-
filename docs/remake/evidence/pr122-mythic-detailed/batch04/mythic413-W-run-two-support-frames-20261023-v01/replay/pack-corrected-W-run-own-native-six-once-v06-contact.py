from pathlib import Path
from PIL import Image
import hashlib,json,subprocess,argparse
import numpy as np

L = Path('/workspace/scratch/pr122-death-s-only-20261022-v01')
B = Path('/workspace/scratch/mythic413-W-run-own-native-20261022-v01')
parser = argparse.ArgumentParser()
parser.add_argument('--version',choices=['06'],default='06')
version = parser.parse_args().version
cp = B/f'actual-W-RUN-six-own-native-v{version}-world-contact/W-RUN-six-own-native-source-contract-v{version}.json'
j = json.loads(cp.read_text())
assert len(j['frames'])==6 and j['C']==2560 and j['source_visual_status']=='HOLD_NOT_REVIEWED'
assert j['actor_approvals_added']==0 and not j['production_connected']
out = L/f'W-run-own-native-six-exact-packed-candidate-v{version}'
out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
frames,checks = [],[]
for f in j['frames']:
    p = Path(f['source']['path'])
    assert sha(p)==f['source']['sha256']
    im = Image.open(p).convert('RGBA')
    assert im.size==(1792,1792)
    rgba = np.array(im)
    y,x = np.where(rgba[:,:,3]>0)
    storage = j['storage_translation']
    root = j['common_rig_root_unpadded']
    boxes = []
    for canvas in [2048,2560]:
        ox = canvas/2-root[0]-storage[0]
        oy = canvas*5/8-root[1]-storage[1]
        box = [float(x.min()+ox),float(y.min()+oy),float(x.max()+1+ox),float(y.max()+1+oy)]
        assert min(box)>=0 and box[2]<=canvas and box[3]<=canvas, (f['phase'],canvas,box)
        boxes.append(dict(canvas=canvas,actual_alpha_bounds=box))
    carrier = Image.new('RGBA',(2304,2304))
    carrier.paste(im,(0,0))
    assert carrier.crop((0,0,1792,1792)).tobytes()==im.tobytes()
    a = np.array(carrier)
    assert not a[1792:,:,:].any() and not a[:,1792:,:].any()
    dest = out/f"phase-{f['phase']}-exact-2304.png"
    if f['phase'] in [1,4]:
        carrier.save(dest)
    else:
        dest = L/'W-run-own-native-six-exact-packed-candidate-v05'/f"phase-{f['phase']}-exact-2304.png"
        assert Image.open(dest).convert('RGBA').tobytes()==carrier.tobytes(), 'Unchanged carrier bytes must match input exactly'
    frames.append(dict(phase=f['phase'],path=str(dest),sha256=sha(dest),storage_translation=storage))
    checks.append(dict(phase=f['phase'],source=str(p),source_sha256=sha(p),carrier=str(dest),
                       carrier_sha256=sha(dest),source_RGBA_inverse_mismatch=0,
                       added_padding_RGBA_zero=True,fixed_root_bounds=boxes,
                       source_visual_status='HOLD_NOT_REVIEWED'))
plan = out/'packing-plan.json'
plan.write_text(json.dumps(dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',
    role='run',direction='W',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,
    physical_canvas=2560,rig_root_in_unpadded_frame=j['common_rig_root_unpadded'],
    tile_size=[2304,2304],source_contract_sha256=sha(cp),frames=frames),indent=2)+'\n')
raw = out/f'thunder_female-W-run-own-native-real-six-v{version}.png'
request = out/f'request-WrunOwnNative{version}.json'
packer = L/'retained-profile-tools-policy-synced-v03/pr122-author-six-pose-atlas-v04.py'
builder = Path('/workspace/scratch/mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07/pr122-build-authored-clip-request-v05.py')
steps = [('pack',[str(packer),'--plan',str(plan),'--expected-plan-sha256',sha(plan),'--output',str(raw)]),
         ('request',[str(builder),'--packing',str(raw.with_suffix('.packing.json')),
          '--expected-packing-sha256',None,'--version',f'WrunOwnNative{version}','--output',str(request)])]
for name,args in steps:
    if None in args:args[args.index(None)]=sha(raw.with_suffix('.packing.json'))
    with (out/(name+'.log')).open('x') as log:
        result = subprocess.run(['python3','-B',*args],cwd='/workspace/twilight',stdout=log,stderr=subprocess.STDOUT)
    assert result.returncode==0, name+' HOLD; saved without blind retries'
proof = dict(status='SIX_NEW_NATIVE_W_RUN_FRAMES_LOSSLESS_PACKED_GEOMETRY_READY_SOURCE_QUALITY_HOLD',
             source_contract=dict(path=str(cp),sha256=sha(cp)),frames=checks,
             raw_sha256=sha(raw),source_visual_status='HOLD_NOT_REVIEWED',
             actor_approvals_added=0,game_clips_adopted=0,production_connected=False,
             source_RGBA_scaled=False,perpose_root_or_C_fit=False,
             gameplay_world_foot_contact='NOT_RUN_HOLD')
with (out/'six-source-to-packed-candidate-proof.json').open('x') as f:json.dump(proof,f,indent=2)
print(json.dumps(dict(status=proof['status'],poses=6,raw_sha256=sha(raw),raw_bytes=raw.stat().st_size,
                      approvals_added=0)))
