extends SceneTree
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
const CODEC=preload("res://scripts/monsters/base508_sp2_frames.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--lineagem-monster-pack="): path=arg.trim_prefix("--lineagem-monster-pack=")
 var allowed: Array[int]=[55,6563,14082,1828,2001,28623,18772,28759,26486,27536,1597,20330,28909]
 if path.is_empty() or not FileAccess.file_exists(path):
  print("BASE508_PRIVATE_PACK_TEST_SKIPPED: explicit private manifest required; no source load claim")
  quit(0);return
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var errors: Array=[];var samples: int=0;var loaded: int=0;var ordinary: int=0;var visual_only: int=0
 var checked: Dictionary={}
 for id: String in manifest.records:
  var actor: Dictionary=manifest.records[id];var sid: int=int(actor.sprite_id)
  if checked.has(sid) or sid not in allowed: continue
  checked[sid]=true
  var pair: Dictionary=actor.source_contexts[0]
  var key: String="lineagem_base508:npc:%d:spawn:%d:territory:%d" % [int(id),int(pair.spawn_view_id),int(pair.territory_link_id)]
  var model: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join(actor.tracks_ref)))
  if int(model.source_capability_contract)!=1: errors.append("Missing capability contract "+id);continue
  var record: Dictionary=ROSTER.visual_record(key,path,true)
  if record.is_empty(): errors.append("Exact visual context rejected "+id);continue
  var view=VIEW.new()
  if not view.configure(record,path): errors.append("Partial view rejected "+id);view.free();continue
  var factory: Dictionary=ROSTER.record(key,path,{"source_m_allow_contextual":true})
  if bool(actor.source_actor_profile.host_combat_ready):
   ordinary+=1
   if factory.is_empty(): errors.append("Supported ordinary actor rejected "+id)
  else:
   visual_only+=1
   if not factory.is_empty(): errors.append("Unsupported ordinary actor enabled "+id)
  for role: String in ["idle","walk","attack","hit","death"]:
   if not model.tracks.has(role):
    view.clear_source_action();view.advance(0.0,role,0,0,role=="attack",role=="death")
    if view.supports_state(role): errors.append("Missing state manufactured "+id+":"+role)
  var primary: Array=[]
  for candidate: String in ["idle","walk","attack","hit","death","source_action_18"]:
   if model.tracks.has(candidate): primary.append(candidate)
  if primary.is_empty(): primary.append(model.tracks.keys()[0])
  for role: String in primary:
   var track: Dictionary=model.tracks[role]
   if not view.advance_source_action(int(track.source_action_id),0.0,0,int(track.source_action_id)+1): errors.append("Explicit source action rejected "+id+":"+role)
   var fs: Array=track.directions[0]
   for index: int in [0,fs.size()-1]:
    for layer: Dictionary in fs[index].layers:
     var decoded: Dictionary=CODEC.render(path.get_base_dir().path_join(layer.path),layer.sha256,int(layer.source_direction_bit),int(layer.source_frame_index))
     if decoded.is_empty(): errors.append("Original packet failed "+id+":"+role);continue
     if decoded.image.get_width()!=int(layer.pixel_size[0]) or decoded.image.get_height()!=int(layer.pixel_size[1]) or int(decoded.offset[0])!=int(layer.offset[0]) or int(decoded.offset[1])!=int(layer.offset[1]): errors.append("Original bounds mismatch "+id+":"+role)
     samples+=1
  if view.advance_source_action(987654,0.0,0,999): errors.append("Undeclared source action accepted "+id)
  view.clear_source_action();view.free();loaded+=1
  print("BASE508_CAPABILITY_MODEL_OK ",sid)
 print("BASE508_CAPABILITIES ",JSON.stringify({"models":loaded,"ordinary_models":ordinary,"visual_only_models":visual_only,"source_layer_samples":samples,"errors":errors}))
 quit(0 if errors.is_empty() and loaded>0 else 1)
