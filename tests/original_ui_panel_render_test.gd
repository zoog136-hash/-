extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const PANEL=preload("res://scripts/ui/original_ui/source_panel.gd")
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	var opened: Dictionary=pack.open(args[0],receipt.manifest_sha256)
	if not opened.ok:print(opened);quit(1);return
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var viewport:=SubViewport.new()
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var checks: int=0
	for row: Dictionary in cases:
		var options: Dictionary=row.options
		var extent:=Vector2(options.widgetOptions.size[0],options.widgetOptions.size[1])
		viewport.size=Vector2i(extent)+Vector2i(8,8)
		var panel=PANEL.new()
		var configured: Dictionary=panel.configure(pack,options,extent)
		if not configured.ok:errors.append(str(configured));panel.free();continue
		panel.position=Vector2(4,extent.y+4)
		viewport.add_child(panel)
		var w: Dictionary=options.widgetOptions
		var parent_display:=Color(float(w.color[1])/255.0,float(w.color[2])/255.0,float(w.color[3])/255.0,float(w.alpha)/255.0)
		panel.set_source_display(parent_display)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels: Image=viewport.get_texture().get_image()
		var rgba: Array[float]=[]
		for channel: int in range(3):rgba.append(float(int(int(options.bgColor[channel+1])*parent_display[channel]*255.0/255.0))/255.0)
		var alpha: float=float(int(int(options.bgColorOpacity)*parent_display.a8/255.0))/255.0
		var expected:=Color(rgba[0]*alpha,rgba[1]*alpha,rgba[2]*alpha,alpha*alpha)
		for point: Vector2i in [Vector2i(5,5),Vector2i(extent/2.0)+Vector2i(4,4),Vector2i(extent)+Vector2i(2,2)]:
			var actual: Color=pixels.get_pixelv(point)
			for channel: int in range(4):
				checks+=1
				if absf(actual[channel]-expected[channel])>2.0/255.0:errors.append(row.member+":source LayerColor RGBA mismatch:"+str(actual)+":"+str(expected))
		checks+=1
		if pixels.get_pixel(1,1).a!=0.0:errors.append(row.member+":outside original extent")
		panel.queue_free()
		await process_frame
	print("ORIGINAL_PANEL_RENDER "+JSON.stringify({"checks":checks,"errors":errors,"scope":"three supplied solid panel fields, original geometry and source GL alpha equation"}))
	quit(0 if errors.is_empty() else 1)
