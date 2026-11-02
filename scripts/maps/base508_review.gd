extends Node2D
## Isolated original map renderer: no writes to live registry/world/save files.
const PACK = preload("res://scripts/maps/base508_pack.gd")
var pack = PACK.new()
var camera: Camera2D
var overview: Sprite2D
var sprites: Dictionary = {}
var label: Label
var inspected: Dictionary = {}
var rendered_chunks: int = 0
var frames: int = 0
var frame_times: Array[float] = []
var capture_path: String = ""
var capture_after: int = 90
var start_us: int
var portal_overlay: Node2D
var destination_outline: Line2D
var resource_load_ms: float = 0

func _ready() -> void:
	var load_started_us: int = Time.get_ticks_usec()
	Engine.max_fps = 30
	RenderingServer.set_default_clear_color(Color("101617"))
	var path: String = OS.get_environment("TWILIGHT_BASE508_PACK")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="): path = arg.trim_prefix("--pack=")
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	if not pack.load_pack(path):
		label.text = pack.error + "\nSet TWILIGHT_BASE508_PACK or --pack=/absolute/private/pack"
		push_error(pack.error)
		return
	var art: Dictionary = pack.manifest.art
	if not art.get("status", "") in ["ORIGINAL_PNG_RENDERABLE", "S32_TI2_RENDERABLE"]:
		label.text = "Source metadata loaded; original artwork unavailable."
		return
	var image := Image.new()
	if FileAccess.get_sha256(pack.safe_file(str(art.overview))) != str(art.overview_sha256):
		label.text = "Original overview SHA mismatch"
		return
	if image.load(pack.safe_file(str(art.overview))) != OK:
		label.text = "Missing original overview"
		return
	overview = Sprite2D.new()
	overview.centered = false
	overview.texture = ImageTexture.create_from_image(image)
	overview.scale = Vector2(float(art.size[0])/image.get_width(), float(art.size[1])/image.get_height())
	add_child(overview)
	camera = Camera2D.new()
	var box: Array = art.visible_bounds
	var center := Vector2(float(box[0])+float(box[2]), float(box[1])+float(box[3]))*.5
	var fit: float = minf(get_viewport_rect().size.x/(float(box[2])-float(box[0])), (get_viewport_rect().size.y-240)/(float(box[3])-float(box[1])))
	camera.position = center-Vector2(0, 110/fit)
	camera.zoom = Vector2.ONE*fit
	add_child(camera)
	if art.status == "S32_TI2_RENDERABLE":
		build_portal_overlay()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--detail":
			camera.zoom = Vector2.ONE
			# PNG pixel point only, deliberately not a source cell coordinate.
			camera.position = center-Vector2(0, 110)
		if arg.begins_with("--portal="):
			focus_portal_destination(int(arg.trim_prefix("--portal=")))
		if arg.begins_with("--npc-region="):
			focus_npc_territory(int(arg.trim_prefix("--npc-region=")))
	start_us = Time.get_ticks_usec()
	resource_load_ms = float(start_us-load_started_us)/1000.0
	update_label()

func update_label() -> void:
	var r: Dictionary = pack.manifest.report
	label.text = "BASE508 MAP RESTORATION REVIEW  |  Land %d → Map/%s\n" % [int(pack.manifest.land.ID), pack.manifest.land.AssetPath]
	var source_label: String = "Original S32 + TI2" if pack.manifest.art.status == "S32_TI2_RENDERABLE" else "Existing original PNG"
	label.text += "%s: rendered  |  S32 chunks: %d/%d  |  restored S32 tiles: %d\n" % [source_label, r.target_chunks_losslessly_loaded, r.target_chunks_expected, r.visual_s32_tiles_restored]
	var portal_mode: String = "source grid anchors" if pack.manifest.art.status == "S32_TI2_RENDERABLE" else "unmapped to PNG"
	label.text += "Source portal links: %d regions (%s)  |  terrain collision: UNKNOWN / movement blocked\n" % [r.portal_regions_preserved, portal_mode]
	label.text += "WASD/arrows: camera pan  |  wheel: zoom  |  30 FPS target  |  no save changes\n"
	if pack.manifest.art.status == "S32_TI2_RENDERABLE":
		label.text += "Keys 1–4: inspect original portal destination regions (camera only)\n"
	for portal: Dictionary in pack.portals:
		var t: Dictionary = portal.TargetTerritory
		label.text += "%d: (%d,%d) → Land %d (%d,%d)..(%d,%d)\n" % [int(portal.ID), int(portal.SourceX), int(portal.SourceY), int(t.LandID), int(t.StartX), int(t.StartY), int(t.EndX), int(t.EndY)]

func _unhandled_input(event: InputEvent) -> void:
	if camera == null: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for portal: Dictionary in pack.portals:
				# Screen-space inspector hitbox, never a gameplay trigger radius.
				if source_grid_point(Vector2(portal.SourceX,portal.SourceY)).distance_to(get_global_mouse_position())*camera.zoom.x<=14:
					focus_portal_destination(int(portal.ID))
					break
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.zoom = Vector2.ONE*minf(camera.zoom.x*1.25, 2.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.zoom = Vector2.ONE*maxf(camera.zoom.x/1.25, .03)
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = int(event.keycode)-KEY_1
		if index >= 0 and index < mini(4, pack.portals.size()):
			focus_portal_destination(int(pack.portals[index].ID))

func source_grid_point(cell: Vector2) -> Vector2:
	return pack.COORDINATE_CONTRACT.grid_anchor(pack.manifest,cell)

func build_portal_overlay() -> void:
	portal_overlay = Node2D.new()
	portal_overlay.z_index = 20
	add_child(portal_overlay)
	for portal: Dictionary in pack.portals:
		var point := source_grid_point(Vector2(portal.SourceX, portal.SourceY))
		var marker := Line2D.new()
		marker.default_color = Color("4dffff")
		marker.width = 4
		marker.points = PackedVector2Array([point+Vector2(-12,0), point+Vector2(0,-6), point+Vector2(12,0), point+Vector2(0,6), point+Vector2(-12,0)])
		portal_overlay.add_child(marker)
	destination_outline = Line2D.new()
	destination_outline.width = 4
	destination_outline.default_color = Color("ffdc65")
	portal_overlay.add_child(destination_outline)

func focus_portal_destination(portal_id: int) -> void:
	if portal_overlay == null: return
	var territory: Dictionary = pack.portal_destination(portal_id)
	if territory.is_empty() or int(territory.LandID) != int(pack.manifest.land.ID): return
	var corners := PackedVector2Array([
		source_grid_point(Vector2(territory.StartX, territory.StartY)),
		source_grid_point(Vector2(territory.EndX, territory.StartY)),
		source_grid_point(Vector2(territory.EndX, territory.EndY)),
		source_grid_point(Vector2(territory.StartX, territory.EndY))])
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for point: Vector2 in corners: bounds = bounds.expand(point)
	corners.append(corners[0])
	destination_outline.points = corners
	camera.zoom = Vector2.ONE
	# Frame the full region for inspection. No actor arrival point is chosen,
	# and the original start/end coordinates in the portal table are untouched.
	camera.position = bounds.get_center()-Vector2(0,110)
	print("BASE508_PORTAL_REGION_INSPECT ", JSON.stringify({"portal_id": portal_id, "target_region": territory, "actor_teleported": false}))

func focus_npc_territory(territory_id: int) -> void:
	if portal_overlay == null: return
	var records: Array = []
	for record: Dictionary in pack.npc_territory_records():
		if int(record.territory_id) == territory_id: records.append(record)
	if records.is_empty(): return
	var raw: Array = records[0].source_bounds
	var corners := PackedVector2Array([source_grid_point(Vector2(raw[0],raw[1])),source_grid_point(Vector2(raw[2],raw[1])),source_grid_point(Vector2(raw[2],raw[3])),source_grid_point(Vector2(raw[0],raw[3]))])
	var bounds := Rect2(corners[0],Vector2.ZERO)
	for point: Vector2 in corners: bounds = bounds.expand(point)
	corners.append(corners[0])
	destination_outline.points = corners
	var fit: float = minf(get_viewport_rect().size.x/maxf(bounds.size.x+160,1),(get_viewport_rect().size.y-240)/maxf(bounds.size.y+160,1))
	camera.zoom = Vector2.ONE*minf(fit,1.0)
	camera.position = bounds.get_center()-Vector2(0,110/camera.zoom.x)
	set_meta("inspected_npc_region",territory_id)
	print("BASE508_NPC_REGION_INSPECT ",JSON.stringify({"territory_id":territory_id,"source_records":records,"actors_instantiated":0,"region_bounds_preserved":true}))

func _process(delta: float) -> void:
	if camera == null: return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	camera.position += move*600*delta/camera.zoom.x
	stream_art()
	frames += 1
	if frames == 1 and has_meta("inspected_npc_region"):
		label.text += "NPC territory %d: original source bounds only; no random center/spawn or collision inferred\n" % int(get_meta("inspected_npc_region"))
	if frames > 30: frame_times.append(delta*1000.0)
	if not capture_path.is_empty() and frames == capture_after:
		capture.call_deferred()

func stream_art() -> void:
	# Overview avoids loading 128M pixels at fit zoom. Detail is capped at 32 MiB RGBA.
	if camera.zoom.x < .35:
		for sprite: Sprite2D in sprites.values(): sprite.queue_free()
		sprites.clear()
		return
	var extent := get_viewport_rect().size/camera.zoom
	var view := Rect2(camera.position-extent*.5, extent)
	var wanted: Dictionary = {}
	for row: Dictionary in pack.manifest.art.chunks:
		if Rect2(Vector2(row.position[0], row.position[1]), Vector2(row.size[0], row.size[1])).intersects(view):
			wanted[str(row.file)] = row
	for file: String in sprites.keys():
		if not wanted.has(file):
			sprites[file].queue_free()
			sprites.erase(file)
	# Bounded synchronous decode: at most one 1024² piece per frame, 8 textures.
	for file: String in wanted:
		if sprites.has(file): continue
		if sprites.size() >= 8: break
		var row: Dictionary = wanted[file]
		var path: String = pack.safe_file(file)
		if not inspected.has(file):
			if FileAccess.get_sha256(path) != str(row.sha256):
				push_error("Original PNG chunk SHA mismatch: " + file)
				return
			inspected[file] = true
		var image := Image.new()
		if image.load(path) != OK: return
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.position = Vector2(row.position[0], row.position[1])
		sprite.texture = ImageTexture.create_from_image(image)
		add_child(sprite)
		sprites[file] = sprite
		rendered_chunks += 1
		break

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	frame_times.sort()
	var elapsed: float = float(Time.get_ticks_usec()-start_us)/1000000.0
	var frame_sum: float = 0
	for ms: float in frame_times: frame_sum += ms
	print("BASE508_RENDER_EVIDENCE ", JSON.stringify({"frames": frames, "elapsed_seconds": elapsed, "resource_load_ms": resource_load_ms, "render_fps_including_first_frames": frames/elapsed, "steady_fps": 1000*frame_times.size()/frame_sum if frame_sum > 0 else 0, "p95_ms": frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0, "detail_chunks_decoded": rendered_chunks, "report": pack.manifest.report, "screenshot": capture_path}))
	get_tree().quit()
