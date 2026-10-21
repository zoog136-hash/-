extends SceneTree
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_NATIVE_PNG_PACK
## REAL immutable v5 images, real Main, exclusive pixel ownership and depth.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
var records: Array=[]
class DepthProbe extends Node2D:
	func _draw() -> void: draw_rect(Rect2(-12,-90,24,90),Color.MAGENTA)
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_REVIEW_FAIL: "+label)
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame

func inspect_physics(world: TwilightWorld, field: NativePngField, mid: String) -> Dictionary:
	var covered:=PackedByteArray();covered.resize(field.width*field.height)
	var shapes: int=0
	var external: int=0
	for node: CollisionShape2D in world.field_physics.get_children():
		if node.get_meta("external_canvas_wall",false): external+=1;continue
		var shape: RectangleShape2D=node.shape
		var start:=Vector2i(((node.position-shape.size*.5-field.bounds.position)/field.cell_size).round())
		var size:=Vector2i((shape.size/field.cell_size).round())
		check(start.x>=0 and start.y>=0 and start.x+size.x<=field.width and start.y+size.y<=field.height,mid+" merged shape stays in the finite navigation grid")
		if start.x<0 or start.y<0 or start.x+size.x>field.width or start.y+size.y>field.height: continue
		shapes+=1
		for y: int in range(start.y,start.y+size.y):
			for x: int in range(start.x,start.x+size.x): covered[y*field.width+x]+=1
	var errors: int=0
	var row_runs: int=0
	for y: int in range(field.height):
		var previous: bool=false
		for x: int in range(field.width):
			var solid: bool=field.astar.is_point_solid(Vector2i(x,y))
			if covered[y*field.width+x]!=(1 if solid else 0): errors+=1
			if solid and not previous: row_runs+=1
			previous=solid
	check(errors==0,mid+" every actual physics rectangle equals the full pathfinding grid, with no overlaps")
	check(external==4,mid+" all four actual external canvas walls retained")
	check(shapes<row_runs,mid+" real physics nodes reduced without changing grid cells")
	return {"previous_row_shapes":row_runs,"merged_shapes":shapes,"grid_cells_checked":covered.size(),"mismatches":errors}
func run() -> void:
	if OS.get_environment("TWILIGHT_NATIVE_PNG_PACK").is_empty() or not REGISTRY.enabled():
		print("NATIVE_REVIEW_SKIP: actual private PNGs and explicit mode required");quit();return
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual Main character entry")
	world.set_process(false);world.save_timer=-100000
	for mid: String in REGISTRY.base_plan().maps:
		world._set_map(mid,false);world.portal_cooldown=10000
		check(world.field_map is NativePngField,mid+" actual pinned PNG field")
		if not world.field_map is NativePngField: continue
		var field: NativePngField=world.field_map
		var renderer: NativePngRenderer=world.field_renderer
		world.player.camera.position_smoothing_enabled=false
		var physics: Dictionary=inspect_physics(world,field,mid)
		var owned: int=0
		var piece_count: int=0
		for cut: Dictionary in field.data.runtime_foreground:
			var foot:=Vector2(cut.foot_image[0],cut.foot_image[1])
			world.player.global_position=foot+Vector2(200,0);world.player.velocity=Vector2.ZERO
			world.player.clear_click_path();world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
			# The runtime now stages two decoded source chunks per refresh.
			check(await renderer.settle_visible(),"asynchronous real visible PNGs fully ready")
			await ticks(3)
			var matching: Array=[]
			for key: String in renderer.chunks:
				var sprite: Sprite2D=renderer.chunks[key]
				if sprite.get_meta("native_foreground","")==cut.id: matching.append(sprite)
			check(not matching.is_empty(),mid+" real reviewed pixels decoded: "+str(cut.id))
			piece_count+=matching.size()
			var sources: Dictionary={}
			for sprite: Sprite2D in matching:
				var source: String=sprite.get_meta("source_file")
				if not sources.has(source):
					var ground: Sprite2D=renderer.chunks[source]
					sources[source]={"original":Image.load_from_file(field.png_root+"/"+source),"rebuilt":ground.texture.get_image(),"position":Vector2(ground.position),"owners":{}}
				var pixels: Image=sprite.texture.get_image()
				var position: Array=sprite.get_meta("source_position")
				var record: Dictionary=sources[source]
				for y: int in range(pixels.get_height()):
					for x: int in range(pixels.get_width()):
						var pixel: Color=pixels.get_pixel(x,y)
						if pixel.a==0: continue
						var local:=Vector2i(Vector2(position[0]+x,position[1]+y)-record.position)
						if record.owners.has(local): check(false,mid+" duplicate pixel owner")
						record.owners[local]=true
						if record.rebuilt.get_pixelv(local).a!=0: check(false,mid+" source pixel still in background")
						record.rebuilt.set_pixelv(local,pixel);owned+=1
			for source: String in sources:
				check(sources[source].original.get_data()==sources[source].rebuilt.get_data(),mid+" foreground + background equals actual original chunk "+source)
			var target:=Vector2(cut.probe_image[0],cut.probe_image[1])
			var probe:=DepthProbe.new();probe.position=foot-Vector2(0,10);world.add_child(probe)
			await ticks(3);await RenderingServer.frame_post_draw
			var screen: Vector2=world.get_global_transform_with_canvas()*target
			var behind: Color=root.get_texture().get_image().get_pixelv(Vector2i(screen))
			var sampled_world: Vector2=world.get_global_transform_with_canvas().affine_inverse()*(Vector2(Vector2i(screen))+Vector2(.5,.5))
			var expected:=Color.TRANSPARENT
			for sprite: Sprite2D in matching:
				var position: Array=sprite.get_meta("source_position")
				var pixels: Image=sprite.texture.get_image()
				var local:=Vector2i((sampled_world-Vector2(position[0],position[1])).floor())
				if Rect2i(Vector2i.ZERO,pixels.get_size()).has_point(local):
					var pixel: Color=pixels.get_pixelv(local)
					if pixel.a>0: expected=pixel
			check(expected.a>0,mid+" depth probe is on an actual source object pixel")
			check(expected.a>0 and behind.is_equal_approx(expected),mid+" actual source object hides actor behind its foot")
			if not behind.is_equal_approx(expected): printerr("DEPTH_PIXEL ",mid," expected=",expected," actual=",behind," sampled=",sampled_world)
			probe.position=foot+Vector2(0,20)
			await ticks(3);await RenderingServer.frame_post_draw
			var front: Color=root.get_texture().get_image().get_pixelv(Vector2i(screen))
			check(front.r>.95 and front.b>.95 and front.g<.05,mid+" actor in front covers source object")
			probe.free()
		for raw: Array in REGISTRY.read_json(REGISTRY.REVIEW_PATH).maps[mid].blocked_probes_add:
			check(not field.walkable(Vector2(raw[0],raw[1])),mid+" corrected real object foundation blocks navigation")
		world.player.camera.zoom=Vector2.ONE*.12;world.player.camera.force_update_scroll()
		var requested: int=renderer.forecast_pixels(renderer.visible_rows(world.player.camera))
		check(await renderer.settle_visible(),"asynchronous real visible PNGs fully ready")
		check(requested<=renderer.MAX_VISIBLE_PIXELS or (renderer.budget_limited and world.player.camera.zoom.x>.12),mid+" over-budget view is constrained before allocation; small maps may fit entirely")
		check(renderer.decoded_pixels<=renderer.MAX_VISIBLE_PIXELS,mid+" actual textures stay below budget")
		for filename: String in renderer.visible_rows(world.player.camera):
			check(renderer.chunks.has(filename),mid+" no visible background holes at memory limit: "+filename)
		world.player.camera.zoom=Vector2.ONE;world.player.camera.force_update_scroll();renderer.refresh_visible()
		records.append({"map":mid,"exclusive_foreground_pixels":owned,"foreground_pieces":piece_count,"peak_rgba_bytes":renderer.peak_decoded_pixels*4,"physics":physics})
	print("NATIVE_REVIEW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"maps":records,"archive":"immutable v5; actual PNGs"}))
	world.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
