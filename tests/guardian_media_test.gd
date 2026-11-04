extends SceneTree
const Media=preload("res://scripts/growth/guardian_media.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var path: String=OS.get_environment("GUARDIAN_ORIGINAL_MEDIA_PACK")
 check(not path.is_empty(),"explicit original source pack")
 check(not Media.installed(),"isolated profile starts without original installation")
 check(Media.texture("Fx_Seet_Skilltree_EnchantActive_01.png")==null,"missing pack never fabricates original pixels")
 var wrong:=FileAccess.open("user://wrong-guardian.zip",FileAccess.WRITE);wrong.store_string("invalid source bytes");wrong.close()
 check(not Media.install("user://wrong-guardian.zip").ok and not Media.installed(),"incorrect source bytes rejected before activation")
 check(Media.install(path).ok and Media.installed(),"exact original atlas installed and settings activated")
 for key: String in Media.INDEX.data.frames:
  var texture: Texture2D=Media.texture(key)
  check(texture!=null,"source frame decoded "+key)
  if texture==null:continue
  var source: Image=texture.get_image();source.convert(Image.FORMAT_RGBA8)
  check(preload("res://scripts/lineagem_pack_install.gd").sha(source.get_data())==Media.INDEX.data.frames[key].rgba_sha256,"pixel-exact atlas crop "+key)
 check(Media.frames.size()==40,"one cached image per exact original frame")
 var texture: Texture2D=Media.texture("Fx_Seet_Skilltree_EnchantActive_01.png")
 check(texture==Media.texture("Fx_Seet_Skilltree_EnchantActive_01.png"),"frame cache reused")
 check(not Media.install("user://wrong-guardian.zip").ok and Media.installed(),"invalid replacement preserves installed original pack")
 var glow=preload("res://scripts/growth/guardian_original_glow.gd").new();root.add_child(glow)
 check(glow.frame_key=="Fx_Seet_Skilltree_EnchantActive_01.png","source initial resource at305")
 glow._process(4.0/60)
 check(glow.frame_key=="Fx_Seet_Skilltree_EnchantActive_02.png","source FileData step at309")
 glow._process(75.0/60)
 check(glow.finished,"source clip ends at383 without looping or gameplay action")
 await process_frame
 print("GUARDIAN_MEDIA_TEST: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
