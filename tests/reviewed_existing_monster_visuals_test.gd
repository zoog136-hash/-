extends SceneTree
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
const LINK=preload("res://scripts/monsters/reviewed_existing_visuals.gd")
const ART=preload("res://scripts/monsters/monster_art.gd")
var checks:int=0
var errors:int=0
class Arena extends Node2D:
 var field_map=null
 var combat_flights=null
 var monster_db:Array=[]
 func is_player_concealed():return false
 func _has_line_of_sight_world(_a:Vector2,_b:Vector2):return true
 func find_world_path(a:Vector2,b:Vector2):return PackedVector2Array([a,b])
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("EXISTING_SOURCE_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var gpu:bool="--gpu" in OS.get_cmdline_user_args()
 if gpu:root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1000,500)
 var all:Array=CATALOG.expand(JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"])
 var before:String=JSON.stringify(all)
 var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LINK.PATH))
 var stage:=Arena.new();root.add_child(stage);stage.monster_db=all
 var player:TwilightPlayer=load("res://scenes/Player.tscn").instantiate();stage.add_child(player);player.set_physics_process(false);player.camera.enabled=false
 var index:int=0
 for name:String in proof.bindings:
  var record:Dictionary={}
  for row:Dictionary in all:
   if row.name==name:record=row;break
  check(not record.is_empty() and not record.get("catalog_only",false),"existing baseline identity "+name)
  LINK.bindings={"disabled":{}}
  var baseline:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();stage.add_child(baseline);baseline.setup(record,player,stage,ART.texture_for(record));baseline.set_physics_process(false)
  LINK.bindings=proof.bindings
  var actor:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();stage.add_child(actor);actor.setup(record,player,stage,ART.texture_for(record));actor.set_physics_process(false);actor.position=Vector2(250+index*500,350);baseline.hide()
  check(actor.motion.profile.frames_path==proof.bindings[name].frames_path,"actual Monster uses reviewed shared frames "+name)
  for property:String in ["max_hp","attack_power","defense_value","armor_class","monster_level","attack_interval","base_move_speed","configured_attack_range","drop_items","loot_source_identity"]:
   check(actor.get(property)==baseline.get(property),"combat/drop identity preserved "+name+" "+property)
  for property:String in ["layout","movement_fps","attack_hit_ratio","attack_hit_frame","action_hit_frames","collision_offset","hit_position","projectile_origin","shadow_size","death_duration"]:
   check(actor.motion.profile.get(property)==baseline.motion.profile.get(property),"gameplay profile preserved "+name+" "+property)
  var source:SpriteFrames=load(proof.bindings[name].frames_path)
  for role:String in ["idle","walk","attack","cast","hit","death"]:
   for facing:int in range(8):
    actor.motion.state=role;actor.motion.facing8=facing;actor.motion.active=role in ["attack","cast"];actor.motion.dead=role=="death";actor.motion.state_clock=0.1;actor.motion.hit_clock=0.08 if role=="hit" else 0.0
    actor.motion.apply(actor.sprite,actor.animation_base_scale)
    check(actor.motion._resolved_key==role+"_"+str(facing) and not actor.sprite.flip_h,"real source role/view "+name)
    check(actor.sprite.texture!=null and not actor.sprite.texture.get_image().is_empty(),"actual pose pixels "+name)
    if gpu:
     await process_frame;await RenderingServer.frame_post_draw
     var viewport:Image=root.get_texture().get_image()
     var box:Rect2=actor.sprite.get_global_transform()*actor.sprite.get_rect()
     var colors:Dictionary={}
     for y:int in range(maxi(0,floori(box.position.y)),mini(viewport.get_height(),ceili(box.end.y))):
      for x:int in range(maxi(0,floori(box.position.x)),mini(viewport.get_width(),ceili(box.end.x))):
       var c:Color=viewport.get_pixel(x,y)
       if maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))>0.08:colors[c.to_rgba32()]=true
     check(colors.size()>8,"actual Monster source body in viewport "+name)

  for path:String in proof.bindings[name].shared_files_sha256:check(FileAccess.get_sha256(path)==proof.bindings[name].shared_files_sha256[path],"shared art SHA")
  var spec:Dictionary=proof.bindings[name];var foot:Vector2=Vector2(spec.foot_in_canvas[0],spec.foot_in_canvas[1]);var center:Vector2=Vector2(spec.canvas_size[0],spec.canvas_size[1])*0.5
  check((actor.motion.profile.sprite_offset+(foot-center)*actor.animation_base_scale).is_zero_approx(),"fixed reviewed ground projection at actor root "+name)
  baseline.queue_free();actor.queue_free();index+=1
 check(JSON.stringify(all)==before,"all 431 catalog records unchanged")
 check(index==2,"two independently evidenced original bodies")
 stage.queue_free();await process_frame;await process_frame
 print("EXISTING_MONSTER_SOURCE_RESULT checks=",checks," errors=",errors," replaced=",index)
 quit(0 if errors==0 else 1)
