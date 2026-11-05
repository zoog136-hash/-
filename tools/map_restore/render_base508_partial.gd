extends SceneTree
## Partial source review only: no game pack activation or save access.
func _initialize()->void:call_deferred("run")
func run()->void:
 var directory:String=OS.get_environment("TWILIGHT_BASE508_UNIVERSE")+"/partial-source-reviews"
 DirAccess.make_dir_recursive_absolute(directory+"/screenshots")
 var sprite=Sprite2D.new();root.add_child(sprite)
 var label=Label.new();label.position=Vector2(16,12);root.add_child(label)
 var receipt:Dictionary={}
 for asset:String in ["13408","13412","13414","99666"]:
  var key:String="base508_asset_"+asset
  var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"/"+key+"/partial-map.json"))
  assert(manifest.art.status=="PARTIAL_ORIGINAL_REFERENCE_UNRESOLVED")
  var image=Image.load_from_file(directory+"/"+key+"/"+manifest.art.overview)
  assert(image!=null)
  sprite.texture=ImageTexture.create_from_image(image)
  var factor:float=min(1248.0/image.get_width(),620.0/image.get_height());sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(640,400)
  label.text=key+" | PARTIAL SOURCE REVIEW: NOT A COMPLETE MAP\nUnresolved whole visual chunks: "+str(manifest.unresolved_visual_chunks.size())+" | no replacement tiles | movement blocked"
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  var target:String=directory+"/screenshots/"+key+".png"
  assert(root.get_texture().get_image().save_png(target)==OK)
  receipt[key]={"status":"PARTIAL_REVIEW_CAPTURED","file":target,"unresolved_chunks":manifest.unresolved_visual_chunks,"runtime_activation":"NEVER_AUTO_REGISTER","terrain_collision":"UNKNOWN_BLOCKED"}
 var file=FileAccess.open(directory+"/viewport-evidence.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"  "));file.close()
 print("BASE508_PARTIAL_VIEWPORTS_OK ",receipt.size())
 quit()
