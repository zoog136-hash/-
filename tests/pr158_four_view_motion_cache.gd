extends "res://tests/pr122_published_boss_approval_main.gd"
## Real four-view resource: adjacent cardinal choices can share one facing8.
func run() -> void:
 var records=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]
 var catalog=load("res://scripts/animation/animation_catalog.gd")
 var motion_type=load("res://scripts/animation/actor_motion.gd")
 var current={}
 for record in records:
  if str(record.get("sourceId",""))=="410":current=record
 var profile=catalog.for_record("transform",current,str(current.image_path))
 var frames=catalog.frames_for_profile(profile,str(current.image_path))
 var motion=motion_type.new()
 motion.profile=profile
 var traces=[]
 for moving in [false,true]:
  for aim in [Vector2(1.01,1),Vector2(1,1.01)]:
   motion.face(aim)
   motion.advance(.5,aim*210. if moving else Vector2.ZERO)
   motion._resolve_frames(frames)
   var role="run" if moving else "idle"
   var expected=role+"_"+["down","up","left","right"][motion.facing4]
   var entry={"state":motion.state,"facing8":motion.facing8,"facing4":motion.facing4,"expected":expected,"actual":motion._resolved_key}
   traces.append(entry)
   print("FOUR_VIEW_CACHE_TRACE ",JSON.stringify(entry))
   check(motion._resolved_key==expected,"Current cardinal view is never stale within the same facing8")
 if OS.get_environment("PR158_CACHE_REPRO_ONLY")!="1":
  var contract=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actors/eight_direction/native_production/mythic-retained-r158-source-provenance.json"))
  var checks=0
  for id in contract.actors:
   var row={}
   for record in records:
    if str(record.get("sourceId",""))==id:row=record
   var before=row.duplicate(true)
   var prior=contract.actors[id].prior_animation_profile
   if prior is Dictionary:before.animation_profile=prior.duplicate(true)
   else:before.erase("animation_profile")
   var old_profile=catalog.for_record("transform",before,str(before.image_path))
   var new_profile=catalog.for_record("transform",row,str(row.image_path))
   for d in range(8):
    var aim=Vector2.RIGHT.rotated(d*PI/4.)
    check(old_profile.projectile_offset(aim).is_equal_approx(new_profile.projectile_offset(aim)),"Original projectile aim-space origin preserved "+id+" "+str(d))
    checks+=1
   for style in ["slash","thrust","heavy","bow","magic"]:check(is_equal_approx(old_profile.marker_for(style),new_profile.marker_for(style)),"Original combat marker ratio preserved "+id)
  var diagonal=Vector2(1,1.01)
  motion.begin_attack(.8,diagonal)
  motion._resolve_frames(frames)
  check(motion.facing8==1 and motion.facing4==0 and motion._resolved_key=="attack_down","Attack uses actual post-aim cardinal view")
  var donor={}
  for record in records:
   if str(record.get("sourceId",""))=="139":donor=record
  var native_profile=catalog.for_record("transform",donor,str(donor.image_path))
  var native_frames=catalog.frames_for_profile(native_profile,str(donor.image_path))
  var native_motion=motion_type.new()
  native_motion.profile=native_profile
  for aim in [Vector2(1.01,1),Vector2(1,1.01)]:
   native_motion.face(aim)
   native_motion.advance(.5,Vector2.ZERO)
   native_motion._resolve_frames(native_frames)
   check(native_motion.facing8==1 and native_motion._resolved_key=="idle_1","Native eight-view direction is unchanged by cardinal cache key")
  report.projectile_offset_direction_checks=checks
  report.combat_marker_ratio_checks=contract.actors.size()*5
 report.cardinal_cache_traces=traces
 report.actual_source_resource=frames.resource_path
 report.actual_Motion_class=true
 finish(0 if report.errors.is_empty() else 1)
