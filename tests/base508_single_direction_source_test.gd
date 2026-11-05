extends SceneTree
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const PACK=preload("res://scripts/monsters/base508_monster_pack_cache.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--lineagem-monster-pack="):path=arg.trim_prefix("--lineagem-monster-pack=")
 if path.is_empty():print("BASE508_SINGLE_DIRECTION_SKIPPED: explicit private manifest required");quit(0);return
 var manifest: Dictionary=PACK.manifest(path);var errors: Array=[];var count: int=0;var layers: int=0
 for nid: String in manifest.get("records",{}):
  var actor: Dictionary=PACK.actor(path,int(nid))
  if int(actor.get("source_partial_direction_contract",0))!=1:continue
  var pair: Dictionary=actor.source_contexts[0]
  var key: String="lineagem_base508:npc:%d:spawn:%d:territory:%d" % [int(nid),int(pair.spawn_view_id),int(pair.territory_link_id)]
  var record: Dictionary=ROSTER.visual_record(key,path,true)
  if record.is_empty() or int(record.get("source_m_fixed_source_slot",-1))!=0:errors.append("Literal source slot0 not available "+nid);continue
  if not ROSTER.record(key,path,{"source_m_allow_contextual":true}).is_empty():errors.append("Partial directions enabled ordinary combat "+nid)
  for track: Dictionary in actor.tracks.values():
   if track.directions[0].is_empty():errors.append("Authored direction lost "+nid)
   for slot: int in range(1,8):
    if not track.directions[slot].is_empty():errors.append("Absent source direction manufactured "+nid)
  var view=VIEW.new()
  if not view.configure(record,path):errors.append("Single-slot original view rejected "+nid);view.free();continue
  for facing: int in range(8):
   view.advance(0.0,"idle",facing,0,false,false)
   if view.last_source_frame<0:errors.append("Fixed original slot hidden "+nid)
  for layer: Sprite2D in view._layers:
   if layer.visible and layer.texture!=null:layers+=1
  view.free()
  # Without an explicit fixed-slot display contract, absent directions fail.
  record.erase("source_m_fixed_source_slot");var free_view=VIEW.new()
  if not free_view.configure(record,path):errors.append("Explicit source view rejected "+nid)
  else:
   if not free_view.advance_source_action(3,0.0,5,1):errors.append("Actual slot0 rejected "+nid)
   if free_view.advance_source_action(3,0.0,0,2):errors.append("Absent slot3 silently substituted "+nid)
  free_view.free();count+=1
 print("BASE508_SINGLE_DIRECTION ",JSON.stringify({"actors":count,"visible_layers":layers,"errors":errors,"manufactured_directions":0}))
 quit(0 if errors.is_empty() and count>0 and layers>0 else 1)
