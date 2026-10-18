extends SceneTree
## Real private PNGs + existing Main. Public runs explicitly skip missing art.
const QA = preload("res://tests/qa_class_selection.gd")
const REGISTRY = preload("res://scripts/maps/remake_registry.gd")
var world: TwilightWorld
var field: RemakePlayableField
var checks: int = 0
var failures: Array[String] = []
var output := "user://png-refinement"
var selected: PackedStringArray = []
var observations: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("PNG_REFINE_FAIL: ",label)
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame
func place(p: Vector2) -> void:
	world.player.clear_click_path();world.player.set_touch_vector(Vector2.ZERO)
	world.player.global_position = p;world.player.velocity = Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	field.collision_stream.refresh();world.field_renderer.refresh_visible()
func cuts() -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for chunk: Node in world.field_renderer.chunks.values():
		for child: Node in chunk.get_children():
			if child is Sprite2D and child.has_meta("png_cut_id"): found.append(child)
	return found
func distance(a: Color,b: Color) -> float: return maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
func frame() -> Image:
	await ticks(2);await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func inspect_cut(id: String, entry: Dictionary) -> void:
	var foot := Vector2(entry.foot_world[0],entry.foot_world[1])
	world.player.set_physics_process(false)
	var old_offset: Vector2 = world.player.camera.position
	var component := {"map_id":id,"cut":entry.id,"states":[]}
	for state: String in ["behind","front"]:
		var point := Vector2.INF
		var best: float = INF
		var center: Vector2i = field.world_to_cell(foot)
		for y: int in range(center.y-12,center.y+13):
			for x: int in range(center.x-12,center.x+13):
				var p: Vector2 = field.cell_to_world(Vector2i(x,y))
				var dy: float = (p.y-foot.y)*(-1 if state == "behind" else 1)
				if dy<18 or dy>120 or absf(p.x-foot.x)>30 or not field.point_clear(p): continue
				# The torch is only 50px tall: a foot 48px behind it leaves
				# an idle character entirely above its flame, with no overlap.
				var desired_gap: float = 24.0 if str(entry.id).begins_with("blue_torch") else 36.0
				var score: float = absf(p.x-foot.x)*3+absf(dy-desired_gap)
				if score<best:best=score;point=p
		check(point.is_finite(),id+" "+entry.id+" source-walkable "+state)
		if not point.is_finite(): continue
		world.player.set_physics_process(true)
		place(point);await ticks(18)
		# Let the real controller enter idle before freezing the pixel probe.
		# Walking dust has its own effect Z layer and is not body occlusion.
		world.player.set_physics_process(false)
		world.player.camera.global_position = foot+Vector2(0,-60)
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		world.player.class_sprite.pause()
		var sprite: Sprite2D
		var copies: int = 0
		for node: Sprite2D in cuts():
			if str(node.get_meta("png_cut_id")) == str(entry.id): sprite=node;copies+=1
		check(copies == 1,id+" "+entry.id+" one foreground instance")
		if sprite == null:continue
		sprite.show();world.player.show();var both: Image = await frame()
		world.player.hide();var object_only: Image = await frame()
		sprite.hide();var neither: Image = await frame()
		world.player.show();var actor_only: Image = await frame();sprite.show()
		var overlap: int = 0;var correct: int = 0;var wrong: int = 0
		var at: Vector2 = world.get_canvas_transform()*foot
		for py: int in range(maxi(0,int(at.y)-380),mini(root.size.y,int(at.y)+90)):
			for px: int in range(maxi(0,int(at.x)-110),mini(root.size.x,int(at.x)+110)):
				var a: Color = neither.get_pixel(px,py);var t: Color = object_only.get_pixel(px,py);var p: Color = actor_only.get_pixel(px,py);var c: Color = both.get_pixel(px,py)
				if distance(a,t)<.15 or distance(a,p)<.15 or distance(p,t)<.1:continue
				overlap+=1
				if distance(c,t if state == "behind" else p)<.025:correct+=1
				if distance(c,p if state == "behind" else t)<.025:wrong+=1
		check(overlap>4 and correct>4 and correct>wrong,id+" "+entry.id+" actual foreground pixels "+state)
		component.states.append({"state":state,"overlap":overlap,"correct":correct,"wrong":wrong,"source_foot":[point.x,point.y]})
		both.save_png(output+"/"+id+"-"+entry.id+"-"+state+".png")
	world.player.camera.position = old_offset
	world.player.set_physics_process(true)
	observations.append(component)

func inspect_footprints(id: String) -> void:
	if field.png_review_footprints == null:return
	var mob: TwilightMonster
	for actor: Node in world.monsters_root.get_children():
		if actor is TwilightMonster and not actor.dead:mob=actor;break
	check(mob != null,id+" real monster for manual footprint physics")
	for polygon: PackedVector2Array in field.png_review_footprints.polygons:
		var center := Vector2.ZERO
		for p: Vector2 in polygon:center+=p
		center/=polygon.size()
		check(not field.point_clear(center),id+" manually traced footprint blocks actual field")
		var rectangle := Rect2(polygon[0],Vector2.ZERO)
		for p: Vector2 in polygon:rectangle=rectangle.expand(p)
		for direction: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
			var start := Vector2.INF
			for radius: float in [32.,40.,48.,72.,96.,120.,160.,200.]:
				var p: Vector2 = center-direction*radius
				if field.point_clear(p):start=p;break
			check(start.is_finite(),id+" clear manual footprint approach "+str(direction))
			if not start.is_finite():continue
			place(start)
			if mob != null:mob.global_position=start;mob.velocity=Vector2.ZERO
			await ticks(3)
			check(world.player.test_move(world.player.global_transform,center-start),id+" real player cast to manual footprint "+str(direction))
			if mob != null:check(mob.test_move(mob.global_transform,center-start),id+" real monster cast to manual footprint "+str(direction))
			world.player.set_touch_vector(direction)
			var clear: bool = true
			for i: int in range(60):
				await physics_frame
				if mob != null:mob.velocity=direction*210;mob._move_on_map()
				clear=clear and field.point_clear(world.player.global_position) and (mob == null or field.point_clear(mob.global_position))
			world.player.set_touch_vector(Vector2.ZERO)
			check(clear,id+" player and monster respect manual footprint for 60 real ticks "+str(direction))
			var ray := PhysicsRayQueryParameters2D.create(start,center,4)
			check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),id+" actual collision body for manual footprint")
		var left: Vector2 = center-Vector2(rectangle.size.x*.5+48,0)
		var right: Vector2 = center+Vector2(rectangle.size.x*.5+48,0)
		if field.point_clear(left) and field.point_clear(right):
			var path: PackedVector2Array = field.path(left,right)
			check(not path.is_empty(),id+" original navigation routes around explicit manual footprint")
			var previous: Vector2 = left
			for p: Vector2 in path:
				check(field.line_clear(previous,p),id+" every detour segment clears real foot");previous=p
			place(left);world._set_click_destination(right)
			for i: int in range(360):
				await physics_frame
				if world.player.global_position.distance_to(right)<14:break
			check(world.player.global_position.distance_to(right)<14,id+" actual click movement completes manual footprint detour")

func inspect(id: String) -> void:
	world._set_map(id,false);world.set_process(false);world.portal_cooldown=10000
	check(world.field_map is RemakePlayableField and world.field_renderer.png_review_active,id+" existing Main uses real PNG")
	if not world.field_map is RemakePlayableField or not world.field_renderer.png_review_active:return
	field=world.field_map;world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var raw: RemakePlayableField = REGISTRY.load_field(id)
	check(raw != null and raw.definition.source_sha256 == field.definition.source_sha256,id+" unchanged original grid identity")
	if raw != null:
		var sample: Vector2i = field.world_to_cell(world.player.global_position)
		for dy: int in range(-3,4):
			for dx: int in range(-3,4):
				var c: Vector2i = sample+Vector2i(dx,dy)
				check(raw.value_at(c,false) == field.value_at(c,false),id+" original cell unchanged")
		raw.close()
	check(world.player.scale == Vector2.ONE and world.player.move_speed == 210,id+" original actor scale/speed")
	var layout: Dictionary = world.field_renderer.png_pack.review_layout
	for category: String in ["npc_spawn","portal"]:
		for record: Dictionary in layout[category]:
			if str(record.get("placement_status","")) != "PNG_REVIEW_MANUAL_CONNECTED_CELL":continue
			var p:=Vector2(record.position[0],record.position[1])
			check(field.point_clear(p) and not field.path(world.player.global_position,p).is_empty(),id+" manually reviewed connected placement "+str(record.id))
	await inspect_footprints(id)
	for region: Dictionary in world.field_renderer.png_pack.regions:
		for entry: Dictionary in region.cuts:
			if str(entry.id) in ["giran_tree_939_822","blue_torch_4872_2256","central_crystal_column"]:await inspect_cut(id,entry)

func run() -> void:
	if not "--png-review" in OS.get_cmdline_user_args() or OS.get_environment("TWILIGHT_MAP_PNG_PACK").is_empty():
		print("PNG_REFINE_SKIP: actual private PNG pack and explicit review session required");quit();return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--maps="):selected=arg.trim_prefix("--maps=").split(",")
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world)
	world.save_timer=-100000
	if selected.is_empty():selected=PackedStringArray(["aden_world","oman_10","domination_summit"])
	for id: String in selected:await inspect(id)
	var report: Dictionary = {"checks":checks,"failures":failures,"occlusion":observations,"source_grids_preserved":true,"global_registration":"REVIEW_REQUIRED","android_device":"NOT_RUN"}
	var file:=FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PNG_REFINE_RESULT ",JSON.stringify(report));world.queue_free();await ticks(2);quit(0 if failures.is_empty() else 1)
