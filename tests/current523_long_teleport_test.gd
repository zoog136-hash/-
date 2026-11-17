extends SceneTree
## Long teleports across Aden mainland villages on the original 523 map.
##
## Background (2026-11-16): a probe that wrote raw positions found signal 11
## after the third "teleport". The native backtrace resolved to
## GDScriptFunctionState::resume -> GDScriptFunction::call -> Variant::callp
## on a freed Node: the probe had moved the player into a blocked Giran cell,
## the renderer safely closed the 523 session (_scope_problem: "원문 자체 통행의
## 지원 영역 밖"), the town NPC layer node was freed, and the probe called a
## method on its typed local copy after `await` (no freed check without a
## debugger). No engine-side use-after-free was found.
##
## Always: the landing contract every in-game teleport relies on — on a 523
## source field point_clear (the renderer's per-frame scope check) is exactly
## walkable (what teleport landings test), so a landing the game accepts can
## never close the session.
## With --source523-pack=<root> (actual Main): repeated real teleports
## (content523_enter_land, i.e. the scroll path that rebuilds field+renderer
## and frees the previous map) keep the session open, free every previous
## field, and keep memory bounded. Objects are held only through weakref.
const WAIVE := ["NoTeleport","TurnOffAutoForTeleport","NoPurplePushOnDie","NpcBuff","NoTeleportCome","LandPlayerSocketTimeoutSecond","ObjectLazyLoad","IdleTime","UsableCallClan","CompetitionDungeonLand","LandCondition"]
## Source cells next to each village's original NPC (Land 4).
const TOWNS := {"aden":[33051,32758],"gludio":[32612,32789],"giran":[33430,32807],"giran_north":[33465,32658]}
const ORDER := ["aden","gludio","giran","giran_north","gludio","aden","giran"]
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const START_VILLAGE = preload("res://scripts/maps/current523_start_village.gd")

class GridField extends "res://scripts/maps/current523_source_field.gd":
	var blocked: Dictionary = {}
	var size: int = 64
	func _cell_allowed(cell: Vector2i) -> bool: return loaded and cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size and not blocked.has(cell)

class FakeTiles extends RefCounted:
	var problem: String = ""
	var known: Dictionary = {}
	var image: Texture2D
	func _init() -> void: image = ImageTexture.create_from_image(Image.create_empty(24, 24, false, Image.FORMAT_RGBA8))
	func has_tile(id: int) -> bool: return known.has(id)
	func texture_for(_id: int) -> Texture2D: return image
	func cache_size() -> int: return known.size()

func _grid_field() -> GridField:
	var value := GridField.new()
	value.coordinates.configure([0, 0], [64, 64], {"translation": [0, 768]})
	return value

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CURRENT523_LONG_TELEPORT_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func landing_contract() -> void:
	var field := _grid_field()
	field.loaded = true
	for i: int in 64: field.blocked[Vector2i(i, (i * 7) % 64)] = true; field.blocked[Vector2i((i * 5) % 64, i)] = true
	var agree: bool = true
	var both: Dictionary = {"walkable":0,"blocked":0}
	for y: int in 64:
		for x: int in 64:
			var p: Vector2 = field.cell_to_world(Vector2i(x, y))
			var w: bool = field.walkable(p)
			both["walkable" if w else "blocked"] += 1
			for padding: float in [4.0, 24.0]: agree = agree and field.point_clear(p, padding) == w
	evidence["landing_contract"] = both
	check(both.walkable > 0 and both.blocked > 0, "synthetic grid has open and blocked cells")
	check(agree, "523 source field: point_clear(p, padding) == walkable(p) for every cell")
	# Nearest clear cell (actor recovery instead of closing the session).
	var blocked_cell := Vector2i(10, 10)
	field.blocked[blocked_cell] = true
	var start: Vector2 = field.coordinates.to_world(Vector2(blocked_cell))
	var near: Dictionary = field.nearest_clear_point(start, 24)
	check(not field.walkable(start) and near.get("ok", false) and field.point_clear(near.position, 4) and int(near.ring) >= 1, "nearest_clear_point leaves a blocked cell for a clear one")
	var veto: Dictionary = field.nearest_clear_point(start, 24, func(p: Vector2) -> bool: return p.distance_to(start) > 100.0)
	check(veto.get("ok", false) and veto.position.distance_to(start) > 100.0, "nearest_clear_point honours the coverage veto")
	var walled := _grid_field()
	walled.loaded = true
	walled.size = 0
	check(not walled.nearest_clear_point(start, 8).get("ok", false), "no clear cell within the radius is reported, never invented")

func recovery_contract() -> void:
	var field := _grid_field()
	field.loaded = true
	field.set_meta("current523_source_field", true)
	var actor := CharacterBody2D.new()
	root.add_child(actor)
	var renderer = RENDERER.new()
	root.add_child(renderer)
	renderer.field = field
	renderer.player = actor
	renderer._legacy_origins = {Vector2i(0, 0): true}
	renderer._overlap = {Vector2i(0, 0): "synthetic"}
	renderer._configured = true
	var recovered: Array = []
	renderer.actor_position_recovered.connect(func(detail: Dictionary) -> void: recovered.append(detail))
	field.blocked[Vector2i(20, 20)] = true
	actor.global_position = field.coordinates.to_world(Vector2(20, 20))
	actor.velocity = Vector2(50, 0)
	check(renderer._scope_problem() == "" and renderer.actor_point_ok(actor.global_position), "runtime: an actor on a blocked cell is moved to a clear cell, the session stays")
	check(recovered.size() == 1 and recovered[0].kind == "nearest_clear_cell" and renderer.position_recoveries == 1 and actor.velocity == Vector2.ZERO, "recovery is reported once and stops the actor")
	# Outside the painted coverage with no clear cell near: village fallback.
	actor.global_position = field.coordinates.to_world(Vector2(40, 200))
	var village: Vector2 = field.coordinates.to_world(Vector2(5, 5))
	renderer.recovery_fallback = func() -> Variant: return village
	check(renderer._scope_problem() == "" and actor.global_position == village and recovered.back().kind == "village_return", "no clear covered cell near: the owner's village point is used")
	renderer.recovery_fallback = Callable()
	actor.global_position = field.coordinates.to_world(Vector2(40, 200))
	check(renderer._scope_problem() == RENDERER.POSITION_SCOPE_PROBLEM, "nothing recoverable: the scope problem is still reported (session closes with a reason)")
	renderer._configured = false
	actor.global_position = field.coordinates.to_world(Vector2(20, 20))
	check(renderer._scope_problem() == RENDERER.POSITION_SCOPE_PROBLEM and renderer.position_recoveries == 2, "try_configure never moves the actor (no recovery before the session runs)")
	# A tile the pack lacks is a hole, not a session close.
	var tiles := FakeTiles.new()
	tiles.known = {1: true}
	renderer._tile_pack = tiles
	renderer._configured = true
	actor.global_position = field.coordinates.to_world(Vector2(5, 5))
	var here: Vector2 = actor.global_position
	renderer._chunk_rects = {"synthetic": Rect2(here - Vector2(32, 32), Vector2(64, 64))}
	renderer._raw_chunks = {"synthetic": {-2: PackedInt64Array([int(here.x), int(here.y), 1 << 8, int(here.x), int(here.y), 2 << 8])}}
	var failed: Array = []
	renderer.safe_return_requested.connect(func(reason: String) -> void: failed.append(reason))
	var built: bool = renderer._build_frame()
	check(built and renderer.problem.is_empty() and renderer.frame_metrics().get("unresolved_refs", -1) == 1 and renderer.frame_metrics().get("draw_commands", -1) == 1, "an unresolved tile is skipped and counted; the frame still builds")
	evidence["recovery"] = {"last":renderer.last_position_recovery, "unresolved_refs":renderer.unresolved_tile_refs}
	renderer.queue_free(); actor.queue_free()
	await process_frame
	check(failed.is_empty(), "no safe return was requested for recoverable problems")

func _mb() -> float: return OS.get_static_memory_usage() / 1048576.0

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in 120: await process_frame
	# Actual Main shows the renewal class picker on a fresh save; the older
	# HUD workspace picker is the fallback.
	var picker: Node = _find_script(root, "renewal_class_select.gd")
	if picker != null:
		picker.call("_choose", "기사")
		if picker.has_method("_choose_gender"): picker.call("_choose_gender", 1)
		picker.call("_confirm")
	else: QA.enter_game(world)
	picker = null
	for frame: int in 900:
		await process_frame
		if world.current523_aden_source_active(): break
	if not world.current523_aden_source_active():
		evidence["runtime"] = "original 523 map not active (run with --source523-pack=<root>): teleport part skipped"
		world.queue_free(); await process_frame; return
	world.save_timer = -100000
	start_village(world)
	var steps: int = int(OS.get_environment("LONG_TELEPORT_STEPS")) if OS.get_environment("LONG_TELEPORT_STEPS") != "" else 21
	var settle: int = int(OS.get_environment("LONG_TELEPORT_FRAMES")) if OS.get_environment("LONG_TELEPORT_FRAMES") != "" else 45
	var previous_fields: Array = []
	var baseline_mb: float = -1.0
	var baseline_nodes: int = -1
	var moved: int = 0
	var rows: Array = []
	for i: int in steps:
		var town: String = ORDER[i % ORDER.size()]
		var cell: Array = TOWNS[town]
		var before: WeakRef = weakref(world.field_map)
		var result: Dictionary = world.content523_enter_land(4, [int(cell[0]) - 6, int(cell[1]) - 6, int(cell[0]) + 6, int(cell[1]) + 6], WAIVE)
		for frame: int in settle: await process_frame
		var active: bool = world.current523_aden_source_active()
		var field_now: Object = world.field_map
		var clear: bool = active and field_now != null and world.field_renderer.actor_point_ok(world.player.global_position)
		if result.get("ok", false): moved += 1
		previous_fields.append(before)
		var row: Dictionary = {"step":i,"town":town,"ok":result.get("ok",false),"reason":str(result.get("reason","")),"active":active,"clear":clear,
			"static_mb":snappedf(_mb(),0.1),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT))}
		rows.append(row)
		print("LONG_TELEPORT_STEP ", JSON.stringify(row))
		if not check(active and result.get("ok", false), "teleport %d to %s keeps the 523 session (%s)" % [i, town, row.reason]): break
		check(clear, "teleport %d to %s lands on a clear source cell" % [i, town])
		if i == 2: baseline_mb = _mb(); baseline_nodes = row.nodes
	for frame: int in 30: await process_frame
	var alive: int = 0
	for ref: WeakRef in previous_fields.slice(0, maxi(0, previous_fields.size() - 1)):
		if ref.get_ref() != null and ref.get_ref() != world.field_map: alive += 1
	var final_mb: float = _mb()
	var final_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	evidence["runtime"] = {"steps":steps,"moved":moved,"previous_fields_alive":alive,"baseline_mb":snappedf(baseline_mb,0.1),"final_mb":snappedf(final_mb,0.1),
		"baseline_nodes":baseline_nodes,"final_nodes":final_nodes,"gpu_textures":OS.get_environment("TWILIGHT_GPU_ACTOR_TEXTURES") != "0"}
	check(moved == steps, "every teleport moved (%d/%d)" % [moved, steps])
	check(alive == 0, "every previous 523 field is freed after its teleport (%d alive)" % alive)
	if baseline_mb >= 0.0:
		check(final_mb - baseline_mb < 160.0, "static memory stays bounded over repeated teleports (+%.1f MB)" % (final_mb - baseline_mb))
		check(final_nodes < int(baseline_nodes * 1.35) + 200, "node count stays bounded (%d -> %d)" % [baseline_nodes, final_nodes])
	await blocked_entry(world)
	await village_fallback(world)
	world.queue_free()
	for frame: int in 3: await process_frame

## A saved/relocated spot on a blocked cell (old save, #485 relocation) used to
## leave the player on the old aden_world: reopening now starts on a clear cell.
func blocked_entry(world: Node) -> void:
	if not world.current523_aden_source_active(): return
	var field_now: Object = world.field_map
	var renderer: Object = world.field_renderer
	var center: Vector2i = Vector2i(int(TOWNS.aden[0]), int(TOWNS.aden[1]))
	var blocked := Vector2i(-1, -1)
	for ring: int in range(1, 16):
		for y: int in range(center.y - ring, center.y + ring + 1):
			for x: int in range(center.x - ring, center.x + ring + 1):
				if blocked.x >= 0: break
				var p: Vector2 = field_now.coordinates.to_world(Vector2(x, y))
				if not field_now.walkable(p) and renderer.support_world_point(p): blocked = Vector2i(x, y)
	if not check(blocked.x >= 0, "a blocked covered cell exists near Aden village"): return
	var controller: RefCounted = world.call("_aden_play_controller")
	var options: Dictionary = (controller.get("settings") as Dictionary).duplicate(true)
	options["source_position"] = [blocked.x + 0.5, blocked.y + 0.5]
	world.close_current523_aden_play(false)
	for frame: int in 10: await process_frame
	var opened: bool = world.open_current523_aden_play(str(options.raw_root), str(options.tile_root), options)
	for frame: int in 30: await process_frame
	var recovery: Dictionary = controller.get("entry_recovery")
	evidence["blocked_entry"] = {"blocked_cell":[blocked.x, blocked.y], "opened":opened, "active":world.current523_aden_source_active(), "recovery":recovery.duplicate(true), "problem":str(world.get("current523_aden_play_problem"))}
	check(opened and world.current523_aden_source_active() and not recovery.is_empty(), "a blocked saved spot opens the 523 map on a nearby clear cell (no old-map fallback)")
	check(world.current523_aden_source_active() and world.field_renderer.actor_point_ok(world.player.global_position), "the reopened actor stands on a clear covered cell")

## 사용자 결정 2026-11-17: a new character starts in Giran town (original
## Locations473 "[리스타트 좌표] 기란 마을", inside TerritoriesVillage1367) on a
## walkable cell, with original Giran town NPCs (EarthObjectSpawn) around.
func start_village(world: Node) -> void:
	var here: Dictionary = world.orim_current_land()
	var cell := Vector2i(int(here.get("cell",[0,0])[0]), int(here.get("cell",[0,0])[1])) if here.get("cell",[]) is Array and (here.get("cell",[]) as Array).size() == 2 else Vector2i(-1,-1)
	var offset: int = maxi(absi(cell.x - START_VILLAGE.cell().x), absi(cell.y - START_VILLAGE.cell().y))
	var npcs: Array = []
	for npc: Variant in (world.field_map.data.get("npc_spawn",[]) if world.field_map != null else []):
		if not npc is Dictionary or not npc.get("source_position") is Array: continue
		var at: Array = npc.source_position
		if maxi(absi(int(at[0]) - cell.x), absi(int(at[1]) - cell.y)) <= 20: npcs.append({"name":str(npc.get("name","")),"cell":at,"spawn":int(npc.get("source523_earth_object_spawn_id",0))})
	evidence["start_village"] = {"land":here,"location":START_VILLAGE.LOCATION,"ring":offset,"npcs_within_20":npcs.size(),"npcs":npcs.slice(0,12),"walkable":world.field_map.walkable(world.player.global_position)}
	print("GIRAN_START ", JSON.stringify(evidence.start_village))
	check(int(here.get("land_id",-1)) == 4 and START_VILLAGE.in_village(cell) and offset <= 8, "a new character starts in Giran village next to Locations473 (cell %s, ring %d)" % [str(cell), offset])
	check(world.field_map.walkable(world.player.global_position) and world.field_renderer.actor_point_ok(world.player.global_position), "the Giran start cell is walkable and covered")
	check(npcs.size() >= 3, "original Giran town NPCs are near the start (%d within 20 cells)" % npcs.size())
	var controller: RefCounted = world.call("_aden_play_controller")
	var fallback: Variant = controller.call("_recovery_fallback_point")
	var fallback_cell: Vector2i = world.field_map.world_to_cell(fallback) + world.field_map.coordinates.origin if fallback is Vector2 else Vector2i(-1,-1)
	evidence["recovery_fallback_cell"] = [fallback_cell.x, fallback_cell.y]
	check(fallback is Vector2 and START_VILLAGE.in_village(fallback_cell), "the runtime village fallback is Giran (%s)" % str(fallback_cell))

## A spot with no clear cell within the recovery radius (open sea) falls back to
## the start village: Giran town.
func village_fallback(world: Node) -> void:
	if not world.current523_aden_source_active(): return
	var field_now: Object = world.field_map
	var bounds: Rect2i = field_now.get("source_bounds") if field_now.get("source_bounds") is Rect2i else Rect2i()
	var stranded := Vector2i(-1, -1)
	if bounds.has_area():
		for gy: int in range(1, 16):
			for gx: int in range(1, 16):
				if stranded.x >= 0: break
				var probe := Vector2i(bounds.position.x + bounds.size.x * gx / 16, bounds.position.y + bounds.size.y * gy / 16)
				var p: Vector2 = field_now.coordinates.to_world(Vector2(probe.x, probe.y))
				if not field_now.call("nearest_clear_point", p, RENDERER.RECOVERY_RADIUS_CELLS, Callable()).get("ok", false): stranded = probe
	if not check(stranded.x >= 0, "a cell with no clear cell within %d exists on Land 4" % RENDERER.RECOVERY_RADIUS_CELLS): return
	var controller: RefCounted = world.call("_aden_play_controller")
	var options: Dictionary = (controller.get("settings") as Dictionary).duplicate(true)
	options["source_position"] = [stranded.x + 0.5, stranded.y + 0.5]
	world.close_current523_aden_play(false)
	for frame: int in 10: await process_frame
	var opened: bool = world.open_current523_aden_play(str(options.raw_root), str(options.tile_root), options)
	for frame: int in 30: await process_frame
	var recovery: Dictionary = controller.get("entry_recovery")
	var here: Dictionary = world.orim_current_land() if world.current523_aden_source_active() else {}
	var cell := Vector2i(int(here.cell[0]), int(here.cell[1])) if here.get("cell") is Array else Vector2i(-1, -1)
	evidence["village_fallback"] = {"stranded_cell":[stranded.x, stranded.y], "opened":opened, "recovery_kind":str(recovery.get("kind","")), "landed":here}
	print("GIRAN_FALLBACK ", JSON.stringify(evidence.village_fallback))
	check(opened and str(recovery.get("kind","")) == "village_return", "a stranded spot opens through the village fallback")
	check(START_VILLAGE.in_village(cell) and world.field_renderer.actor_point_ok(world.player.global_position), "the village fallback lands in Giran town on a clear cell (%s)" % str(cell))
	# The return scroll destination (own policy, no original Territory->village table) is Giran too.
	var returned: Dictionary = world.return_current523_source_to_aden()
	for frame: int in 30: await process_frame
	here = world.orim_current_land() if world.current523_aden_source_active() else {}
	cell = Vector2i(int(here.cell[0]), int(here.cell[1])) if here.get("cell") is Array else Vector2i(-1, -1)
	evidence["return_scroll"] = {"ok":returned.get("ok",false),"policy":str(returned.get("policy","")),"reason":str(returned.get("reason","")),"landed":here}
	check(returned.get("ok",false) and str(returned.get("policy","")) == START_VILLAGE.POLICY and int(returned.get("source_location",{}).get("ID",0)) == 473 and START_VILLAGE.in_village(cell), "the 523 return lands in Giran town: " + str(evidence.return_scroll))
	# An existing character at a normal saved spot (here Aden town) is not moved.
	check(world._save_game(true) == OK, "save after the Giran return")
	var file: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	if not check(file is Dictionary, "the save reads back"): return
	var aden_spot: Dictionary = {"native_land_id":4, "source_position":[33923.5, 33350.5]}
	file["character_source_cursor"] = aden_spot
	var writer := FileAccess.open(world.save_path(), FileAccess.WRITE); writer.store_string(JSON.stringify(file)); writer.close()
	world._load_game(true)
	evidence["normal_save_cursor_after_load"] = world.character_source_cursor.duplicate(true)
	# JSON reads numbers back as floats: compare values, not variant types.
	check(int(world.character_source_cursor.get("native_land_id",-1)) == 4 and world.character_source_cursor.get("source_position",[]) == aden_spot.source_position and not world.source_save_blocked,"a normal saved spot loads unchanged (not moved to Giran)")

func _find_script(node: Node, file: String) -> Node:
	var script: Variant = node.get_script()
	if script != null and str(script.resource_path).ends_with(file): return node
	for child: Node in node.get_children():
		var found: Node = _find_script(child, file)
		if found != null: return found
	return null

func run() -> void:
	landing_contract()
	await recovery_contract()
	var has_pack: bool = false
	for value: String in OS.get_cmdline_user_args(): has_pack = has_pack or value.begins_with("--source523-pack=")
	if has_pack: await runtime()
	else: evidence["runtime"] = "no --source523-pack: teleport part skipped"
	print("CURRENT523_LONG_TELEPORT_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
