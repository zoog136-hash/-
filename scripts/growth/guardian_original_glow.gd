extends Control
## Actual UI128 pixels and CSB FileData track. Optional presentation, no gameplay calls.
const Media=preload("res://scripts/growth/guardian_media.gd")
const Timeline=preload("res://scripts/growth/guardian_timeline.gd")
var elapsed: float=0
var frame_key: String=""
var finished: bool=false
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
 _process(0)
func _process(delta: float) -> void:
 if finished:return
 elapsed+=maxf(0,delta)
 var animation: Dictionary=Media.INDEX.data.animation
 var frame: float=float(animation.clip.start)+elapsed*float(animation.fps)*float(animation.speed)
 frame_key=str(animation.node.resource.path)
 for track: Dictionary in animation.tracks:
  if track.property!="FileData":continue
  for sample: Dictionary in track.frames:
   if frame<float(sample.index):break
   frame_key=str(sample.resource.path)
 queue_redraw()
 if frame>=float(animation.clip.end):finished=true;queue_free()
func _draw() -> void:
 var image: Texture2D=Media.texture(frame_key)
 if image==null:return
 var node: Dictionary=Media.INDEX.data.animation.node
 var color: Array=node.color_argb
 var tint:=Color(float(color[1])/255,float(color[2])/255,float(color[3])/255,float(color[0])/255)
 var extent:=Vector2(node.size[0],node.size[1])*Vector2(node.scale[0],node.scale[1])
 var center: Vector2=size/2+Vector2(node.position[0],-float(node.position[1]))
 draw_texture_rect(image,Rect2(center-extent*Vector2(node.anchor[0],node.anchor[1]),extent),false,tint)
