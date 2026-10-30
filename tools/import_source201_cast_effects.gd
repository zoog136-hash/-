extends SceneTree
## Rebuild reviewed atlases from exact installed raw records; no gameplay code.
const CATALOG=preload("res://scripts/skills/source_effect_catalog.gd")
const PLAN="res://data/skills/reviewed201_cast_effects.json"
const ROOT="res://assets/external_spx/similar_skills/"
func digest(bytes:PackedByteArray)->String:
 var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func canonical(value:Variant)->Variant:
 if value is float and value==floor(value):return int(value)
 if value is Array:
  var array:Array=[]
  for item:Variant in value:array.append(canonical(item))
  return array
 if value is Dictionary:
  var dictionary:Dictionary={}
  for key:String in value:dictionary[key]=canonical(value[key])
  return dictionary
 return value
func _initialize():
 var catalog=CATALOG.new()
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
 var bindings:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/similar_effects.json"))
 var visuals:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/current_official_visuals.json"))
 for spec:Dictionary in plan.cases:
  var frames:Array=[];var bounds:=Rect2i();var count:int=0
  var record:Dictionary={}
  for row:Dictionary in catalog.records(str(spec.group_id)):
   if row.record_key==spec.record_key:record=row;break
  if record.is_empty() or record.sha256!=spec.raw_sha256:printerr("PIN_MISMATCH ",spec.name);quit(1);return
  count=int(record.frames)
  for index:int in range(count):
   var decoded:Dictionary=catalog.frame(str(spec.group_id),str(spec.record_key),index)
   if decoded.is_empty():printerr("DECODE_FAILED ",spec.name);quit(1);return
   bounds=decoded.bounds if index==0 else bounds.merge(decoded.bounds)
   frames.append(decoded)
  var columns:int=mini(8,count)
  var atlas:=Image.create_empty(bounds.size.x*columns,bounds.size.y*ceili(float(count)/columns),false,Image.FORMAT_RGBA8)
  var hashes:Array=[];var native_bounds:Array=[]
  for index:int in range(count):
   var frame:=Image.create_empty(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
   var decoded:Dictionary=frames[index]
   frame.blit_rect(decoded.image,Rect2i(Vector2i.ZERO,decoded.image.get_size()),decoded.bounds.position-bounds.position)
   hashes.append(digest(frame.get_data()))
   native_bounds.append([decoded.bounds.position.x,decoded.bounds.position.y,decoded.bounds.size.x,decoded.bounds.size.y])
   atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i((index%columns)*bounds.size.x,(index/columns)*bounds.size.y))
  if atlas.save_png(ROOT+str(spec.atlas))!=OK:quit(1);return
  manifest.effects[spec.group_id]={"atlas":spec.atlas,"width":bounds.size.x,"height":bounds.size.y,"columns":columns,"count":count,"offset":[bounds.position.x,bounds.position.y],"sha256":FileAccess.get_sha256(ROOT+str(spec.atlas)),"raw_sha256":spec.raw_sha256,"model_id":spec.model_id,"fps":spec.fps,"source_records":[{"record_key":spec.record_key,"name":record.name}],"source_record_key":spec.record_key,"source_name":record.name,"source_names":[spec.name],"resource_scope":"reviewed_existing_active_cast","skill_binding_required":true,"frame_rgba_sha256":hashes,"native_frame_bounds":native_bounds,"source_group_id":spec.group_id,"timing_policy":plan.timing_policy}
  var binding:Dictionary=bindings.bindings[spec.skill_id].duplicate(true)
  if binding.has("inherits_visual"):
   var source:String=str(binding.inherits_visual);var visited:Dictionary={}
   while bindings.bindings.has(source) and not visited.has(source):
    visited[source]=true
    var inherited:Dictionary=bindings.bindings[source]
    if not inherited.has("inherits_visual"):
     binding["phases"]=inherited.get("phases",{}).duplicate(true);break
    source=str(inherited.inherits_visual)
   binding["prior_visual_id"]=binding.inherits_visual;binding.erase("inherits_visual")
  for phase:String in spec.phases:binding.phases[phase]=spec.group_id
  binding["source_review"]={"group_id":spec.group_id,"record_key":spec.record_key,"raw_sha256":spec.raw_sha256,"basis":spec.motif_review,"timing_policy":plan.timing_policy}
  bindings.bindings[spec.skill_id]=binding
  for visual:Dictionary in visuals.records:
   if visual.current_name==spec.name:visual["reviewed_cast"]=binding.source_review.duplicate(true)
 manifest.scope["additional_reviewed_cast_groups"]=5
 manifest.scope["reviewed_cast_resource_count"]=manifest.effects.size()
 for entry:Array in [[ROOT+"manifest.json",manifest],["res://data/skills/similar_effects.json",bindings],["res://data/skills/current_official_visuals.json",visuals]]:
  var file=FileAccess.open(entry[0],FileAccess.WRITE);file.store_string(JSON.stringify(canonical(entry[1]),"  ",false,false)+"\n");file.close()
 print("REVIEWED_CAST_ATLASES groups=5 resources=",manifest.effects.size());quit()
