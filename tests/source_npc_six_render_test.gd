extends SceneTree
## Actual viewport readback of native sprite slots. This is a diagnostic, not map placement QA.
const CATALOG = preload("res://scripts/npc/source_npc_catalog.gd")
const ACTOR = preload("res://scripts/npc/source_npc_actor.gd")
var actors: Array[Node2D] = []
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var stage := Node2D.new()
	root.add_child(stage)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,720),Vector2(0,720)])
	background.color = Color("20282c")
	stage.add_child(background)
	var index: int = 0
	for id: String in CATALOG.records():
		var actor = ACTOR.new()
		stage.add_child(actor)
		actor.position = Vector2(210+(index%3)*420,220+(index/3)*310)
		if not actor.configure({"source_catalog_id":id},true): errors.append(id)
		actor.set_process(false)
		actors.append(actor)
		var label := Label.new()
		if ResourceLoader.exists("res://assets/fonts/NotoSansKR.ttf"):
			label.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"))
		label.text = str(CATALOG.record(id).name)+" · "+id.trim_prefix("l1j_tw380_npc_")
		label.position = actor.position+Vector2(-150,40)
		stage.add_child(label)
		index += 1
	var directory: String = OS.get_environment("TWILIGHT_NPC_CAPTURE_DIR")
	if directory.is_empty(): directory = "/tmp/twilight-npc-six-captures"
	DirAccess.make_dir_recursive_absolute(directory)
	for slot: int in range(8):
		for actor: Node2D in actors:
			actor.set_heading(slot)
			actor._process(0.24)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image.is_empty() or image.save_png(directory+"/slot-%d.png" % slot) != OK: errors.append("readback")
	print("SOURCE_NPC_RENDER slots=8 actors=6 failures=",errors.size()," placement=diagnostic_only")
	quit(0 if errors.is_empty() else 1)
