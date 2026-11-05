extends SceneTree
## A deliberate host stationary contract does not invent a native walk clip.
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const PACK=preload("res://scripts/monsters/base508_monster_pack_cache.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
const MONSTER=preload("res://scripts/monster.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var errors: Array=[];var path: String="";var pixels: int=0
 # These real movement methods must be safe even if another host path sets
 # velocity, before any terrain controller or navigation is consulted.
 var actor=MONSTER.new();actor.source_host_stationary=true
 actor.position=Vector2(30,40);actor.velocity=Vector2(100,10);actor.path=PackedVector2Array([Vector2(80,40)])
 actor._move_toward(Vector2(80,40),1.0)
 if actor.position!=Vector2(30,40) or actor.velocity!=Vector2.ZERO or not actor.path.is_empty():errors.append("Stationary pursuit moved actor")
 actor.velocity=Vector2(200,0);actor._move_on_map()
 if actor.position!=Vector2(30,40) or actor.velocity!=Vector2.ZERO:errors.append("Stationary physics moved actor")
 actor.free()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--lineagem-monster-pack="):path=arg.trim_prefix("--lineagem-monster-pack=")
 if path.is_empty() or not FileAccess.file_exists(path):
  print("BASE508_STATIONARY_MOVEMENT ",JSON.stringify({"errors":errors,"private_actor_view_skipped":true}))
  quit(0 if errors.is_empty() else 1);return
 var key: String="lineagem_base508:npc:47744:spawn:277472:territory:136572"
 var record: Dictionary=ROSTER.record(key,path,{"source_m_allow_contextual":true,"speed":123.0})
 if record.is_empty():errors.append("Exact stationary source record rejected")
 else:
  if float(record.get("speed",-1))!=0.0 or not bool(record.get("source_m_host_stationary",false)):errors.append("Caller could override stationary speed")
  if int(record.get("source_m_host_action_contract",{}).get("attack_action_id",-1))!=1:errors.append("Wrong native action selected")
  if not ROSTER.record(key,path).is_empty():errors.append("Stationary actor enabled without explicit context permission")
  var packed: Dictionary=PACK.actor(path,47744)
  if packed.get("tracks",{}).has("walk") or not packed.get("source_actor_profile",{}).get("missing_roles",[]).has("walk"):errors.append("Missing walk clip manufactured")
  var view=VIEW.new()
  if not view.configure(record,path):errors.append("Stationary original view rejected")
  elif not view.advance_source_action(1,0.0,0,1):errors.append("Original action1 unavailable")
  else:
   for layer: Sprite2D in view._layers:
    if layer.visible and layer.texture!=null:pixels+=1
   if view.supports_state("walk"):errors.append("View invented walk")
   view.clear_source_action();view.advance(0.0,"idle",0,2,false,false)
   if view.source_state_status.get("role","")!="idle":errors.append("Stationary did not return to authored idle")
  view.free()
 print("BASE508_STATIONARY_SOURCE ",JSON.stringify({"errors":errors,"source_layers":pixels,"movement_guard":true,"source_geographic_spawns":0}))
 quit(0 if errors.is_empty() and pixels>0 else 1)
