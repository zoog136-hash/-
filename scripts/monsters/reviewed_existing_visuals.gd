extends RefCounted
## Exact reviewed identities only. Existing records, stats and save IDs stay intact.
const PATH="res://data/monsters/reviewed_existing_visuals.json"
static var bindings:Dictionary={}
static func binding(record:Dictionary) -> Dictionary:
 if bool(record.get("catalog_only",false)):return {}
 if bindings.is_empty():
  var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
  if data is Dictionary:bindings=data.get("bindings",{})
 return bindings.get(str(record.get("name","")),{})
static func configure(profile:Resource,kind:String,record:Dictionary) -> void:
 if kind!="monster":return
 var entry:Dictionary=binding(record)
 if entry.is_empty() or not ResourceLoader.exists(str(entry.frames_path)):return
 profile.frames_path=str(entry.frames_path)
 profile.animation_names={}
 profile.native_width_ratio=0.90
 profile.pixel_scale=scale_for(record,entry)
 profile.color_tint=Color.WHITE
 profile.authored_motion_weight=0.0
static func scale_for(record:Dictionary,entry:Dictionary) -> float:
 return float(record.get("visual_height",72.0))/float(entry.reference_body_height)
static func apply_anchor(profile:Resource,record:Dictionary) -> void:
 var entry:Dictionary=binding(record)
 if entry.is_empty() or profile.frames_path!=str(entry.frames_path):return
 var size:Array=entry.canvas_size;var foot:Array=entry.foot_in_canvas
 profile.sprite_offset=(Vector2(size[0],size[1])*0.5-Vector2(foot[0],foot[1]))*Vector2(0.90,1.0)*scale_for(record,entry)
static func portrait(record:Dictionary) -> Texture2D:
 var entry:Dictionary=binding(record)
 if entry.is_empty():return null
 var frames:SpriteFrames=load(str(entry.frames_path))
 if frames==null or not frames.has_animation("idle_2"):return null
 return frames.get_frame_texture("idle_2",0)
