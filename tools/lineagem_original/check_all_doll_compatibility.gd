extends SceneTree
const VIEW=preload("res://scripts/animation/original_source_preview.gd")
const POLICY=preload("res://scripts/animation/source_playback_policy.gd")
func _initialize():call_deferred("run")
func run():
 var path: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--native-manifest="):path=arg.trim_prefix("--native-manifest=")
 if path.is_empty():push_error("Supply an authorized --native-manifest path");quit(2);return
 var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/lineagem_base508/cards.json"))
 var stats={"registered_cards":0,"loaded_cards":0,"unique_appearances":{},"shared_fallback_appearances":{},"shared_tracks":{},"explicit_tracks":{},"source_absent_roles":{},"origins":{},"errors":[]}
 var view=VIEW.new();view.playback_mode_override="compatible";root.add_child(view)
 for card: Dictionary in cards.catalog["마법인형"]:
  stats.registered_cards+=1
  if not view.configure("doll:"+str(card.sourceId),path):stats.errors.append("configure:"+str(card.source_card_id));continue
  stats.loaded_cards+=1
  var sid: String=str(int(view._record.source_sprite_id));stats.unique_appearances[sid]=true
  for role: String in ["idle","walk","attack"]:
   if not view._playback_tracks.has(role):stats.source_absent_roles[role]=int(stats.source_absent_roles.get(role,0))+1
  for role: String in view._playback_tracks:
   var track: Dictionary=view._playback_tracks[role];var original: Dictionary=view._record.tracks[role]
   if bool(track.static_pending_timing) or float(track.effective_fps)<=0.0:stats.errors.append("pending:"+sid+":"+role)
   var key: String=sid+":"+role;stats.origins[key]=track.timing_origin
   if original.get("fps")!=null and float(original.fps)>0.0:
    stats.explicit_tracks[key]=true
    if not is_equal_approx(float(track.effective_fps),float(original.fps)):stats.errors.append("changed_explicit:"+key)
   elif str(track.timing_origin)=="compat_user_approved_doll_shared_24_not_verified_M_default":
    stats.shared_fallback_appearances[sid]=true;stats.shared_tracks[key]=true
    if not is_equal_approx(float(track.effective_fps),24.0):stats.errors.append("shared_rate:"+key)
   for direction: int in range(track.directions.size()):
    for index: int in range(track.directions[direction].size()):
     var f: Dictionary=track.directions[direction][index];var raw: Dictionary=original.directions[direction][index]
     if f.source_ticks!=raw.source_ticks or f.source_frame!=raw.source_frame or f.source_group!=raw.source_group:stats.errors.append("changed_source_token:"+key)
  view.advance_source(0,"idle",2,0,false)
  if view.last_source_frame<0:stats.errors.append("idle_sample:"+sid)
  if int(view._record.source_sprite_id)==20663:
   if not view._playback_tracks.idle.directions[5][0].has("presentation_duration"):stats.errors.append("scoped20663_override_lost")
   if view._playback_tracks.idle.directions[0][0].has("presentation_duration"):stats.errors.append("scoped20663_override_leaked")
  view.clear()
  await process_frame
 stats.unique_appearances=stats.unique_appearances.size();stats.shared_fallback_appearances=stats.shared_fallback_appearances.size();stats.shared_tracks=stats.shared_tracks.size();stats.explicit_tracks=stats.explicit_tracks.size()
 if stats.registered_cards!=167 or stats.loaded_cards!=167:stats.errors.append("167_card_coverage")
 print("ALL_DOLL_COMPATIBILITY ",JSON.stringify(stats))
 view.free();quit(0 if stats.errors.is_empty() else 1)
