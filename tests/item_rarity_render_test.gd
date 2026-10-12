extends SceneTree

const EFFECT = preload("res://scripts/ui/item_visual.gd")
var failures: Array[String] = []
var view: TextureRect
var material: ShaderMaterial

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("RARITY_RENDER_FAIL: "+message)

func frame_at(rank: float, clock: float) -> Image:
	material.set_shader_parameter("rank",rank)
	material.set_shader_parameter("preview_time",clock)
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func centroid(image: Image) -> Vector2:
	var center := Vector2.ZERO
	var mass: float = 0.0
	for y: int in range(20,148):
		for x: int in range(20,148):
			var value: float = maxf(0.0,image.get_pixel(x,y).r-0.40)
			center += Vector2(x,y)*value
			mass += value
	return center/maxf(mass,0.0001)

func width(image: Image) -> int:
	var left: int = 1000
	var right: int = -1
	for x: int in range(20,148):
		if image.get_pixel(x,84).r > 0.2:
			left = mini(left,x)
			right = maxi(right,x)
	return right-left+1

func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var pixels := Image.create(64,64,false,Image.FORMAT_RGBA8)
	pixels.fill(Color(0.35,0.35,0.35,1.0))
	view = TextureRect.new()
	view.texture = ImageTexture.create_from_image(pixels)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.position = Vector2(20,20)
	view.size = Vector2(128,128)
	root.add_child(view)
	material = EFFECT.shared_material(3,0).duplicate() as ShaderMaterial
	view.material = material
	var early: Image = await frame_at(3.0,0.30)
	var late: Image = await frame_at(3.0,0.95)
	var a: Vector2 = centroid(early)
	var b: Vector2 = centroid(late)
	check(b.x>a.x+40 and b.y>a.y+40,"hero sheen travels upper-left to lower-right in actual pixels")
	var idle: Image = await frame_at(3.0,2.0)
	check(absf(idle.get_pixel(84,84).r-0.35)<0.015,"idle keeps source brightness; no double texture multiplication")
	var legend: Image = await frame_at(4.0,0.30)
	check(legend.get_pixel(42,42).r > early.get_pixel(42,42).r,"legend highlight stronger without white wash")
	var front: Image = await frame_at(5.0,0.0)
	var side: Image = await frame_at(5.0,2.0)
	check(width(side)>35 and width(side)<width(front)*0.6,"mythic depth turn remains readable edge-on")
	var unique: Image = await frame_at(6.0,2.0)
	check(unique.get_data()!=side.get_data(),"unique adds a distinct glow to the same turn")
	check(view.rotation==0.0 and view.scale==Vector2.ONE,"effect never rotates controls or overlays")
	view.queue_free()
	await process_frame
	print("ITEM_RARITY_RENDER_RESULT ",JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"hero_centroids":[[a.x,a.y],[b.x,b.y]],"mythic_widths":[width(front),width(side)],"failures":failures}))
	if failures.is_empty(): print("ITEM_RARITY_RENDER_OK")
	quit(0 if failures.is_empty() else 1)
