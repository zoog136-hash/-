extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var result: Dictionary=pack.open(args[0],receipt.manifest_sha256)
	if not result.ok:print(result);quit(1);return
	var loaded: Dictionary=pack.particle({"path":"Effect/Main_Effect_Loop.plist"})
	if not loaded.ok:print(loaded);quit(1);return
	var texture: Texture2D=loaded.texture
	var errors: Array[String]=[]
	if texture.get_meta("original_embedded_png_sha256")!=expected.png_sha256:errors.append("embedded original PNG hash")
	if PACK._sha256(texture.get_image().get_data())!=expected.rgba_pma_sha256:errors.append("all decoded original PMA bytes")
	if texture.get_width()!=int(expected.width) or texture.get_height()!=int(expected.height):errors.append("original dimensions")
	print("ORIGINAL_PARTICLE_EMBEDDED "+JSON.stringify({"errors":errors,"png_sha256":expected.png_sha256,"pixels":texture.get_width()*texture.get_height()}))
	quit(0 if errors.is_empty() else 1)
