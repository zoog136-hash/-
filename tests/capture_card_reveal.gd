extends SceneTree

const STAGE = preload("res://scripts/ui/card_reveal_stage.gd")
var mode: String = "grades"
var target: String = "user://card-reveal-capture"
var one_frame: float = -1.0
var viewport_size := Vector2i(1280,720)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--output="):
			target = arg.trim_prefix("--output=")
		if arg.begins_with("--one-frame="):
			one_frame = float(arg.trim_prefix("--one-frame="))
		if arg.begins_with("--viewport="):
			var dimensions: PackedStringArray = arg.trim_prefix("--viewport=").split("x")
			viewport_size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	call_deferred("_run")

func _run() -> void:
	root.size = viewport_size
	var stage: Control = STAGE.new()
	root.add_child(stage)
	stage.silent = true
	if mode == "grades":
		stage.present_showcase()
	else:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
		var selected: Array[Dictionary] = []
		var wanted: Array[String] = ["희귀","영웅","전설","신화","유일"]
		for i: int in range(1 if mode == "fusion" else 11):
			var grade: String = "유일" if mode == "fusion" else wanted[i%5]
			for row: Dictionary in data["변신"]:
				if row.get("grade","") == grade:
					selected.append(row.duplicate(true))
					break
		var candidates: Array[Texture2D] = []
		for i: int in range(8):
			candidates.append(preload("res://scripts/ui/card_reveal_card.gd").authored_art(i))
		stage.present(selected,candidates,"변신",mode == "fusion",mode == "fusion")
	stage.playing = true
	stage.set_process(false)
	var absolute: String = ProjectSettings.globalize_path(target)
	DirAccess.make_dir_recursive_absolute(absolute)
	var fps: int = 30
	var frames: int = 1 if one_frame >= 0.0 else int(stage.duration*fps)
	for index: int in range(frames):
		stage.seek(one_frame if one_frame >= 0.0 else float(index)/fps)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image.is_empty():
			printerr("CARD_REVEAL_CAPTURE_FAILED: actual renderer returned no image")
			quit(1)
			return
		var error: Error = image.save_png(absolute+"/frame-%04d.png" % index)
		if error != OK:
			quit(1)
			return
	var metadata := {"renderer":RenderingServer.get_video_adapter_name(),"mode":mode,"frames":frames,"fps":fps,"size":[root.size.x,root.size.y],"source":"native Godot 4.7.2 OpenGL frame capture; authored grade progression; capture fixture is not an awarded random pack"}
	var file := FileAccess.open(absolute+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"))
	print("CARD_REVEAL_CAPTURE_OK "+JSON.stringify(metadata))
	quit(0)
