extends SceneTree
## Private batch viewport evidence. No world, actor, save, or automatic map registration.
const PACK=preload("res://scripts/maps/base508_pack.gd")
var root_path:String
var records:Dictionary={}
var sprite:Sprite2D
var label:Label
func _initialize()->void:
 root_path=OS.get_environment("TWILIGHT_BASE508_UNIVERSE")
 call_deferred("run")
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 sprite=Sprite2D.new();root.add_child(sprite)
 label=Label.new();label.position=Vector2(16,12);root.add_child(label)
 var receipt_path=root_path+"/viewport-evidence.json"
 if FileAccess.file_exists(receipt_path):records=JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
 DirAccess.make_dir_recursive_absolute(root_path+"/screenshots")
 while true:
  var state=JSON.parse_string(FileAccess.get_file_as_string(root_path+"/universe-progress.json"))
  if not state is Dictionary:
   await create_timer(2).timeout
   continue
  for key in state.assets:
   if records.has(key):continue
   var row:Dictionary=state.assets[key]
   if not row.get("status","") in ["VERIFIED_VISUAL","REUSED_VERIFIED_VISUAL","VERIFIED_EMPTY"]:continue
   var directory:String=row.pack_root
   var referenced:bool=FileAccess.file_exists(directory+"/map.json")
   var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+("/map.json" if referenced else "/asset.json")))
   if referenced:
    var pack=PACK.new()
    if not pack.load_pack(directory):
     records[key]={"status":"LOAD_FAILED","reason":pack.error};continue
   var image=Image.load_from_file(directory+"/"+manifest.art.get("overview","overview.png"))
   if image==null:
    records[key]={"status":"OVERVIEW_LOAD_FAILED"};continue
   sprite.texture=ImageTexture.create_from_image(image)
   var factor:float=min(1248.0/image.get_width(),640.0/image.get_height())
   sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(640,390)
   label.text=key+" | original TI2 / S32 | terrain: UNKNOWN BLOCKED\n"+("Land contexts: "+str(row.land_ids) if referenced else "UNREFERENCED SOURCE: NO GAME REGISTRATION")
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   var screenshot:String=root_path+"/screenshots/"+key+".png"
   var error:int=root.get_texture().get_image().save_png(screenshot)
   records[key]={"status":"VIEWPORT_CAPTURED" if error==OK else "CAPTURE_FAILED","file":screenshot,"referenced":referenced,"art_status":manifest.art.status,"terrain_collision":"UNKNOWN","save_access":false}
   var file=FileAccess.open(receipt_path,FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
   print("BASE508_VIEWPORT ",key," ",records[key].status)
  var terminal:int=0
  for row in state.assets.values():
   if row.get("status","") in ["VERIFIED_VISUAL","REUSED_VERIFIED_VISUAL","VERIFIED_EMPTY","FAILED","BLOCKED"]:terminal+=1
  if terminal==int(state.get("total_asset_jobs",672)):break
  await create_timer(2).timeout
 quit()
