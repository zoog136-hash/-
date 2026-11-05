extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE_SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var errors: Array[String]=[]
var checks: int=0

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: errors.append(message)

func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	if not args.has("pack") or not args.has("capture"):
		push_error("Explicit original sprite-scene pack and private capture directory required");quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.pack).path_join("receipt.json")))
	var opened: Dictionary=pack.open(args.pack,receipt.manifest_sha256)
	check(opened.get("ok",false),"source pack did not open")
	if not opened.get("ok",false): print(opened);quit(1);return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(640,480)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(args.capture)
	for member: String in pack.manifest.entries:
		var scene=SOURCE_SCENE.new()
		var result: Dictionary=scene.configure(pack,member)
		check(result.get("ok",false),"source scene rejected: "+str(result))
		if not result.get("ok",false): scene.free();continue
		viewport.add_child(scene)
		scene.position=Vector2(320,240)
		check(scene.source_nodes.size()==int(args.get("nodes",3)),"source hierarchy changed")
		check(not scene.play("not_a_source_clip").ok,"invented animation clip")
		var clip: Dictionary=scene.source_tree.animationList[0]
		check(scene.play(str(clip.name),true).ok,"original clip missing")
		scene.set_process(false)
		for frame: int in [int(clip.startIndex),int(clip.startIndex)+20,int(clip.endIndex)-1,int(clip.endIndex)]:
			scene.seek_frame(frame)
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image=viewport.get_texture().get_image()
			check(image!=null and not image.is_empty(),"no rendered pixels")
			if image!=null:
				check(image.get_used_rect().has_area(),"empty original rendered effect")
				if args.has("clip-size"):
					var extent: int=int(args["clip-size"])
					var bounds:=Rect2i(320-extent/2,240-extent/2,extent,extent)
					check(bounds.encloses(image.get_used_rect()),"pixels escaped original icon bounds")
				var path: String=str(args.capture).path_join(member.get_file().get_basename()+"_"+str(frame)+".png")
				check(image.save_png(path)==OK,"capture failed")
		scene.seek_frame(float(clip.endIndex)-1.0)
		scene._process(1.0/60.0)
		check(is_equal_approx(scene._frame,float(clip.startIndex)),"source loop endpoint changed")
		if args.has("clip-size"):
			# Runtime clipping probe, separate from unchanged-source captures.
			# Move the existing child pixels outside the source Panel; they must
			# disappear. Do not count this perturbed scene as source visual proof.
			var icon: Node2D
			var animated: Node2D
			for source_node: Node2D in scene.source_nodes.values():
				if source_node.name=="Icon": icon=source_node
				if source_node.name=="Seet_Ani": animated=source_node
			check(icon!=null and animated!=null,"original icon nodes missing")
			if icon!=null and animated!=null:
				icon.visible=false
				scene.seek_frame(float(clip.startIndex)+20)
				await process_frame
				await RenderingServer.frame_post_draw
				check(viewport.get_texture().get_image().get_used_rect().has_area(),"clipping probe has no source pixels")
				animated.position.x+=128.0
				await process_frame
				await RenderingServer.frame_post_draw
				check(not viewport.get_texture().get_image().get_used_rect().has_area(),"Panel failed to clip its animated child")
				var clip_control: Control=animated.get_parent().get_parent()
				clip_control.clip_contents=false
				await process_frame
				await RenderingServer.frame_post_draw
				check(viewport.get_texture().get_image().get_used_rect().has_area(),"clipping probe was outside the viewport")
		scene.queue_free()
		await process_frame
	print("ORIGINAL_UI_SPRITE_RENDER_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"entries":pack.manifest.entries,"scope":"original leaf effect scenes; no full UI or gameplay claim"}))
	quit(0 if errors.is_empty() else 1)
