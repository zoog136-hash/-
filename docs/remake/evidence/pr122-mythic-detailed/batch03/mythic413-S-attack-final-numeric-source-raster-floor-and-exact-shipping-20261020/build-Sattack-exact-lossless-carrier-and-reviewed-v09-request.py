"""Scratch-only S carrier: exact RGBA padding, audited packer and isolated builder.
No art views, source edits, repository edits, runtime adoption or tests.
"""
from pathlib import Path
import hashlib,json,sys,subprocess,importlib.util,runpy
import numpy as np
from PIL import Image
B=Path(__file__).parent;S=Path('/workspace/scratch');R=Path('/workspace/twilight')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(p,q):
 with Path(p).open('x') as w:json.dump(q,w,indent=2,ensure_ascii=False,allow_nan=False);w.write('\n')
 return pin(p)
cp=S/'mythic413-S-attack-author-20261020-v01/actual-S-ATTACK6-own-native-articulated-rig-v07/S-ATTACK6-final-actual-native-SOURCE-ONE-SHOT-PASS-contract-v08.json'
assert pin(cp)['sha256']=='6994157cc90d78d61e3ef8044f0ad6c4bbacc2247f314ae42fa628b735f1341d';c=json.loads(cp.read_text())
vp=Path(c['independent_final_SOURCE_and_one_shot_PASS']['path']);assert pin(vp)['sha256']=='4a453eb39fe306f92e4a73b22334dab5cdd52efb3027e0bd0590fe1cc992bac8';v=json.loads(vp.read_text())
npf=B/'Sattack-final699415-independent36-source-raster-fixed-rig-finite-capture-v01.json';assert pin(npf)['sha256']=='40206a1ac2f2fbebd55606cf33a047e450cc5d8a413b352ed2306b2217073a99';numeric=json.loads(npf.read_text())
review=save(B/'Sattack-final699415-peer-visual-and-independent-numeric-source-cycle-binding-v01.json',dict(schema='PR122-peer-actual-visual-plus-independent-numeric-exact-source-review-v1',source_visual_status='PASS',key='transform:413',direction='S',role='attack',source_contract=pin(cp),actual_peer_visual_review=pin(vp),independent_numeric_review=pin(npf),C_fixed=2560,bodyunit_fixed=2.5,common_rig_root=c['common_rig_root_in_unpadded_frame'],storage_translation=[128,128],source_canvas=[1792,1792],cycle_seconds=.42,phase_seconds=.07,intended_contact_frame=3,loop=False,visual_findings=list(v['actual_visual_findings'].values()),visual_limitations=v['limits']+numeric['limits'],actual_six_bindings=numeric['rows'],new_image_views=0,images_forwarded=0,actor_approvals_added=0))
out=S/'mythic413-S-attack-actual-packed-r001-20261020';out.mkdir();ship=out/'original-six-exact-RGBA-transparent-storage';ship.mkdir();frames=[];rows=[]
for i,f in enumerate(c['frames']):
 p=Path(f['path']);assert pin(p)['sha256']==f['sha256'];original=Image.open(p);assert original.mode=='RGBA' and original.size==(1792,1792);a=np.array(original);image=Image.new('RGBA',(2304,2304));image.paste(original,(0,0));dest=ship/f'phase{i}-original1792-in-transparent2304.png'
 with dest.open('xb') as w:image.save(w,format='PNG',compress_level=6)
 result=np.array(Image.open(dest));assert np.array_equal(result[:1792,:1792],a) and not np.any(result[1792:]) and not np.any(result[:1792,1792:]);assert np.count_nonzero(result[:,:,3])==np.count_nonzero(a[:,:,3])
 frames.append(dict(phase=i,path=str(dest),sha256=pin(dest)['sha256'],storage_translation=[128,128]));rows.append(dict(phase=i,original_source=pin(p),shipping_source=pin(dest),original_size=[1792,1792],shipping_size=[2304,2304],same_integer_translation=[0,0],original_RGBA_reverse_mismatch=0,empty_padding_RGBA_nonzero=0,original_alpha_positive_count=int(np.count_nonzero(a[:,:,3])),shipping_alpha_positive_count=int(np.count_nonzero(result[:,:,3]))))
save(out/'uniform-rig-root-storage-translation-proof-v01.json',dict(status='PASS_EXACT_ALL_SIX_FULL_RGBA_TRANSPARENT_PADDING_ONLY',source_contract=pin(cp),source_visual_and_numeric_binding=review,physical_C=2560,bodyunit=2.5,common_unpadded_root=c['common_rig_root_in_unpadded_frame'],original_storage=[128,128],shipping_storage=[128,128],same_integer_translation_all6=[0,0],rows=rows,source_resampled=False,runtime_adoption_approved=False,actor_approvals_added=0))
plan=out/'packing-plan.json';save(plan,dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',direction='S',role='attack',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,physical_canvas=2560,rig_root_in_unpadded_frame=c['common_rig_root_in_unpadded_frame'],tile_size=[2304,2304],frames=frames))
packer=S/'mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07/pr122-author-six-pose-atlas-v04.py';assert pin(packer)['sha256']=='297cf390779e3e60e65b242335dfab307c106dc421df3bb46250bc929ddc3938';raw=out/'thunder_female-S-attack-six-actual-poses-r001.png'
subprocess.run([sys.executable,str(packer),'--plan',str(plan),'--expected-plan-sha256',pin(plan)['sha256'],'--output',str(raw)],check=True)
P=S/'mythic413-declared-physical-root-canonical-bridge-proposal-20261020-v09r02';f=P/'v09r02-declared-canonical-bridge-unexecuted-proposal-frozen-allowlist-v01.json';assert pin(f)['sha256']=='db238a794e44c10ffcdd278e3df5323c04c7773a1717484f5c4e21da6afdffa6'
for e in json.loads(f.read_text())['files']:
 p=Path(e.get('path',e.get('source','')));assert pin(p)['sha256']==e['sha256'] and pin(p)['bytes']==e['bytes']
audit=B/'v09r02-declared-canonical-bridge-independent-readonly-code-audit-v01.json';assert pin(audit)['sha256']=='8bd4f1d3d741e8668c0b5589585874ed552a57eafdcd6c5785668a75b4bf584c'
original={n:pin(R/'tools'/n)['sha256']for n in ['pr122_reviewed_runtime_layout.py','stage_pr122_native_locomotion.py','advance_pr122_native_locomotion.py']};sys.dont_write_bytecode=True;sys.path.insert(0,str(R/'tools'));loaded={}
for name in ['pr122_reviewed_runtime_layout','stage_pr122_native_locomotion','advance_pr122_native_locomotion']:
 p=P/(name+'.py');spec=importlib.util.spec_from_file_location(name,p);mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod);loaded[name]=mod
assert loaded['advance_pr122_native_locomotion'].staging is loaded['stage_pr122_native_locomotion'] and loaded['stage_pr122_native_locomotion'].reviewed_layout is loaded['pr122_reviewed_runtime_layout'];assert loaded['pr122_reviewed_runtime_layout'].declared_canonical_preflight_kwargs(None,None,'unused','S',2048)=={}
for n,h in original.items():assert h==pin(P/n)['sha256']
save(out/'isolated-three-copy-preload-provenance-v01.json',dict(status='ISOLATED_EXACT_THREE_COPY_PRELOAD_BUILDER_ONLY_NO_REPO_WRITES',original_repository_tools=original,loaded_modules={n:pin(m.__file__)for n,m in loaded.items()},legacy_absent_seed_kwargs_unchanged=True,expected_request='request-SattackSixActualRig01.json',root_matching_core_deployment_notice='Parent reported f91818460bd75667d9d1b135cebbcd355daea64a deployment; all three local ROOT core file hashes independently equal the reviewed scratch copies. This is metadata, not game adoption.',runtime_adoption_approved=False,actor_approvals_added=0))
packing=raw.with_suffix('.packing.json');req=out/'request-SattackSixActualRig01.json';builder=P/'pr122-build-authored-clip-request-v07.py';assert pin(builder)['sha256']=='40ec010741afcc5d442793292943188af89f28a72fa04b5785c63b1095e5e938'
sys.argv=[str(builder),'--packing',str(packing),'--expected-packing-sha256',pin(packing)['sha256'],'--version','SattackSixActualRig01','--output',str(req)];runpy.run_path(str(builder),run_name='__main__')
for n,h in original.items():assert pin(R/'tools'/n)['sha256']==h
print(json.dumps(dict(request=pin(req),raw=pin(raw),packing=pin(packing),source_review=review,source_PNGs_modified=False,repository_files_changed=False,new_image_views=0,runtime_adoption_approved=False)))
