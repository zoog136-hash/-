from pathlib import Path
from collections import Counter
import json,hashlib,subprocess
root=Path(__file__).resolve().parents[5];base=Path(__file__).resolve().parent;prepared=json.load(open(base/'prepared.json'));dirs=['E','SE','S','SW','W','NW','N','NE']
common_unseen=['Timed default Main playback and transitions','GPU tint/material/VFX presentation','Combat hitbox/target overlap at the real attack marker','Physical collision/contact against a moving world ground plane','Final release or new approval decision']
model_notes={
 'mummy_lord':('HOLD',[
  {'criterion':'identity','result':'PASS','observation':'Crowned bandaged mummy, gold trim, long torn pale cloak and curved gold-edged blade match the original project reference.'},
  {'criterion':'eight_view_camera','result':'PASS','observation':'Front S and rear N/back-quarter cape silhouettes are distinct; blade/crown/cloak remain attached in the examined views.'},
  {'criterion':'run_support','result':'HOLD','observation':'The runtime RUN route uses the three-pose WALK cycle. Enlarged E/S/W/NE source sequences leave the opposite support leg partly obscured by the cloak; a complete alternating-support/weight transfer is not established by this inspection.'},
  {'criterion':'attack_hit_idle','result':'PASS','observation':'Raised-blade windup, forward sweep and ready recovery differ from recoil/bracing and neutral breathing. Timed contact against a target was not inspected.'}]),
 'seer_boss':('PASS',[
  {'criterion':'identity','result':'PASS','observation':'Single central red eye, teeth, crown and red eye-stalk silhouette match the source; the floating eyeball anatomy is retained.'},
  {'criterion':'eight_view_camera','result':'PASS','observation':'S exposes the central eye/front mouth; N shows the back mantle. Side and rear-quarter stalk silhouettes change with camera direction.'},
  {'criterion':'locomotion_weight','result':'PASS','observation':'Floating movement uses changing body tilt and independently curved eye-stalk poses rather than foot walking; ground-paw alternation is not applicable.'},
  {'criterion':'attack_hit_idle','result':'PASS','observation':'Attack spreads/leans the eye-stalk cluster, recoil pulls it back, and idle is restrained. No obvious detached part, hard cutoff or collapsed body appeared in the reviewed regions.'}]),
 'salah':('HOLD',[
  {'criterion':'identity','result':'PASS','observation':'Goat skull, long swept horns, exposed rib/bone structure, torn red mantle and long hooked poleaxe match the original source.'},
  {'criterion':'eight_view_camera','result':'PASS','observation':'Front skull, rear spine/cape and both side poleaxe silhouettes are present; motion roles remain distinct.'},
  {'criterion':'run_support','result':'HOLD','observation':'Runtime RUN falls back to three WALK poses. Enlarged E/S/W/NE hoof sequences show steps, but which anatomical hoof takes the opposite support and the contact duration are not sufficiently established for mythic locomotion approval.'},
  {'criterion':'attack_contact','result':'HOLD','observation':'Windup and sweep exist, but the S/front poleaxe sweeps mostly laterally across the body. Real forward target contact at the marker requires a timed Main/target review; no contact PASS is inferred from the pose name.'}]),
 'sand_worm':('PASS',[
  {'criterion':'identity','result':'PASS','observation':'Large circular red tooth-lined mouth, segmented curved sand-colored body and rubble base retain the source worm silhouette.'},
  {'criterion':'eight_view_camera','result':'PASS','observation':'S presents the open mouth, N presents back segmentation, side/rear-quarter bends differ; it is not a rotated flat portrait.'},
  {'criterion':'locomotion_weight','result':'PASS','observation':'A burrowing/anchored-body interpretation is used. The base stays at the source plane while the neck changes compression and bend; biped/quadruped foot support is not applicable.'},
  {'criterion':'attack_hit_idle','result':'PASS','observation':'Attack compresses/thrusts the mouth, hit retracts it and death progressively slumps. No obvious region cutoff or disconnected core was visible in the examined source frames.'}]),
 'albino_phoenix_project_source':('PASS',[
  {'criterion':'identity','result':'PASS','observation':'Orange-gold flame bird, pointed crest, long curled flame tail and layered wings match the provided project reference. White recoloring is not assumed from the name albino.'},
  {'criterion':'eight_view_camera','result':'PASS','observation':'Front S, rear N, side and rear-quarter wing/body silhouettes are visibly differentiated.'},
  {'criterion':'locomotion_weight','result':'PASS','observation':'High/mid/low wing poses form a readable flying cycle with tail follow-through; ground foot support is not applicable.'},
  {'criterion':'attack_hit_idle','result':'PASS','observation':'Forward beak/talon attack, folded/recoiling hit and restrained idle flight are distinguishable. Flame tail/wing tips remain complete in the viewed frames.'}]),
 'waring_monster_boss':('HOLD',[
  {'criterion':'identity','result':'PASS','observation':'Black muscular big-cat body, yellow eyes, bared teeth and curled tail match the project panther reference.'},
  {'criterion':'eight_view_camera','result':'PASS','observation':'Front/back/side cameras and quadruped silhouettes are distinct; forward pounce, recoil and collapse are readable.'},
  {'criterion':'run_support','result':'HOLD','observation':'Runtime RUN uses three WALK poses. Enlarged E/S/W/NE paw sequences do not establish the full opposite fore/hind support exchange with enough certainty to grant mythic gait/contact approval.'},
  {'criterion':'clipping_collapse','result':'PASS','observation':'No obvious missing limb, detached tail or hard body cutoff is visible in the reviewed AtlasTexture regions.'}]),
 'male_plate_plate_helm_longsword':('REWORK_CANDIDATE',[
  {'criterion':'identity','result':'REWORK_CANDIDATE','observation':'The original is a heavily spiked black armored knight with a skull/chest motif, long broad blade and torn red cape. Runtime is a slim generic plate knight with small one-hand sword, prominent shield and plain dark cape; the distinctive heavy armor/red-cape silhouette is lost.'},
  {'criterion':'boss_uniqueness','result':'REWORK_CANDIDATE','observation':'One generic SpriteFrames body is shared across these named/regional bosses. Palette or width variants cannot establish a dedicated mythic boss identity.'},
  {'criterion':'eight_view_actions','result':'PASS','observation':'The generic rig itself has distinct eight cameras, articulated movement, sword windup/sweep, hit and collapse. This rig-level observation does not approve it for the target bosses.'}]),
 'asitagio':('REWORK_CANDIDATE',[
  {'criterion':'identity','result':'REWORK_CANDIDATE','observation':'Runtime is a squat black/lava golem-like fist fighter with glowing forearms. It has no authored axe/sword or feather wings; the target reference identity cannot be recovered by tinting this body.'},
  {'criterion':'eight_view_actions','result':'PASS','observation':'The proxy rig itself exposes eight sides and fist attack/hit/collapse phases; this does not supply the missing target anatomy and weapon.'}]),
 'albino_deer_batch16_authored':('REWORK_CANDIDATE',[
  {'criterion':'species_identity','result':'REWORK_CANDIDATE','observation':'The source reference is a long-maned horse/unicorn form. Runtime is a branching-antler deer/stag with short mane and deer proportions; the single unicorn horn/horse silhouette is not preserved.'},
  {'criterion':'attack_identity','result':'REWORK_CANDIDATE','observation':'Runtime lowers and charges with broad branching antlers, which is a deer attack rather than the target unicorn horn/body action.'},
  {'criterion':'eight_view_actions','result':'PASS','observation':'Eight deer views and a full locomotion sequence exist. Their completeness does not make the body a unicorn.'}]),
 'male_plate_plate_helm_battle_axe':('REWORK_CANDIDATE',[
  {'criterion':'identity_weapon','result':'REWORK_CANDIDATE','observation':'The original Nightvald reference shows massive black spiked armor, torn red cape and a very long jagged sword. Runtime uses a slim generic plate rig with small battle axe and shield, losing both weapon and heavy silhouette.'},
  {'criterion':'data_reference_conflict','result':'HOLD','observation':'World visual metadata says weapon=axe, while the actual project reference visibly carries a long serrated blade. Resolve this data/reference conflict before using the generic axe mapping as identity evidence.'},
  {'criterion':'eight_view_actions','result':'PASS','observation':'The generic axe rig has eight cameras and action sequences; target-specific weight and identity remain unapproved.'}]),
 'female_mage_mage_hood_staff':('REWORK_CANDIDATE',[
  {'criterion':'identity','result':'REWORK_CANDIDATE','observation':'Ice Queen reference is silver-haired/crowned with purple feather wings, black/gold armor, purple dress and purple staff. Runtime is a plain brown hooded mage with green-tipped staff, with no wings or crown.'},
  {'criterion':'eight_view_actions','result':'PASS','observation':'The generic mage rig has eight views and staff actions, but generic motion or tint cannot restore the missing queen silhouette.'}]),
 'lamia':('REWORK_CANDIDATE',[
  {'criterion':'species_identity','result':'REWORK_CANDIDATE','observation':'The Zenith Queen reference has a crowned purple spider/arachnid lower body and multiple long legs. Runtime is a brown-haired gold-bikini lamia with one green snake tail, losing the spider abdomen/leg silhouette.'},
  {'criterion':'attack_locomotion_identity','result':'REWORK_CANDIDATE','observation':'Serpent slither and bare-hand gestures do not provide the target spider leg propulsion/attack anatomy.'}]),
 'ettin':('REWORK_CANDIDATE',[
  {'criterion':'species_identity','result':'REWORK_CANDIDATE','observation':'The Yopnir reference is a white-furred quadruped bull with gold-armored huge horns. Runtime is a gray two-headed biped ogre carrying a spiked club, replacing the species, number of heads and weapon/body mechanics.'},
  {'criterion':'attack_locomotion_identity','result':'REWORK_CANDIDATE','observation':'A two-legged club swing cannot stand in for the target bull charge and horn/hoof motion.'}])}
# Pin each tracked runtime/reference source to HEAD as well as SHA256, proving
# this read-only review did not rewrite existing resource bytes.
tree={}
for line in subprocess.check_output(['git','ls-tree','-r','HEAD'],cwd=root,text=True).splitlines():
 metadata,path=line.split('\t',1);tree[path]=metadata.split()[2]
def pin(path):
 path=Path(path);path=root/path if not path.is_absolute() else path;b=path.read_bytes();relative=path.relative_to(root).as_posix();git_sha=hashlib.sha1(('blob '+str(len(b))+'\0').encode()+b).hexdigest();return {'path':relative,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'tracked_HEAD_blob':tree.get(relative),'matches_HEAD':tree.get(relative)==git_sha}
reviews=[]
for row in prepared['bosses']:
 verdict,findings=model_notes[row['model']];findings=[dict(f) for f in findings]
 if row['id']=='monster:알비노 데몬':findings[0]['target_specific_reference']='Target is a red horned armored demon with a large right-hand axe and empty left hand; runtime has molten fists and no axe.'
 if row['id']=='monster:오만한 우그누스':findings[0]['target_specific_reference']='Target is a humanoid armored red/black feather-winged demon with a long blade; runtime has no wings and no blade.'
 model=prepared['model_sheets'][row['model']];sources=[pin(row['frames_path'].removeprefix('res://')),pin(row['reference']['path'].removeprefix('res://'))]+[pin(t['path'].removeprefix('res://')) for t in row['texture_pins']]
 assert all(source['matches_HEAD'] for source in sources),row['id']
 evidence=[{'path':model['path'],'sha256':model['sha256']},{'path':row['reference_crop'],'sha256':row['reference_crop_sha256']}]
 if row['model'].startswith(('male_plate','female_mage')):
  for suffix in ['-page0.png','-page1.png']:
   path=base/'sheets'/(row['model']+suffix);evidence.append({'path':path.relative_to(root).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 review={'id':row['id'],'index_in_sorted_bosses':row['index'],'kind':'boss','required_quality':'mythic_transform','prior_production_status':row['preserved_status'],'approval_preserved':row['approval_preserved'],'prior_status_unchanged':True,'approval_changed':False,'new_approval':False,'current_review':verdict,'review_scope':'Private actual source-frame visual screening against the exact current project reference; PASS is not a production/release approval','profile':row['profile'],'profile_sha256':row['profile_sha256'],'source_pins':sources,'reference':row['reference'],'reference_region_rgba_sha256':row['reference_rgba_sha256'],'examined_views':dirs,'examined_roles':{'idle':dirs,'run_runtime_fallback_to_walk':dirs,'attack':dirs,'hit':dirs,'death_preserved_existing':dirs},'actual_track_counts':row['tracks'],'shared_model_review_id':row['model'],'findings':findings,'evidence':evidence,'unseen_not_reviewed':common_unseen.copy(),'tint_note':'Underlying exact source pixels were visually reviewed; profile tint/material properties are pinned. Tint cannot repair the identified species/weapon/silhouette mismatches. GPU material/VFX result was not reviewed.'}
 if row['model'] in ['mummy_lord','salah','waring_monster_boss']:
  review['evidence'].append({'path':(base/'locomotion-enlarged.png').relative_to(root).as_posix(),'sha256':hashlib.sha256((base/'locomotion-enlarged.png').read_bytes()).hexdigest()})
 if row['id']=='monster:얼음 여왕':
  staging_pins=json.load(open(base/'queen-staging-pins.json'));staging_path=base/'queen-staging-run8.png'
  review['staging_review']={'current_review':'HOLD','examined_views':dirs,'examined_roles':['run'],'examined_poses':48,'register_profile_pins':staging_pins['registers'],'source_pngs':staging_pins['tracks'],'findings':[
   {'criterion':'identity','result':'PASS','observation':'New sources restore silver hair/crown, black-gold bodice, purple wings/dress and purple staff rather than the hooded-mage proxy.'},
   {'criterion':'opposite_support','result':'HOLD','observation':'In E/S and several front/side directions, phases0/3 retain a similar exposed leading-leg plant and phases1/4 and2/5 repeat a similar knee lift. Opposite anatomical LEFT support is not established; six distinct pixel hashes do not prove a six-phase alternating run.'},
   {'criterion':'NE_camera','result':'HOLD','observation':'NE reads close to an E/SE side/front silhouette with the face/front bodice visible; a convincing rear-right camera distinction needs correction or independent confirmation.'},
   {'criterion':'ground_plane','result':'HOLD','observation':'The source-plane anchoring is bbox-derived; named flight/contact phases lack independent anatomical sole/ground-plane proof. The technical canvas-foot PASS is not physical support approval.'}],'evidence':{'path':staging_path.relative_to(root).as_posix(),'sha256':hashlib.sha256(staging_path.read_bytes()).hexdigest()},'scale_review_note':'Each source was rendered using its own actual NativeMotionProfile pixel_scale and canvas256 normalization; source resolution differences were not misreported as body-scale defects.','unseen_not_reviewed':['Staged idle/attack/hit/death beyond the examined new RUN sources','Default Main replacement and target/ground interaction'],'approval_granted':False}
 review['original_approval'] = row['approval_preserved']
 review['original_status'] = row['preserved_status']
 review['reasons'] = [finding['observation'] for finding in findings if finding['result'] == verdict]
 reviews.append(review)
summary={'schema':'pr122-boss-visual-review-v1','review_group':'boss-b','date':'2026-10-23','scope':'Sorted boss ids [20:40], 20 bosses including 13 previously VERIFIED_COMPLETED','reviewed_bosses':20,'ids':[row['id'] for row in reviews],'snapshot_git_HEAD':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'frozen':True,'preserved_approved_bosses':sum(r['approval_preserved'] for r in reviews),'verdict_counts':dict(Counter(r['current_review'] for r in reviews)),'method':'Actual private tool vision of reference crops and all source-frame role/view sheets, plus enlarged locomotion and new Ice Queen RUN sources. No chat image output; no art/data/runtime edits.','source_unchanged_vs_HEAD':all(p['matches_HEAD'] for r in reviews for p in r['source_pins']),'approval_policy':'Prior approvals/statuses are unchanged; this creates separate current visual findings and grants no production approvals.','reviews':reviews}
(base/'review-results.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
files=[]
for path in sorted(base.rglob('*')):
 if path.is_file() and path.name!='file-manifest.json' and '__pycache__' not in path.parts:files.append({'path':path.relative_to(root).as_posix(),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(base/'file-manifest.json').write_text(json.dumps({'schema':1,'files':files,'source_assets_changed':0,'new_approvals':0},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'reviewed':20,'preserved_approved':summary['preserved_approved_bosses'],'verdict_counts':summary['verdict_counts'],'evidence_files':len(files)},ensure_ascii=False))
