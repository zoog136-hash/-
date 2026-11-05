extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var errors: Array[String]=[]
var checks: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: errors.append(message)
func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var parts=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	if not args.has("pack") or not args.has("output"): quit(2);return
	var pack=PACK.new()
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(str(args.pack).path_join("receipt.json")))
	var opened=pack.open(args.pack,receipt.manifest_sha256)
	check(opened.ok,"pack failed")
	if not opened.ok: quit(1);return
	check(pack.manifest.entries.size()==19,"must cover remaining 19")
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1600,1000)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(args.output)
	var rows: Array=[]
	for member: String in pack.manifest.entries:
		var scene=SCENE.new()
		var result: Dictionary=scene.configure(pack,member,true)
		check(result.ok,member+": "+str(result))
		if not result.ok: scene.free();continue
		viewport.add_child(scene)
		scene.position=Vector2(800,700)
		scene.set_process(false)
		var frames: Array=[0]
		for clip: Dictionary in scene.source_tree.animationList:
			check(scene.play(str(clip.name)).ok,"source clip rejected")
			frames.append(int(clip.startIndex))
			frames.append(int(clip.endIndex))
		var captures: Array=[]
		for frame: int in frames:
			scene.seek_frame(frame)
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels=viewport.get_texture().get_image()
			check(not pixels.get_used_rect().has_area(),"unexpected pixels in empty/hidden source container: "+member)
			var path: String=str(args.output).path_join(member.replace("/","_")+"_"+str(frame)+".png")
			check(pixels.save_png(path)==OK,"capture failed")
			captures.append({"frame":frame,"has_pixels":pixels.get_used_rect().has_area(),"path":path})
		if member.ends_with("ChracterAppear.csb"):
			var target: Node2D
			for node: Node2D in scene.source_nodes.values():
				if node.name=="Nd_Char_Spine":target=node
			check(target!=null,"source spine attachment missing")
			scene.seek_frame(18)
			check(is_equal_approx(target.position.x,150.0),"source position interpolation")
			scene.seek_frame(28)
			check(is_equal_approx(target.modulate.a,85.0/255.0),"source alpha interpolation")
			scene.play("Char_Ani_Start")
			scene._process(13.0/60.0)
			check(is_equal_approx(target.position.x,150.0),"source clock execution")
		if member.ends_with("Fx_Compose_Spine.csb"):
			for source_node: Node2D in scene.source_nodes.values():
				if source_node.name=="Nd_Spine":
					scene.play("Spine_Loop")
					scene._process(1.0/60.0)
					check(is_equal_approx(scene._frame,71.0),"composition source clock")
					check(source_node.position.is_equal_approx(Vector2(0,337.5)),"composition source position")
					check(source_node.transform.x.is_equal_approx(Vector2.RIGHT) and source_node.transform.y.is_equal_approx(Vector2.DOWN),"composition source scale/rotation")
		var strict=SCENE.new()
		var strict_result: Dictionary=strict.configure(pack,member)
		if not scene.unresolved_bindings.is_empty():check(not strict_result.ok,"unconnected container activated")
		strict.free()
		rows.append({"member":member,"nodes":scene.source_nodes.size(),"inspection":result,"captures":captures,"service_connected":false,"dynamic_content":"not_supplied_by_this_CSB"})
		scene.queue_free()
		await process_frame
	var report={"checks":checks,"errors":errors,"entries":rows,"scope":"19 original source containers inspected; blank captures are not full screen integration"}
	var out=FileAccess.open(str(args.output).path_join("result.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print("ORIGINAL_UI_REMAINING19 ",JSON.stringify({"checks":checks,"errors":errors,"entries":rows.size()}))
	quit(0 if errors.is_empty() else 1)
