extends SceneTree
const CATALOG=preload("res://scripts/skills/source_effect_catalog.gd")
const DECODER=preload("res://scripts/skills/source_spr_decoder.gd")
var failures:int=0
var checked:int=0
func check(ok:bool,label:String):
 checked+=1
 if not ok:failures+=1;printerr("SOURCE_EFFECT_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var catalog=CATALOG.new()
 var groups:Dictionary=catalog.groups()
 var effect_count:int=0
 for spec:Dictionary in groups.values():
  if spec.kind=="effect":effect_count+=1
 check(effect_count==2764,"all permitted additional groups registered")
 for id:String in catalog.manifest.get("excluded_groups",[]):check(not groups.has(id),"excluded identity stays excluded")
 check(DECODER.decode(PackedByteArray(),0).is_empty(),"empty rejected")
 check(DECODER.decode(PackedByteArray([1]),0).is_empty(),"truncated rejected")
 var fixture:String=OS.get_environment("TWILIGHT_SOURCE_EFFECT_FIXTURES")
 if fixture.is_empty():fixture="res://tests/fixtures/source_effect_native_pixels.json"
 if not fixture.is_empty():
  var expected:Array=JSON.parse_string(FileAccess.get_file_as_string(fixture))
  for row:Dictionary in expected:
   var frame:Dictionary=catalog.frame(str(row.group),str(row.record_key),int(row.frame))
   check(not frame.is_empty(),"actual source frame "+str(row.record_key))
   if frame.is_empty():continue
   var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(frame.image.get_data())
   check(context.finish().hex_encode()==str(row.rgba_sha256),"pinned Python decoder pixel equivalence")
   check(frame.bounds==Rect2i(int(row.bounds[0]),int(row.bounds[1]),int(row.bounds[2])-int(row.bounds[0]),int(row.bounds[3])-int(row.bounds[1])),"native grid and extent retained")
   check(int(frame.frame_count)==int(row.frame_count),"source frame count")
   if "--gpu-samples" in OS.get_cmdline_user_args():
    var loaded:Dictionary=catalog.texture(str(row.group),str(row.record_key),int(row.frame))
    check(not loaded.is_empty(),"on-demand GPU texture")
    if not loaded.is_empty():
     var texture_context:=HashingContext.new();texture_context.start(HashingContext.HASH_SHA256);texture_context.update(loaded.texture.get_image().get_data())
     check(texture_context.finish().hex_encode()==str(row.rgba_sha256),"uploaded native texture pixels")
     var sprite:=Sprite2D.new();sprite.texture=loaded.texture;root.add_child(sprite)
     sprite.position=Vector2(180+(checked%3)*360,180+(checked%2)*280)
  if "--gpu-samples" in OS.get_cmdline_user_args():
   root.size=Vector2i(1200,800)
   await process_frame;await RenderingServer.frame_post_draw
   var visible:Image=root.get_texture().get_image()
   check(visible!=null and visible.get_used_rect().size!=Vector2i.ZERO,"actual viewport readback")
 var reused:int=0
 for id:String in groups:
  if groups[id].get("storage","")!="reviewed_atlas":continue
  reused+=1
  for row:Dictionary in catalog.records(id):
   for index:int in [0,int(row.count)-1]:
    var decoded:Dictionary=catalog.frame(id,str(row.record_key),index)
    check(not decoded.is_empty(),"reviewed atlas reuse")
    if decoded.is_empty():continue
    var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(decoded.image.get_data())
    check(digest.finish().hex_encode()==str(row.frame_rgba_sha256[index]),"existing reviewed source pixels unchanged")
 check(reused==45,"45 reviewed groups reused without duplicate payload")
 check(catalog.frame("missing","missing",0).is_empty(),"no guessed variant")
 print("SOURCE_EFFECT_CATALOG checks=",checked," failures=",failures," groups=",groups.size())
 quit(1 if failures else 0)
