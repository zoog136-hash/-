extends SceneTree
const VIEW=preload("res://scripts/animation/original_source_preview.gd")
const CLOCK=preload("res://scripts/animation/source_presentation_policy.gd")
const POLICY=preload("res://scripts/animation/source_playback_policy.gd")
func _initialize():
 var path: String = ""
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--native-manifest="):path=argument.trim_prefix("--native-manifest=")
 if path.is_empty():
  push_error("Supply --native-manifest=/authorized/private/pack/manifest.json")
  quit(2);return
 var actor=VIEW.new();root.add_child(actor);actor.playback_mode_override="compatible"
 assert(actor.configure("sprite:24709",path))
 var frames: Array=actor._playback_tracks.idle.directions[0]
 assert(frames[0].source_ticks==4 and is_equal_approx(frames[0].duration,4.0/24.0))
 assert(is_equal_approx(CLOCK.duration(frames[0]),1.0/60.0))
 var native_total=0.0;var presentation_total=0.0
 for f in frames:native_total+=f.duration;presentation_total+=CLOCK.duration(f)
 assert(is_equal_approx(native_total,2.0) and is_equal_approx(presentation_total,1.85))
 var samples=[]
 for i in range(556):
  actor.cancel_source_attack()
  actor.advance_source(0.0 if i==0 else 1.0/30.0,"idle",5,0,false)
  var phase=fmod(float(i)/30.0,1.85)
  var expected=11 if phase < 1.0/60.0-0.0000001 else mini(10,int(maxf(0.0,phase-1.0/60.0+0.0000001)/(4.0/24.0)))
  # Float boundaries may choose either adjacent native pose, never create a hold.
  var away=true;var b=1.0/60.0
  for j in range(12):
   if absf(phase-b)<0.0000001:away=false
   b+=4.0/24.0
  if away and phase>0.0000001:assert(actor.last_source_frame==expected)
  samples.append(actor.last_source_frame)
 assert(is_equal_approx(actor._clock,18.5))
 actor.advance_source(1.0/30.0,"walk",5,0,false)
 assert(actor._role=="walk" and not actor._playback_tracks.walk.has("presentation_observation"))
 actor.advance_source(0.0,"idle",5,0,false)
 assert(actor.last_source_frame==11 and is_zero_approx(actor._clock))
 actor.playback_mode_override="strict";assert(actor.configure("sprite:24709",path))
 assert(not actor._playback_tracks.idle.has("presentation_observation"))
 assert(not actor._playback_tracks.idle.directions[0][0].has("presentation_duration"))
 actor.playback_mode_override="compatible";assert(actor.configure("sprite:26725",path))
 assert(not actor._playback_tracks.idle.has("presentation_observation"))
 var native=JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/lineagem_pack_install.gd").resolve_file(path.get_base_dir(), "actors/24709.json")))
 native.tracks.idle.source_raw_body+="changed"
 assert(not POLICY.tracks(native,"relic","compatible").idle.has("presentation_observation"))
 actor.clear()
 print("24709_PRESENTATION_PASS native2s preserved; scoped1.85s; elapsed30FPS no forced holds; transition/strict/other actor/raw guard")
 quit()
