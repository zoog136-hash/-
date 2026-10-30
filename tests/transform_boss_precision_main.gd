extends "res://tests/transform_unique_precision_main.gd"
## Actual Main -> current monster catalog -> real Monster.setup default resources.
## Controlled presentation / real collision movement, not live AI damage/loot QA.
## Optional TRANSFORM_BOSS_PRECISION_IDS/ROLES/DIRECTIONS select a bounded regression.
const ACTIVE_REPAIR_ATTACKS={"monster:그림 리퍼:6": {"atlas": "res://assets/actors/eight_direction/boss_draft_first/grim_reaper/reviewed_parts_r001/N-attack.png", "sha256": "41c4e7265b58dd7717db5a24dc62de32d7ec8182263f9e05df95ab0a35276a8c"}, "monster:교만의 왕자 데우스:6": {"atlas": "res://assets/actors/eight_direction/boss_draft_first/prince_deus/reviewed_parts_r009/N-attack.png", "sha256": "4269ef17476f8b9bd5c52736529c110b0f5e962e12dbcb686a8638d207eb59c6"}, "monster:교만의 왕자 데우스:5": {"atlas": "res://assets/actors/eight_direction/boss_draft_first/prince_deus/reviewed_parts_r009/NW-attack.png", "sha256": "b439fdd4af587b88479bebf1a8497fba33c7a741966678209c351133ad55c82c"}}
var scope_roles:Array=["idle","run","attack","hit","death"]
var scope_directions:Array=[0,1,2,3,4,5,6,7]
var boss:Node
var overview:Image
var current_row=0
var source_plan:Array=[]
var stage_strikes:Array=[]
var homes:Dictionary={}

func global_state() -> String:
 return JSON.stringify([world_ref.hp,world_ref.mp,world_ref.gold,world_ref.inventory,world_ref.equipped_items,world_ref.equipped_catalog,world_ref.item_instances,world_ref.field_population.boss_director.export_state(),actor.collision_layer,actor.collision_mask])

func reset_boss() -> void:
 boss.motion.dead=false;boss.motion.cancel_attack();boss.motion.hit_clock=0.
 boss.velocity=Vector2.ZERO;boss.motion.advance(.5,Vector2.ZERO)

func tick_pose(velocity:Vector2=Vector2.ZERO) -> void:
 boss.motion.advance(1./120.,velocity)
 boss.motion.apply(boss.sprite,boss.animation_base_scale)

func capture_boss(column:int) -> void:
 actor.camera.offset=boss.global_position-actor.global_position
 actor.camera.force_update_scroll()
 if not await map_ready():return
 await process_frame
 await RenderingServer.frame_post_draw
 var point=boss.get_global_transform_with_canvas()*Vector2.ZERO
 var crop=root.get_texture().get_image().get_region(Rect2i(Vector2i(point)+Vector2i(-100,-190),Vector2i(200,220)))
 overview.blit_rect(crop,Rect2i(0,0,200,220),Vector2i(column*200,current_row*220))

func record_sample(id:String,d:int,role:String) -> void:
 var tex:Texture2D=boss.sprite.texture
 var row={"id":id,"direction":d,"role":role,"resolved_key":boss.motion._resolved_key,"phase":boss.motion._resolved_frame_index,"body":boss.global_position,"sprite_position":boss.sprite.position,"offset":boss.sprite.offset,"scale":boss.sprite.scale,"rotation":boss.sprite.rotation}
 if tex is AtlasTexture:row["atlas"]=tex.atlas.resource_path;row["region"]=tex.region;row["margin"]=tex.margin
 if role=="attack" and ACTIVE_REPAIR_ATTACKS.has(id+":"+str(d)):
  var pinned:Dictionary=ACTIVE_REPAIR_ATTACKS[id+":"+str(d)]
  check(tex is AtlasTexture and tex.atlas.resource_path==pinned.atlas and FileAccess.get_sha256(pinned.atlas)==pinned.sha256,"Existing active repaired attack source stays unchanged after declared dependency relocation "+id)
 report["projection_samples"].append(row)

func role_case(id:String,d:int,role:String) -> void:
 reset_boss();boss.motion.face(Vector2.RIGHT.rotated(d*PI/4.))
 var frames:SpriteFrames=boss.motion.frame_source
 var required=role+"_"+str(2 if role=="death" else d)
 var before_strikes=stage_strikes.size();var sequence=-1
 if role=="attack":sequence=boss.motion.begin_attack(minf(.68,boss.attack_interval*.75),boss.motion.direction,boss.motion.profile.motion_style,boss.motion.profile.marker_for(boss.motion.profile.motion_style))
 elif role=="hit":
  boss.motion.react(false,Vector2.ZERO)
  # react initializes clocks; advance selects the hit state before resolving it.
  # Zero elapsed time preserves every real phase for the sampled timeline.
  boss.motion.advance(0.,Vector2.ZERO)
 elif role=="death":boss.motion.die()
 boss.motion.invalidate_pose();boss.motion._resolve_frames(frames)
 var actual:String=boss.motion._resolved_key
 # Confirm actual resolver output before interpreting sparse static clip names.
 if not check(actual==required and boss.motion._resolved_role!="unavailable" and frames.has_animation(actual),"Current default boss required role/view available "+id+" "+required+" actual="+actual+" role="+boss.motion._resolved_role):
  report.cases.append({"id":id,"direction":d,"role":role,"required":required,"actual":actual,"available":false,"stale_pose_not_counted_as_success":true});return
 var count=frames.get_frame_count(actual);var seen={};var seconds=1.0
 if role=="idle":
  var units=0.
  for phase in range(count):units+=frames.get_frame_duration(actual,phase)
  seconds=units/frames.get_animation_speed(actual)*1.1+.03
 elif role=="attack":seconds=boss.motion.attack_duration+.12
 elif role=="hit":seconds=maxf(boss.motion.hit_duration,boss.motion._native_hit_duration)*1.25+.02
 elif role=="death":seconds=boss.motion.profile.death_duration+.7
 var body:Vector2=boss.position;var collision:Transform2D=boss.get_node("CollisionShape2D").transform;var marker=false
 for tick in range(int(ceil(seconds*120.))+5):
  tick_pose()
  check(boss.position==body and boss.get_node("CollisionShape2D").transform==collision,"Presentation never changes boss body/collider "+id)
  check(boss.sprite.texture!=null and not boss.sprite.flip_h,"Actual boss full source texture/no mirror "+id)
  if boss.motion._resolved_key==actual:
   var phase:int=boss.motion._resolved_frame_index
   check(phase>=0 and phase<count and boss.sprite.texture==frames.get_frame_texture(actual,phase),"Actual boss Sprite2D owns resolved source phase "+id)
   if not seen.has(phase):
    seen[phase]=true;record_sample(id,d,role)
    if role=="idle" and phase==0:await capture_boss(d*5)
  if role=="attack" and stage_strikes.size()>before_strikes and not marker:
   marker=true
   check(stage_strikes.size()==before_strikes+1 and int(stage_strikes.back())==sequence and boss.motion._resolved_key==required and boss.motion._resolved_frame_index==mini(count-1,boss.motion.profile.hit_frame_for("attack")),"One authoritative boss attack marker matches actual source phase "+id)
   await capture_boss(d*5+4)
 check(seen.size()==count,"All actual boss timeline phases "+id+" "+required+" "+str(seen.keys())+"/"+str(count))
 if role=="attack":check(marker and stage_strikes.size()==before_strikes+1,"Boss combat release count "+id)
 else:check(stage_strikes.size()==before_strikes,"Nonattack boss presentation emits no release "+id)
 if role=="death":check(boss.motion.state=="corpse" and boss.motion._resolved_frame_index==count-1 and boss.sprite.texture==frames.get_frame_texture(actual,count-1),"Boss South death terminal/corpse holds original last source pose "+id)
 report.cases.append({"id":id,"direction":d,"role":role,"required":required,"actual":actual,"available":true,"expected":count,"seen":seen.keys(),"marker":marker})

func movement_case(id:String,d:int) -> void:
 reset_boss();boss.global_position=homes[d]
 var aim=Vector2.RIGHT.rotated(d*PI/4.);var frames:SpriteFrames=boss.motion.frame_source;var key="run_"+str(d)
 var start:Vector2=boss.global_position;var seen={};var collision:Transform2D=boss.get_node("CollisionShape2D").transform
 await physics_frame;await physics_frame
 for tick in range(56):
  check(not boss.is_physics_processing() and not world_ref.is_processing() and not world_ref.is_physics_processing(),"One controlled boss physics owner")
  await physics_frame
  var previous:Vector2=boss.global_position
  boss.velocity=aim*boss.base_move_speed
  boss._move_on_map()
  boss.motion.advance(1./60.,(boss.global_position-previous)*60.)
  boss.motion.apply(boss.sprite,boss.animation_base_scale)
  check(boss.get_node("CollisionShape2D").transform==collision and not boss.sprite.flip_h,"Real boss locomotion preserves collision/mirroring "+id)
  if boss.motion._resolved_key==key:
   var phase:int=boss.motion._resolved_frame_index
   if not seen.has(phase):
    seen[phase]=true;record_sample(id,d,"physical_run")
    var targets=[0,2,frames.get_frame_count(key)-1]
    if phase in targets:await capture_boss(d*5+1+targets.find(phase))
 var available=frames.has_animation(key) and boss.motion._resolved_role!="unavailable"
 check(available,"Actual boss moving resolves exact RUN view "+id+" "+key)
 if available:check(seen.size()==frames.get_frame_count(key),"All boss RUN timeline phases under real map movement "+id+" "+key)
 check(boss.global_position.distance_to(start)>20. and boss.global_position.distance_to(start)<330.,"Real boss map/collider displacement bounded "+id)
 boss.velocity=Vector2.ZERO
 for tick in range(5):
  await physics_frame;boss._move_on_map();boss.motion.advance(1./60.,Vector2.ZERO);boss.motion.apply(boss.sprite,boss.animation_base_scale)
 var stopped:Vector2=boss.position
 for tick in range(4):await physics_frame;boss._move_on_map()
 check(boss.position.distance_to(stopped)<.05,"Actual boss stop has no body drift "+id)
 report.cases.append({"id":id,"direction":d,"role":"physical_run_stop","required":key,"available":available,"seen":seen.keys(),"displacement":boss.global_position-start})

func expected_boss_routes() -> Array:
 # The connection ledger pins the current selection. Export provenance retains
 # the immutable prior source/SHA separately; neither is a new art approval.
 var ledger:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_boss_runtime_connections.json"))
 var moved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actors/eight_direction/refined_production_20261030/production_boss_export_r001/source-provenance.json"))
 check(moved.actors.size()==2 and moved.actors.has("monster:그림 리퍼") and moved.actors.has("monster:교만의 왕자 데우스"),"Exactly two declared export-safe source paths")
 var rows=[]
 for original:Dictionary in ledger.connections:
  var row={"key":str(original.id),"frames":str(original.frames),"sha256":str(original.frames_sha256)}
  if moved.actors.has(row.key):
   var move:Dictionary=moved.actors[row.key]
   check(row.frames==move.selected_frames and row.sha256==move.selected_sha256,"Current connection ledger matches the independently pinned export revision")
   check(FileAccess.get_sha256(move.prior_selected_frames)==move.prior_frames_sha256,"Immutable prior boss selection remains byte-identical in export provenance")
  rows.append(row)
 return rows

func run() -> void:
 Engine.max_fps=120;root.size=Vector2i(1280,720)
 source_plan=expected_boss_routes()
 var requested=OS.get_environment("TRANSFORM_BOSS_PRECISION_IDS").split(",",false)
 var roles=OS.get_environment("TRANSFORM_BOSS_PRECISION_ROLES").split(",",false)
 var directions=OS.get_environment("TRANSFORM_BOSS_PRECISION_DIRECTIONS").split(",",false)
 if not roles.is_empty():
  for role:String in roles:check(role in scope_roles,"Explicit boss role scope exists")
  scope_roles=Array(roles)
 if not directions.is_empty():
  var values=[]
  for key:String in directions:
   check(key.is_valid_int() and int(key) in scope_directions,"Explicit boss facing scope is an exact known direction")
   values.append(int(key))
  scope_directions=values
 for key:String in requested:check(source_plan.any(func(row:Dictionary)->bool:return row.key==key),"Explicit boss identity belongs to original19")
 check(source_plan.size()==19,"Exactly nineteen explicit published/registered boss connections")
 report["projection_samples"]=[];report["actor_routes"]=[];report["scope"]="Actual Main / real Monster.setup defaults. Controlled role clock and real collider movement; no live AI damage, rewards, kill or persistent boss state changes."
 report["AI_combat_damage_loot_or_natural_spawns_exercised"]=false
 report["new_art_approvals"]=0
 var world=load("res://Main.tscn").instantiate();world_ref=world;root.add_child(world)
 await process_frame
 if bool(world.hud.get("class_picker_initial")):world.hud.complete_class_selection()
 world.set_process(false);world.set_physics_process(false);world.save_timer=-10000.
 for node in world.find_children("*","",true,false):node.set_process(false);node.set_physics_process(false)
 actor=world.player;actor.camera.make_current()
 check(world.field_map!=null and bool(world.field_map.get_meta("source_map84",false)),"Latest main actual source84 field, no missing-pack fallback")
 if not await map_ready():finish(1);return
 var baseline=global_state();var start:Vector2=actor.position;var original_camera_offset:Vector2=actor.camera.offset
 overview=Image.create(8000,19*220,false,Image.FORMAT_RGBA8);overview.fill(Color(.1,.11,.13,1.))
 var region:Vector2i=world._world_to_cell(start)
 for expected:Dictionary in source_plan:
  var id:String=expected.key;var record={}
  if not requested.is_empty() and not id in requested:continue
  for row:Dictionary in world.monster_db:
   if "monster:"+str(row.name)==id:record=row.duplicate(true)
  if not check(not record.is_empty(),"Actual expanded monster catalog contains exact boss "+id):continue
  var original_record=JSON.stringify(record)
  boss=world.MONSTER_SCENE.instantiate();boss.position=world.monsters_root.to_local(start);world.monsters_root.add_child(boss)
  preload("res://scripts/maps/source_body_profile.gd").apply(boss,false)
  boss.setup(record,actor,world,world._monster_texture(record))
  preload("res://scripts/maps/source_body_profile.gd").apply(boss,world.field_map is RemakePlayableField or world.field_map is NativePngField)
  boss.set_process(false);boss.set_physics_process(false)
  # Factory world hit/death signals are deliberately not connected: animation QA
  # never awards loot or damages the real isolated-save Player.
  boss.motion.strike.connect(func(sequence:int)->void:stage_strikes.append(sequence))
  check(boss.is_boss and boss.motion.profile.frames_path==expected.frames and boss.motion.frame_source!=null and boss.motion.frame_source.resource_path==expected.frames,"Actual independent default boss path without candidate injection "+id)
  check(FileAccess.get_sha256(expected.frames)==expected.sha256,"Exact current boss resource SHA "+id)
  check(boss.max_hp==maxi(30,int(record.hp)) and boss.hp==boss.max_hp and is_equal_approx(boss.attack_interval,maxf(.12,float(record.get("attack_interval",1.25)))),"Actual boss HP/combat interval unchanged "+id)
  report.actor_routes.append({"id":id,"profile_id":boss.motion.profile.profile_id,"frames":boss.motion.profile.frames_path,"actual_resource":boss.motion.frame_source.resource_path,"sha256":FileAccess.get_sha256(expected.frames),"is_boss":boss.is_boss,"source_override":false})
  await physics_frame;await physics_frame
  check(PhysicsServer2D.body_get_space(boss.get_rid()).is_valid(),"Actual boss collider remains in real map space "+id)
  homes={}
  if "run" in scope_roles:
   for d:int in scope_directions:
    var aim=Vector2.RIGHT.rotated(d*PI/4.)
    for radius in [0,8,16,32,48,64]:
     for side in range(24):
      var offset=Vector2.RIGHT.rotated(side*TAU/24.)*radius;var p:Vector2=world._cell_to_world(region+Vector2i(roundi(offset.x),roundi(offset.y)))
      if not world.field_map.source_line_clear(p,p+aim*330.) or not world.field_map.line_clear(p,p+aim*330.):continue
      var legal=true
      for step in range(23):
       if not world._is_walkable_world(p+aim*minf(step*15.,330.)):legal=false;break
      if not legal:continue
      var from:Transform2D=boss.global_transform;from.origin=p
      if boss.test_move(from,Vector2.ZERO,null,.08,true) or boss.test_move(from,aim*330.):continue
      homes[d]=p;break
     if homes.has(d):break
    if not check(homes.has(d),"Actual boss native330px path/collider clearance "+str(d)):finish(1);return
  for d:int in scope_directions:
   boss.global_position=homes[d] if homes.has(d) else start+Vector2(170,60)
   if "idle" in scope_roles:await role_case(id,d,"idle")
   if "run" in scope_roles:await movement_case(id,d)
   if "idle" in scope_roles:await role_case(id,d,"idle")
   if "attack" in scope_roles:await role_case(id,d,"attack")
   if "hit" in scope_roles:await role_case(id,d,"hit")
  if "death" in scope_roles:await role_case(id,2,"death")
  check(JSON.stringify(record)==original_record and global_state()==baseline,"Boss controlled playback preserves player inventory/equipment/save/boss state and original NPC record "+id)
  report["completed_actors"]=current_row+1
  var f=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t")+"\n");f.close()
  overview.save_jpg(output.path_join("boss19-actual-Main-internal-overview.jpg"),.9)
  boss.queue_free();await process_frame;current_row+=1
  print("BOSS_PRECISION_CHECKPOINT ",id," completed=",current_row," errors=",report.errors.size())
 actor.camera.offset=original_camera_offset
 report["current_main_source_map84_GPU_texture_checks"]=map_texture_checks.size()
 report["runtime_sources"]={"monster":FileAccess.get_sha256("res://scripts/monster.gd"),"world":FileAccess.get_sha256("res://scripts/world.gd"),"actor_motion":FileAccess.get_sha256("res://scripts/animation/actor_motion.gd")}
 finish(0 if report.errors.is_empty() else 1)
