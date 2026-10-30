extends SceneTree
const CATALOG=preload("res://scripts/animation/animation_catalog.gd")
const SOURCE=preload("res://scripts/animation/source_transform_catalog.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("SOURCE201_TRANSFORM_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE.MANIFEST_PATH))
 var count:int=0;var frames_checked:int=0
 for card:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
  var key:String="transform:"+str(card.sourceId);var entry:Dictionary=document.entries.get(key,{})
  if not entry.get("source201_selected_input",false):continue
  count+=1
  SOURCE.entries={"disabled":{}};var baseline:Resource=CATALOG.for_record("transform",card)
  SOURCE.entries=document.entries;var profile:Resource=CATALOG.for_record("transform",card)
  for property:String in ["layout","motion_style","movement_fps","movement_cadence_width_ratio","reference_speed","attack_hit_ratio","attack_hit_frame","action_hit_frames","attack_animation_speed","collision_offset","projectile_origin","hit_position","shadow_size","death_duration","use_profile_hit_ratio"]:
   check(profile.get(property)==baseline.get(property),"gameplay profile preserved "+key+property)
  for facing:int in range(8):check(profile.projectile_offset(Vector2.from_angle(facing*PI/4))==baseline.projectile_offset(Vector2.from_angle(facing*PI/4)),"projectile geometry unchanged")
  var frames:SpriteFrames=CATALOG.frames_for_profile(profile,"")
  check(frames!=null,"real SpriteFrames load "+key)
  if frames==null:continue
  var provenance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(entry.frames_path.get_base_dir()+"/provenance.json"))
  for role:String in ["idle","walk","run","attack","hit","death","cast"]:
   for facing:int in range(8):
    var track:String=role+"_"+str(facing)
    var refs:Array=provenance.tracks[track].filter(func(r):return r.duration_raw>0)
    check(frames.has_animation(track) and frames.get_frame_count(track)==refs.size(),"exact positive source sequence "+key+track)
    var weight:float=0
    for index:int in range(refs.size()):
     check(frames.get_frame_duration(track,index)==refs[index].duration_raw,"relative source hold preserved")
     check(refs[index].source_heading==(facing+3)%8,"literal source heading; no mirrored/other-body replacement")
     check(frames.get_frame_texture(track,index)!=null,"actual imported native pose")
     weight+=frames.get_frame_duration(track,index);frames_checked+=1
    check(is_equal_approx(weight/frames.get_animation_speed(track),float(refs.size())/8.0),"explicit local cadence without original tick-unit claims")
  for file:String in entry.files_sha256:check(FileAccess.get_sha256(entry.frames_path.get_base_dir()+"/"+file)==entry.files_sha256[file],"pinned runtime file "+file)
  var bounds:Array=entry.canvas_original_grid;var center:=Vector2(bounds[2]-bounds[0],bounds[3]-bounds[1])/2.0
  var foot:=Vector2(entry.foot_in_canvas[0],entry.foot_in_canvas[1])
  check((profile.sprite_offset+(foot-center)*Vector2(0.9,1.0)*profile.pixel_scale).length()<0.001,"fixed projected foot remains actor root")
 check(count==14,"fourteen reviewed source appearances; ambiguous variants not silently bound")
 SOURCE.entries=document.entries
 print("SOURCE201_TRANSFORM_RESULT entries=",count," source_pose_references=",frames_checked," checks=",checks," errors=",errors)
 quit(0 if errors==0 else 1)
