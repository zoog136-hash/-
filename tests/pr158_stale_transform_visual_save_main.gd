extends "res://tests/pr122_published_boss_approval_main.gd"
## Real isolated save/load; refresh current rendering without rewriting saved gear.
func canonical(value: Variant) -> Variant:
 if value is Dictionary:
  var result={}
  var keys=value.keys()
  keys.sort()
  for key in keys:result[key]=canonical(value[key])
  return result
 if value is Array:
  var result=[]
  for entry in value:result.append(canonical(entry))
  return result
 if typeof(value) in [TYPE_INT,TYPE_FLOAT]:return float(value)
 return value

func physical_ids(items: Dictionary) -> Dictionary:
 var result={}
 for slot in items:
  if items[slot] is Dictionary:result[slot]=str(items[slot].get("instance_id",""))
 return result

func run() -> void:
 var world=load("res://Main.tscn").instantiate()
 world.set_process(false)
 world.set_physics_process(false)
 root.add_child(world)
 await process_frame
 if bool(world.hud.get("class_picker_initial")):world.hud.complete_class_selection()
 for node in world.find_children("*","",true,false):
  node.set_process(false)
  node.set_physics_process(false)
 world.save_timer=-10000.
 var actor=world.player
 var outcomes=[]
 # Normalize only the ordinary existing save migration before stale fixtures.
 if not check(world._save_game(true)==OK,"Write normal isolated baseline save"):
  finish(1)
  return
 world._load_game(true)
 check(not world.equipment_collections.save_blocked,"Normal baseline load accepted")
 for id in ["267","258","130"]:
  var current={}
  for row in world.catalog_db["변신"]:
   if str(row.get("sourceId",""))==id:current=row
  if not check(not current.is_empty(),"Known current transform "+id):continue
  var saved=current.duplicate(true)
  saved["name"]="saved-name-"+id
  saved["speed"]=1.125
  saved["instance_id"]="preserved-transform-"+id
  saved["saved_gameplay_payload"]={"enhance":7,"stats":[31,42]}
  saved["image_path"]="res://assets/catalog/8e92f489ef86a806894b9855.png"
  if id=="267":
   saved["animation_profile"]=current.animation_profile.duplicate(true)
   saved.animation_profile.frames_path="res://assets/actors/eight_direction/native_production/girtas_267/r001/SpriteFrames.tres"
  else:saved.erase("animation_profile")
  var before_record=JSON.stringify(saved)
  var old_profile=world.ANIMATION_CATALOG.for_record("transform",saved,str(saved.image_path))
  check(old_profile.frames_path!=str(current.animation_profile.frames_path),"Fixture reproduces stale render before presentation refresh "+id)
  world.equipped_catalog["변신"]=saved
  world._restore_equipped_visuals()
  check(JSON.stringify(saved)==before_record and world.equipped_catalog["변신"]==saved,"Restore does not mutate saved transform record "+id)
  check(world._save_game(true)==OK,"Write real isolated stale save "+id)
  var file_sha=FileAccess.get_sha256(world.save_path())
  var saved_data=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
  var expected_inventory=saved_data.inventory
  var expected_items=saved_data.equipped_items
  var expected_instances=saved_data.item_instances
  var expected_catalog=saved_data.equipped_catalog
  var expected_next=int(saved_data.next_item_instance_id)
  var expected_stats=[world.hp,world.mp,world.gold,actor.move_speed,actor.attack_speed_multiplier,actor.equipment_move_speed_multiplier,actor.collision_layer,actor.collision_mask,actor.get_node("CollisionShape2D").transform]
  actor.clear_transform_visual()
  world._load_game(true)
  check(actor.transform_active and actor.transform_sprite.sprite_frames.resource_path==str(current.animation_profile.frames_path),"Actual loaded Player uses current default, not stale save rendering "+id)
  check(canonical(world.equipped_catalog)==canonical(expected_catalog),"Loaded gameplay catalog snapshot matches parsed saved bytes "+id)
  var loaded=world.equipped_catalog["변신"]
  check(str(loaded.sourceId)==id and loaded.name==saved.name and loaded.speed==saved.speed and loaded.instance_id==saved.instance_id,"Explicit saved source ID name speed and physical transform ID preserved "+id)
  check(canonical(world.inventory)==canonical(expected_inventory) and canonical(world.equipped_items)==canonical(expected_items) and canonical(world.item_instances)==canonical(expected_instances) and world.next_item_instance_id==expected_next,"Inventory and physical equipment records unchanged from parsed save "+id)
  check(physical_ids(world.equipped_items)==physical_ids(expected_items),"Explicit physical equipment instance IDs preserved "+id)
  check(expected_stats==[world.hp,world.mp,world.gold,actor.move_speed,actor.attack_speed_multiplier,actor.equipment_move_speed_multiplier,actor.collision_layer,actor.collision_mask,actor.get_node("CollisionShape2D").transform],"HP speed combat collision unchanged "+id)
  check(FileAccess.get_sha256(world.save_path())==file_sha,"Load refresh never rewrites saved file bytes "+id)
  check(canonical(world.equipped_catalog["변신"])==canonical(saved_data.equipped_catalog["변신"]),"Loaded stale transform remains semantically identical to parsed saved record "+id)
  outcomes.append({"id":id,"current_frames":actor.transform_sprite.sprite_frames.resource_path,"old_frames":old_profile.frames_path,"save_bytes_unchanged":true})
 # Exact IDs take priority; a name match must never rescue an unknown ID.
 var known=world.catalog_db["변신"][0]
 var unknown={"sourceId":"not-a-known-id","name":known.name,"image_path":"saved-path","animation_profile":{"frames_path":"saved-frames"},"speed":1.23}
 check(world._current_transform_visual_record(unknown)==unknown,"Unknown source ID preserves existing fallback without guessing by name")
 var canonical={}
 for row in world.catalog_db["변신"]:
  if str(row.get("sourceId",""))=="130":canonical=row
 var legacy={"name":canonical.name,"speed":1.34,"saved_stat":99}
 var legacy_before=JSON.stringify(legacy)
 var projected=world._current_transform_visual_record(legacy)
 check(JSON.stringify(legacy)==legacy_before and not legacy.has("sourceId") and str(projected.sourceId)=="130" and projected.speed==legacy.speed and projected.saved_stat==99 and projected.image_path==canonical.image_path,"Name-only save unchanged; transient render identity is canonical")
 var legacy_profile=world.ANIMATION_CATALOG.for_record("transform",projected,str(projected.image_path))
 check(legacy_profile.profile_id=="transform:130","Legacy presentation uses numeric transform movement policy")
 var legacy_frames=world.ANIMATION_CATALOG.frames_for_profile(legacy_profile,str(projected.image_path))
 var legacy_motion=load("res://scripts/animation/actor_motion.gd").new()
 legacy_motion.profile=legacy_profile
 legacy_motion.advance(.1,Vector2.RIGHT*legacy_profile.reference_speed*.4)
 legacy_motion._resolve_frames(legacy_frames)
 check(legacy_motion.state=="run" and legacy_motion._resolved_key=="run_0","Slowed name-only mythic keeps visible RUN instead of missing WALK")
 world.catalog_db["변신"].append(canonical.duplicate(true))
 check(world._current_transform_visual_record(legacy)==legacy,"Ambiguous legacy name is unchanged")
 world.catalog_db["변신"].pop_back()
 for id in ["138","140","179","182"]:
  for row in world.catalog_db["변신"]:
   if str(row.get("sourceId",""))==id:
    var stale=row.duplicate(true)
    stale["animation_profile"]={"color_tint":"ff0000","frames_path":"old"}
    var fresh=world._current_transform_visual_record(stale)
    check(fresh.get("animation_profile",{})==row.get("animation_profile",{}),"Current donor/tint presentation preserved "+id)
    check(fresh.sourceId==stale.sourceId and fresh.name==stale.name,"Donor use never changes gameplay identity "+id)
 report.actual_Main=true
 report.real_isolated_save_load=true
 report.stale_save_cases=outcomes
 report.saved_gameplay_records_mutated=false
 report.saved_files_rewritten_on_load=false
 finish(0 if report.errors.is_empty() else 1)
