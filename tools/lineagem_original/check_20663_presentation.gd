extends SceneTree
const VIEW=preload("res://scripts/animation/original_source_preview.gd")
const CLOCK=preload("res://scripts/animation/source_presentation_policy.gd")
const POLICY=preload("res://scripts/animation/source_playback_policy.gd")
func _initialize():
 var path: String = ""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--native-manifest="):path=arg.trim_prefix("--native-manifest=")
 if path.is_empty():push_error("Supply an authorized --native-manifest path");quit(2);return
 var actor=VIEW.new();root.add_child(actor);actor.playback_mode_override="compatible"
 assert(actor.configure("sprite:20663",path))
 var track: Dictionary=actor._playback_tracks.idle
 assert(track.fps==null and track.timing_origin=="compat_PC_3_81_default_24_not_verified_for_M")
 assert(track.directions[5][0].source_ticks==4 and is_equal_approx(track.directions[5][0].duration,4.0/24.0))
 assert(is_equal_approx(CLOCK.duration(track.directions[5][0]),1.0/60.0))
 for direction in range(8):
  if direction!=5:assert(not track.directions[direction][0].has("presentation_duration"))
 var total=0.0
 for frame in track.directions[5]:total+=CLOCK.duration(frame)
 assert(is_equal_approx(total,101.0/60.0))
 for index in range(304):actor.advance_source(0.0 if index==0 else 1.0/30.0,"idle",2,0,false)
 assert(is_equal_approx(actor._clock,10.1) and actor.last_source_frame==10)
 actor.advance_source(1.0/30.0,"walk",2,0,false)
 assert(actor._role=="walk" and not actor._playback_tracks.walk.has("presentation_observation"))
 actor.advance_source(0,"idle",2,0,false)
 assert(is_zero_approx(actor._clock) and actor.last_source_frame==10)
 actor.playback_mode_override="strict";assert(actor.configure("sprite:20663",path))
 assert(actor._playback_tracks.idle.static_pending_timing and actor._playback_tracks.idle.fps==null)
 assert(not actor._playback_tracks.idle.has("presentation_observation"))
 var record=JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/lineagem_pack_install.gd").resolve_file(path.get_base_dir(),"actors/20663.json")))
 record.tracks.idle.fps=24
 assert(not POLICY.tracks(record,"doll","compatible").idle.has("presentation_observation"))
 actor.clear()
 print("20663_PRESENTATION_SUPPORT_V0_PASS d5 only; raw FPSnull/ticks retained; compat24 remains unverified;30FPS loop/transition/strict guards")
 quit()
