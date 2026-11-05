extends Node
## Original property/time tracks on the existing local UI; presentation never transacts.
const DATA=preload("res://data/growth/guardian_presentation.json")
var target_ref: WeakRef
var clip: Dictionary={}
var elapsed: float=0
var original_scale: Vector2=Vector2.ONE
var original_modulate: Color=Color.WHITE
static func sample(track: Dictionary,frame: float) -> Variant:
 var frames: Array=track.frames
 var previous: Dictionary=frames[0]
 for current: Dictionary in frames:
  if frame<float(current.index):
   if not previous.tween:return previous.value
   var weight: float=clampf((frame-float(previous.index))/maxf(1,float(current.index)-float(previous.index)),0,1)
   if previous.value is Array:return [lerpf(float(previous.value[0]),float(current.value[0]),weight),lerpf(float(previous.value[1]),float(current.value[1]),weight)]
   return lerpf(float(previous.value),float(current.value),weight)
  previous=current
 return previous.value
static func play(target: Control,name: String) -> void:
 if not DATA.data.clips.has(name):return
 var old: Node=target.get_node_or_null("GuardianTimeline")
 if old!=null:old.finish();target.remove_child(old);old.queue_free()
 var player=new()
 player.name="GuardianTimeline";player.target_ref=weakref(target);player.clip=DATA.data.clips[name]
 player.original_scale=target.scale;player.original_modulate=target.modulate
 target.add_child(player)
 player.advance(0)
func _process(delta: float) -> void:advance(delta)
func advance(delta: float) -> void:
 var target: Control=target_ref.get_ref()
 if not is_instance_valid(target):queue_free();return
 elapsed+=maxf(0,delta)
 var frame: float=float(clip.source_clip.start)+elapsed*float(DATA.data.fps)*float(clip.speed)
 target.pivot_offset=target.size/2
 for track: Dictionary in clip.tracks:
  var value: Variant=sample(track,frame)
  if track.property=="Scale":target.scale=original_scale*Vector2(value[0],value[1])
  elif track.property=="Alpha":target.modulate=Color(original_modulate,original_modulate.a*float(value)/255)
 if frame>=float(clip.source_clip.end):finish();queue_free()
func finish() -> void:
 var target: Control=target_ref.get_ref()
 if is_instance_valid(target):target.scale=original_scale;target.modulate=original_modulate
 set_process(false)
