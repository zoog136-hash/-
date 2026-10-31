extends SceneTree
# Control restores the previous role-clock selection, without copying old engine code.
class LegacyClockMotion extends "res://scripts/animation/actor_motion.gd":
 func _track(frames:SpriteFrames,key:String)->Dictionary:
  var track=super._track(frames,key).duplicate()
  track.erase("clock_role")
  return track
const OLD=LegacyClockMotion
const CANDIDATE=preload("res://scripts/animation/actor_motion.gd")
const PROFILE=preload("res://scripts/animation/animation_profile.gd")
var custom_shared_key=false
var errors:Array=[]
var results:Dictionary={}

func check(ok:bool,message:String)->void:
 if not ok:errors.append(message);push_error(message)

func texture(phase:int,offset:int=0)->ImageTexture:
 var image=Image.create(2,2,false,Image.FORMAT_RGBA8)
 image.fill(Color(float((phase+offset)%7)/7.,.4,.7,1.))
 return ImageTexture.create_from_image(image)

func source(mode:String)->SpriteFrames:
 var frames=SpriteFrames.new();frames.remove_animation("default")
 for role:String in ["idle","attack","death"]:
  var key=role+"_2";frames.add_animation(key);frames.set_animation_speed(key,9.)
  frames.set_animation_loop(key,role=="idle")
  for phase in range(19 if role=="death" else 6):frames.add_frame(key,texture(phase),1.)
 for pair in [["recovery","attack"],["corpse","death"]]:
  var key=pair[0]+"_2";var base=pair[1]+"_2"
  frames.add_animation(key);frames.set_animation_speed(key,10. if mode=="rate" else 9.)
  frames.set_animation_loop(key,mode=="loop")
  for phase in range(frames.get_frame_count(base)):
   frames.add_frame(key,texture(phase,2) if mode=="distinct" else frames.get_frame_texture(base,phase),1.1 if mode=="duration" and phase==0 else 1.)
 if mode!="none":frames.set_meta("twilight_explicit_role_timeline_aliases",{"recovery":"walk","corpse":"special"} if mode=="unknown" else {"recovery":"attack","corpse":"death"})
 return frames

func controller(script:Script,frames:SpriteFrames)->RefCounted:
 var m=script.new();m.profile=PROFILE.new();m.profile.layout="directional8";m.profile.frames_path="unit://explicit-role-alias"
 m.profile.attack_hit_frame=3;m.profile.action_hit_frames={"attack":3};m.profile.death_duration=.8;m.profile.authored_motion_weight=0.
 if frames.has_meta("twilight_explicit_role_timeline_aliases"):m.profile.set_meta("twilight_explicit_role_timeline_aliases",frames.get_meta("twilight_explicit_role_timeline_aliases"))
 if custom_shared_key:m.profile.animation_names={"attack":"attack_2","recovery":"attack_2"}
 m.frame_source=frames;m.face(Vector2.DOWN)
 return m

func trace(script:Script,frames:SpriteFrames,death:bool)->Dictionary:
 var m=controller(script,frames);var sprite=AnimatedSprite2D.new();sprite.sprite_frames=frames
 var poses=[];var events=[]
 var callback:Callable=func(sequence:int)->void:events.append([sequence,m.attack_elapsed])
 m.strike.connect(callback)
 if death:m.die()
 else:m.begin_attack(.9,Vector2.DOWN,"slash",.44)
 for tick in range(240 if death else 125):
  m.advance(1./120.,Vector2.ZERO);m.apply(sprite,Vector2.ONE)
  poses.append([str(sprite.animation),sprite.frame,str(m.state)])
 var cached={}
 for key in m._tracks:cached[key]=m._tracks[key].get("clock_role","")
 m.strike.disconnect(callback);sprite.free()
 return {"poses":poses,"events":events,"cached_roles":cached}

func _init()->void:
 call_deferred("run")

func run()->void:
 var selected=OLD if OS.get_environment("ALIAS_CLOCK_IMPLEMENTATION")=="old" else CANDIDATE
 var valid=source("valid")
 var death=trace(selected,valid,true);var attack=trace(selected,valid,false)
 var terminal=[]
 for item in death.poses:
  if item[2]=="corpse":terminal.append(item[1])
 check(not terminal.is_empty() and terminal.min()==18 and terminal.max()==18,"Explicit identical corpse/death alias holds original final pose")
 var previous=-1;var monotonic=true
 for item in attack.poses:
  if item[0] in ["attack_2","recovery_2"]:
   if item[1]<previous:monotonic=false
   previous=item[1]
 check(monotonic,"Explicit identical recovery/attack alias continues its primary clock")
 check(attack.cached_roles.get("recovery_2","")=="attack" and death.cached_roles.get("corpse_2","")=="death","Canonical clocks validated once into existing track cache")
 var baseline_attack=trace(OLD,valid,false)
 check(attack.events==baseline_attack.events and attack.events.size()==1,"Authoritative strike time and count unchanged")
 for mode in ["none","distinct","duration","rate","loop","unknown"]:
  var resource=source(mode)
  for dying in [false,true]:
   var original=trace(OLD,resource,dying);var actual=trace(selected,resource,dying)
   check(original==actual,"Unmarked, distinct, differently timed or unsupported timelines unchanged: "+mode)
  results[mode]="old/current exact traces checked"
 custom_shared_key=true
 var shared=source("none")
 var old_shared=trace(OLD,shared,false);var new_shared=trace(selected,shared,false)
 check(old_shared==new_shared,"Unflagged custom animation_names shared attack/recovery key retains current-state clock")
 for key in new_shared.cached_roles:check(new_shared.cached_roles[key]=="","Unflagged cache stores no state-dependent clock role")
 results["unflagged_custom_shared_key"]="old/current exact traces checked"
 results["errors"]=errors;results["implementation"]="old" if selected==OLD else "candidate";results["explicit_alias_terminal_minmax"]=[terminal.min(),terminal.max()]
 var file=FileAccess.open("user://alias-clock-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t")+"\n");file.close()
 await process_frame
 print("EXPLICIT_ALIAS_CLOCK_RESULT ",0 if errors.is_empty() else 1," errors=",errors.size()," implementation=",results.implementation)
 quit(0 if errors.is_empty() else 1)
