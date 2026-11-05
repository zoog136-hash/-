extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var errors: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var parts=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2:args[parts[0]]=parts[1]
	if not args.has("pack") or not args.has("output"):quit(2);return
	var pack=PACK.new()
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(str(args.pack).path_join("receipt.json")))
	var opened=pack.open(args.pack,receipt.manifest_sha256)
	if not opened.ok: print(opened);quit(1);return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1800,1100)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(args.output)
	var rows: Array=[]
	for member: String in pack.manifest.entries:
		var scene=SCENE.new()
		var configured: Dictionary=scene.configure(pack,member,true)
		if not configured.ok:
			errors.append(member+":"+str(configured));scene.free();continue
		viewport.add_child(scene)
		scene.position=Vector2(900,800)
		var source_root: Dictionary=scene.source_tree.nodeTree.options
		var design: Array=source_root.get("size",[0,0])
		if float(design[0])>0 and float(design[1])>0:
			viewport.size=Vector2i(ceili(float(design[0])),ceili(float(design[1])))
			var anchor: Array=source_root.anchorPoint
			scene.position=Vector2(float(anchor[0])*float(design[0]),(1.0-float(anchor[1]))*float(design[1]))
		else:viewport.size=Vector2i(1800,1100)
		scene.set_process(false)
		var frames: Array=[0]
		for clip: Dictionary in scene.source_tree.animationList:
			var played: Dictionary=scene.play(str(clip.name))
			if not played.ok:errors.append(member+": source clip failed")
			for frame: int in [int(clip.startIndex),int((clip.startIndex+clip.endIndex)/2),int(clip.endIndex)]:
				if frame not in frames:frames.append(frame)
		var captures: Array=[]
		for frame: int in frames:
			scene.seek_frame(frame)
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image=viewport.get_texture().get_image()
			var filename: String=member.replace("/","_")+"_"+str(frame)+".png"
			if pixels.save_png(str(args.output).path_join(filename))!=OK:errors.append(member+":capture failed")
			captures.append({"frame":frame,"has_pixels":pixels.get_used_rect().has_area(),"file":filename})
		if args.has("button-states"):
			var buttons: Array=[]
			for source_node: Node2D in scene.source_nodes.values():
				if source_node.has_meta("source_button"):buttons.append(source_node.get_meta("source_button"))
			if not buttons.is_empty():
				for state: String in ["normal","pressed","disabled"]:
					for button: Node2D in buttons:
						if not button.set_source_state(state).ok:errors.append(member+":source state rejected")
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels: Image=viewport.get_texture().get_image()
					var filename: String=member.replace("/","_")+"_buttons_"+state+".png"
					if pixels.save_png(str(args.output).path_join(filename))!=OK:errors.append(member+":state capture failed")
					captures.append({"state":state,"has_pixels":pixels.get_used_rect().has_area(),"file":filename,"inspection_only":true})
		rows.append({"member":member,"nodes":scene.source_nodes.size(),"bindings":scene.unresolved_bindings,"captures":captures,"service_connected":false})
		scene.queue_free()
		await process_frame
	var out=FileAccess.open(str(args.output).path_join("result.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"entries":rows,"errors":errors,"manifest_sha256":receipt.manifest_sha256},"\t"))
	print("ORIGINAL_UI_RENDER_CATALOG ",JSON.stringify({"entries":rows.size(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)
