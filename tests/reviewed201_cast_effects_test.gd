extends SceneTree
## Production SkillService with a deterministic world/marker boundary; not Main.
const SERVICE=preload("res://scripts/skills/skill_service.gd")
const SOURCE=preload("res://scripts/skills/source_effect_catalog.gd")
const BRIDGE=preload("res://scripts/skills/skill_similar_bridge.gd")
class PlayerFixture extends TwilightPlayer:
 func _ready():set_physics_process(false);set_process(false)
 func pulse_attack():pass
 func set_skill_speed_multiplier(_value:float):pass
class MonsterFixture extends TwilightMonster:
 func _ready():set_physics_process(false);set_process(false)
 func combat_hit_position()->Vector2:return global_position+Vector2(0,-24)
 func take_damage(amount:int,_critical:bool=false,_kind:String="")->void:hp-=amount
class HudFixture extends Node:
 var messages:Array=[]
 func show_message(value:String):messages.append(value)
class WorldFixture extends Node2D:
 var player:PlayerFixture
 var hud=HudFixture.new()
 var monsters_root=Node2D.new()
 var target:MonsterFixture
 var job_class:String="마법사"
 var level:int=90
 var gold:int=100000
 var mp:int=10000
 var hp:int=100
 var inventory:Dictionary={}
 var equipped_items:Dictionary={"weapon":{"type":"지팡이"}}
 var pending_attack:Dictionary={}
 var active_skill_buffs:Dictionary={}
 var skill_global_cooldown:float=0
 var skill_cooldowns:Dictionary={}
 var rng=RandomNumberGenerator.new()
 var combat_vfx:Variant=null
 var queued:Callable
 var queued_duration:float=0
 var saves:int=0
 func _current_weapon_type():return "지팡이"
 func _all_equipped_records():return []
 func _inventory_total_weight():return 0
 func _carrying_capacity():return 100
 func _effective_max_hp():return 1000
 func _effective_max_mp():return 10000
 func _effective_attribute(_key:String):return 10
 func _skill_cooldown_factor():return 1.0
 func _active_skill_speed_multiplier():return 1.0
 func _update_hud():pass
 func _save_game(_force:bool):saves+=1
 func _refresh_skill_stealth_visual():pass
 func _refresh_speed_modifiers():pass
 func _refresh_combat_hud():pass
 func _break_invisibility():pass
 func _skill_target(_range:float):return target
 func _has_line_of_sight_world(_a:Vector2,_b:Vector2):return true
 func _magic_accuracy_stat():return 100
 func _magic_hit_chance(_a:int,_b:int):return 1.0
 func _elemental_damage_to_monster(amount:int,_element:String,_target:TwilightMonster):return amount
 func _player_critical_rate(_kind:String):return 0
 func _critical_chance(_rate:int,_resistance:int):return 0.0
 func _player_critical_damage(amount:int,_kind:String):return amount
 func _deal_successful_player_hit(monster:TwilightMonster,amount:int,critical:bool):monster.take_damage(amount,critical,"fixture")
 func _queue_player_attack(_target:TwilightMonster,_kind:String,callback:Callable,duration:float,_normal:bool=false,_range:float=0.0):
  queued=callback;queued_duration=duration;pending_attack={};return true
class Anchor extends Node2D:
 func _draw():draw_circle(Vector2.ZERO,5,Color("80ac92"));draw_line(Vector2(-12,0),Vector2(12,0),Color("80ac92"))
var checks:int=0
var failures:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("REVIEWED_CAST_FAIL ",label)
func digest(bytes:PackedByteArray)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func player_fixture()->PlayerFixture:
 var player=PlayerFixture.new()
 for entry:Array in [[NavigationAgent2D.new(),"NavigationAgent2D"],[AnimatedSprite2D.new(),"ClassSprite"],[AnimatedSprite2D.new(),"TransformSprite"],[Camera2D.new(),"Camera2D"]]:entry[0].name=entry[1];player.add_child(entry[0])
 player.get_node("Camera2D").enabled=false
 return player
func monster_fixture()->MonsterFixture:
 var monster=MonsterFixture.new()
 for entry:Array in [[Sprite2D.new(),"Sprite2D"],[NavigationAgent2D.new(),"NavigationAgent2D"],[Label.new(),"NameLabel"],[ProgressBar.new(),"HPBar"]]:entry[0].name=entry[1];monster.add_child(entry[0])
 monster.hp=10000;return monster
func _initialize():call_deferred("run")
func comparison(frames:SpriteFrames,layout:Dictionary,point:Vector2,label:String):
 var sprite=Sprite2D.new();sprite.texture=frames.get_frame_texture("source",frames.get_frame_count("source")/2);sprite.centered=false;sprite.offset=Vector2(layout.offset[0],layout.offset[1]);sprite.position=point
 var edge=maxf(sprite.texture.get_width(),sprite.texture.get_height());sprite.scale=Vector2.ONE*minf(1,260.0/edge);root.add_child(sprite)
 var marker=Anchor.new();marker.position=point;root.add_child(marker)
 var text=Label.new();text.text=label;text.position=Vector2(point.x-150,point.y-190);root.add_child(text)
func run():
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/reviewed201_cast_effects.json"))
 var source=SOURCE.new();var bridge=BRIDGE.new()
 var world=WorldFixture.new();root.add_child(world)
 world.player=player_fixture();world.add_child(world.player);world.player.global_position=Vector2(-1000,-1000)
 world.add_child(world.hud);world.add_child(world.monsters_root)
 world.target=monster_fixture();world.monsters_root.add_child(world.target);world.target.global_position=Vector2(-950,-1000)
 var service=SERVICE.new();service.configure(world);service.catalog.learned.clear()
 var frame_checks:int=0;var casts:int=0;var attacks:int=0
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(800,2570)
 for row_index:int in range(plan.cases.size()):
  var spec:Dictionary=plan.cases[row_index];var row:Dictionary=service.catalog.record_for(str(spec.skill_id));world.job_class="마법사" if str(row["class"])=="공용" else str(row["class"]);service.catalog.learned={str(row.id):1}
  check(not bool(row.get("runtime_blocked",false)) and str(row.get("activation","active"))=="active","only an existing active skill")
  var resource:Dictionary=bridge.effects[spec.group_id];var frames:SpriteFrames=bridge.frames_for_resource(str(spec.group_id))
  check(frames!=null,"on-demand committed native atlas")
  for index:int in range(int(resource.count)):
   var decoded:Dictionary=source.frame(str(spec.group_id),str(spec.record_key),index)
   var padded=Image.create_empty(int(resource.width),int(resource.height),false,Image.FORMAT_RGBA8)
   padded.blit_rect(decoded.image,Rect2i(Vector2i.ZERO,decoded.image.get_size()),decoded.bounds.position-Vector2i(resource.offset[0],resource.offset[1]))
   var actual:Image=frames.get_frame_texture("source",index).get_image()
   check(digest(padded.get_data())==digest(actual.get_data()),"exact native source RGBA and original coordinate padding")
   frame_checks+=1
  bridge.release(str(spec.group_id));bridge.trim()
  service.vfx.clear();world.skill_cooldowns.clear();world.skill_global_cooldown=0;world.pending_attack.clear();world.active_skill_buffs.clear();world.mp=10000;world.hp=100;world.target.hp=10000
  if row.mode=="cleanse":world.player.apply_poison(30,1)
  var resolved:Dictionary=service.catalog.resolve(row)
  for item:String in resolved.get("items",{}):world.inventory[item]=10000
  var mp:int=world.mp;var target_hp:int=world.target.hp
  check(service.cast(row),"production SkillService.cast "+str(spec.name));casts+=1
  check(world.mp==mp-int(resolved.mp),"one real MP charge")
  check(world.skill_global_cooldown==float(resolved.global_cooldown),"same gameplay cooldown")
  if row.mode=="attack":
   attacks+=1;check(world.target.hp==target_hp,"visual starts before damage marker")
   check(is_equal_approx(world.queued_duration,float(resolved.cast_time)),"original cast clock reaches world scheduler")
   check(not service.cast(row) and world.mp==mp-int(resolved.mp),"busy/cooldown rejects second charge")
   world.pending_attack.clear();world.queued.call()
   check(world.target.hp<target_hp and service.event_counts.get(str(row.id),0)==1,"production impact applies one hit")
  elif row.mode=="cleanse":check(not world.player.is_poisoned(),"production poison removal")
  elif row.mode=="heal":check(world.hp>100,"production healing applied")
  else:check(world.active_skill_buffs.has(str(row.name)),"production buff applied")
  var emitted:Dictionary={}
  for live:Dictionary in service.vfx.live:
   if str(live.similar_key)==str(spec.group_id):emitted=live
  check(not emitted.is_empty(),"actual cast/impact reaches reviewed source, not preview-only")
  if not emitted.is_empty():
   var sprite:AnimatedSprite2D=emitted.spx_sprite
   var point:Vector2=world.player.global_position if str(spec.phases[0])=="cast" or row.mode in ["heal","cleanse"] else world.target.combat_hit_position()
   check(sprite.global_position==point,"existing cast/impact anchor")
   check(not sprite.sprite_frames.get_animation_loop("source"),"one-shot active effect")
   if DisplayServer.get_name()!="headless":
    var old_key:String=str(spec.previous_phases[spec.phases[0]]);var before:SpriteFrames=bridge.frames_for_resource(old_key)
    if bool(spec.get("previous_runtime_emission",true)):
     comparison(before,bridge.effects[old_key],Vector2(200,240+row_index*280),str(spec.name)+" / before")
    else:
     var absent=Label.new();absent.text=str(spec.name)+" / before: no cast effect";absent.position=Vector2(50,50+row_index*280);root.add_child(absent)
    comparison(sprite.sprite_frames,resource,Vector2(600,240+row_index*280),str(spec.name)+" / after")
    bridge.release(old_key)
  service.vfx.clear()
  check(service.vfx.similar_bridge.cache.is_empty(),"released effects unpin all resources")
 for name:String in ["엘리멘탈 스피드","다크 러쉬","고스트 스텝"]:
  var row:Dictionary=service.catalog.record_for(name);var phases:Dictionary=bridge.binding_for(str(row.id)).phases
  check(phases.keys()==["learn"],"speed passive stays learn-only")
 check(casts==9 and attacks==4 and frame_checks==163,"nine real service casts, four controlled hit markers, 163 native frames")
 if DisplayServer.get_name()!="headless":
  service.vfx.set_process(false);await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var image:Image=root.get_texture().get_image();check(image!=null and image.get_used_rect().size!=Vector2i.ZERO,"actual OpenGL viewport readback")
  check(image.get_size()==Vector2i(800,2570),"all nine comparison rows fit the rendered viewport")
  var path:String=OS.get_environment("TWILIGHT_CAST_COMPARISON")
  if not path.is_empty():check(image.save_png(path)==OK,"single before/after evidence saved")
 service.clear();world.queue_free();await process_frame
 print("REVIEWED_CAST_EFFECTS_RESULT checks=",checks," failures=",failures," service_casts=",casts," controlled_damage_markers=",attacks," native_frames=",frame_checks," Main_device_casts=unverified")
 quit(0 if failures==0 else 1)
