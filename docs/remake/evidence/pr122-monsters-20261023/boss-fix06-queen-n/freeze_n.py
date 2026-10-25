"""Freeze only the N RUN input; later combined output is a separate artifact."""
from pathlib import Path
import hashlib,json
from datetime import datetime,timezone
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent
FOLDER=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/n-r001'
def rel(p):return p.relative_to(ROOT).as_posix()
def pin(p):return{'path':rel(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def save(name,value):
    p=OUT/name;data=(json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
    if p.exists():assert p.read_bytes()==data,'Frozen output differs: '+str(p)
    else:p.write_bytes(data)

a=json.loads((OUT/'candidate.json').read_text())['actors']['monster:얼음 여왕']
track=a['tracks'][0]
r=json.loads((OUT/'playback/report.json').read_text())
assert r['actual_ActorMotion_all6']==r['actual_engine_clock_AnimatedSprite2D_all6']=='PASS'
rgba=[]
for f in track['geometry']['frames']:
    source,texture=ROOT/f['source'],ROOT/f['texture']
    assert source.read_bytes()==texture.read_bytes()
    assert pin(source)['sha256']==f['source_sha256']
    im=np.asarray(Image.open(texture).convert('RGBA'));x,y,w,h=f['region']
    digest=hashlib.sha256(im[y:y+h,x:x+w].tobytes()).hexdigest()
    assert digest==f['rgba_sha256'];rgba.append(digest)
assert len(rgba)==len(set(rgba))==6
review={'schema':'pr122-queen-N-isolated-edit-review-v1','actor':'monster:얼음 여왕',
        'method':'Private actual vision of preserved old six isolated crops, two exact edit canvases, all three new single-pose results composited with real alpha, and final normalized six-pose strip.',
        'status':'TECHNICALLY_STAGED_FINAL_QUALITY_HOLD','new_approvals':0,
        'selected_clip':'run_6','selected_poses':6,'newly_generated_selected_poses':3,'reused_selected_poses':3,
        'actual_examined_final_preview':pin(OUT/'private/normalized-N-six-exact-alpha.png'),
        'observed_corrections':[
            {'criterion':'RIGHT_bare_LEFT_covered_continuity','result':'OBSERVED_FIXED_IN_SELECTED_SIX',
             'observation':'All selected rear poses keep exposed bare RIGHT upper thigh on viewer-right and covered LEFT thigh/leg on viewer-left. Wrong old middle source slots2/3 are not selected.'},
            {'criterion':'LEFT_staff','result':'OBSERVED_PRESERVED_IN_SELECTED_SIX',
             'observation':'LEFT hand holds the staff on viewer-left in every back-view pose; hair/crown and both purple wing silhouettes remain connected. Face/front breastplate stay turned away.'},
            {'criterion':'opposite_support_and_flight','result':'OBSERVED_STATIC_IMPROVEMENT_NOT_FULL_GAIT_APPROVAL',
             'observation':'Phase0 bare RIGHT support differs from phase3 covered LEFT support. New phases1/4 preserve opposite raised-knee/grounded-leg ownership. Phase2 old LEFT-forward flight and new phase5 RIGHT-forward flight have different extended/folded legs, replacing the old repeated LEFT-forward ending.'},
            {'criterion':'source_pixel_density','result':'TECHNICAL_NORMALIZATION_ONLY',
             'observation':'Each frame retains exact source PNG/RGBA/region, with per-frame virtual canvases616/696/616/616/728/776 and one86/140 profile scale. No source pixel resampling or color edits.'}],
        'reused_old_source_whole_sheet_preserved':pin(OUT/'references/queen-N-v03-preserved-source.png'),
        'selected_old_source_slots':[0,4,1],
        'excluded_old_source_slots':{'2':'wrong rear bare-thigh side','3':'wrong rear bare-thigh side','5':'repeated LEFT-forward instead of opposite RIGHT-forward flight'},
        'confirmed_source_defects_in_selected_six':[],
        'unseen_not_reviewed':['Complete timed gait and moving-world foot slip/physical contact','Cross-role transitions in default Main','Final independent mythic anatomy/cloth/wing detail and rear-view exact camera acceptance','Flight ground-plane source anchors are metadata estimates, not anatomical contact approval'],
        'PNG_sources':4,'actual_imagegen_calls':3,'additional_whole_sheet_generation':0,
        'existing_frozen_queen_sources_and_approvals_preserved':True}
save('quality-review.json',review)
save('checkpoint.json',{'schema':'pr122-queen-N-checkpoint-v1','native_tracks':1,'native_poses':6,'new_selected_poses':3,'reused_selected_poses':3,
     'selected_RGBA_unique':6,'PNG_byte_and_RGBA_preserved':True,'strict_source_geometry':'PASS','per_frame_density_bounds':'PASS',
     'Godot_version':r['engine'],'actual_ActorMotion_all6':'PASS','actual_engine_clock_all6':'PASS','new_approvals':0,'default_catalog_switches':0,
     'candidate':pin(OUT/'candidate.json'),'playback_report':pin(OUT/'playback/report.json')})
files=[pin(p) for base in [OUT,FOLDER] for p in sorted(base.rglob('*')) if p.is_file() and p.name!='file-manifest.json' and '__pycache__' not in str(p) and 'combined-output' not in str(p)]
manifest={'schema':'pr122-queen-N-frozen-file-manifest-v1','new_raw_sources':3,'new_selected_poses':3,'reused_selected_poses':3,
          'native_selected_clips':1,'native_selected_poses':6,'new_approvals':0,'existing_frozen_files_untouched':True,
          'scope':'N RUN only; any later combined-output is separately pinned','files':files}
save('file-manifest.json',manifest)
print(json.dumps({'verified_files':len(files),'candidate':pin(OUT/'candidate.json'),'manifest':pin(OUT/'file-manifest.json'),'new_approvals':0}))
