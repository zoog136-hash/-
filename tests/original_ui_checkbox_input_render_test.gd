extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const CHECKBOX=preload("res://scripts/ui/original_ui/source_checkbox.gd")
var errors: Array[String]=[]
var checks: int=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:call_deferred("run")
func click(viewport: SubViewport, at: Vector2, down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	viewport.push_input(event,true)
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=3:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	if not pack.open(args[0],receipt.manifest_sha256).ok:quit(1);return
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	DirAccess.make_dir_recursive_absolute(args[2])
	var viewport:=SubViewport.new()
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var captures: Array=[]
	for row: Dictionary in cases:
		var checkbox=CHECKBOX.new()
		var options: Dictionary=row.node.options
		var widget: Dictionary=options.widgetOptions
		var configured: Dictionary=checkbox.configure(pack,options)
		check(configured.ok,"source checkbox configure")
		if not configured.ok:checkbox.free();continue
		viewport.size=Vector2i(ceili(widget.size[0])+48,ceili(widget.size[1])+48)
		checkbox.position=Vector2(24,float(widget.size[1])+24)
		viewport.add_child(checkbox)
		checkbox.set_source_display(Color(float(widget.color[1])/255.0,float(widget.color[2])/255.0,float(widget.color[3])/255.0,float(widget.alpha)/255.0))
		for state: String in ["initial","pressed","normal","disabled"]:
			if state!="initial":checkbox.set_source_state(state)
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image=viewport.get_texture().get_image()
			var filename: String=row.member.replace("/","_")+"_"+str(row.node._offset)+"_"+state+".png"
			check(pixels.save_png(args[2].path_join(filename))==OK,"source state capture")
			captures.append({"member":row.member,"offset":row.node._offset,"state":state,"file":filename,"has_pixels":pixels.get_used_rect().has_area()})
		if bool(widget.touchEnabled) and float(widget.size[0])>0 and float(widget.size[1])>0:
			checkbox.set_source_state("normal")
			checkbox.set_selected(bool(options.selectedState))
			var before: bool=checkbox.selected
			var calls: Array=[]
			var responses: Array=[]
			checkbox.bind_activation(func(value: bool) -> Dictionary:calls.append(value);return {"ok":false,"code":"presentation_unavailable"},Vector2(widget.size[0],widget.size[1]),true)
			checkbox.activation_result.connect(func(result: Dictionary):responses.append(result))
			await process_frame
			var at: Vector2=checkbox._input_area.get_global_rect().get_center()
			click(viewport,at,true)
			check(checkbox.selected==before and calls.is_empty(),"press does not select or dispatch")
			click(viewport,at,false)
			check(checkbox.selected!=before and calls==[not before],"release selects and dispatches exact boolean")
			check(responses.size()==1 and responses[0].code=="presentation_unavailable","existing service failure preserved")
			click(viewport,at,false)
			check(calls.size()==1,"duplicate release does not dispatch")
			click(viewport,at,true);checkbox.visible=false;click(viewport,at,false);checkbox.visible=true
			check(calls.size()==1 and not checkbox._armed,"hidden press cancelled")
			checkbox.set_source_state("disabled")
			click(viewport,at,true);click(viewport,at,false)
			check(calls.size()==1,"disabled checkbox does not dispatch")
		checkbox.queue_free()
		await process_frame
	var result: Dictionary={"checks":checks,"errors":errors,"captures":captures,"source_components":cases.size(),"manifest_sha256":receipt.manifest_sha256,"scope":"original isolated checkbox states and viewport mouse input with service probe; no gameplay save/service completion"}
	FileAccess.open(args[2].path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ORIGINAL_CHECKBOX_INPUT_RENDER "+JSON.stringify({"checks":checks,"errors":errors,"components":cases.size(),"captures":captures.size()}))
	quit(0 if errors.is_empty() else 1)
