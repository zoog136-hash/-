extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const BAR=preload("res://scripts/ui/original_ui/source_loading_bar.gd")
var errors: Array[String]=[]
var checks: int=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func find_bar(node: Dictionary) -> Dictionary:
	if node.classname=="LoadingBar":return node.options
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=find_bar(child)
		if not found.is_empty():return found
	return {}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var pack=PACK.new()
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	check(pack.open(args[0],receipt.manifest_sha256).ok,"open")
	var member: String=pack.manifest.entries[0]
	var strict=SCENE.new()
	check(not strict.configure(pack,member).ok,"unbound live percent must reject strict consumption")
	strict.free()
	var bar=BAR.new()
	check(bar.configure(pack,find_bar(pack.scene(member).nodeTree)).ok,"source bar")
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1024,256)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(bar)
	bar.position=Vector2(100,150)
	var widths: Array[int]=[]
	for percent: float in [-1.0,0.0,50.0,100.0,101.0]:
		bar.set_source_percent(percent)
		await process_frame
		await RenderingServer.frame_post_draw
		widths.append(viewport.get_texture().get_image().get_used_rect().size.x)
	check(widths[0]==0 and widths[1]==0,"zero clamp leaves no original pixels")
	check(widths[2]>0 and widths[2]<widths[3],"source texture crop grows")
	check(widths[3]==widths[4],"upper clamp")
	print("ORIGINAL_LOADING_BAR "+JSON.stringify({"checks":checks,"errors":errors,"pixel_widths":widths,"scope":"original texture percentage rendering; no recovery service claim"}))
	quit(0 if errors.is_empty() else 1)
