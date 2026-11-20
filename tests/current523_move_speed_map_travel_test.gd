extends SceneTree
## User report 2026-11-17: "이속이 너무빠른데?" / "맵 이동이 안돼".
##
## Always (synthetic): the original walk speed (ListSprAction Walk
## PlayerFrameRate 36 / PlayerDelay 16 = 2.25 cells/s, Chebyshev cells on the
## 48x24 diamond) in every direction, the old flat speed off 523 fields, the
## walk animation clock matching one cell step, and the map-teleport rows /
## quote shape.
## With --source523-pack=<root> (actual Main on the original 523 Aden):
## walking covers 2.25 cells/s sideways and up/down; a 순간이동 주문서 moves on
## the current Land; the teleporter window lists the original UIMapArea rows
## and its 이동하기 moves to the destination's Territories box and debits the
## LandTeleport Adena; stepping onto a Portal source cell moves to its
## TargetTerritory; the world map is registered and a picked point walks.
const WALK = preload("res://scripts/maps/source_walk_speed.gd")
const MAP_TELEPORT = preload("res://scripts/maps/current523_map_teleport.gd")
const COORDS = preload("res://scripts/maps/source_coordinates.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const TELEPORT_WINDOW = preload("res://scripts/ui/original_ui/source_main_teleport_window.gd")
const WORLD_MAP_WALK = preload("res://scripts/maps/current523_world_map_walk.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var world: Node
var walk_roles: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("MOVE_SPEED_MAP_TRAVEL_FAIL: ", label)
	return condition

func _initialize() -> void: _run.call_deferred()

func _pack_root() -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): return value.trim_prefix("--source523-pack=")
	return ""

func _wait_for(condition: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if condition.call(): return true
		await process_frame
	return condition.call()

class FakeField extends RefCounted:
	var coordinates: RefCounted

func synthetic() -> void:
	var c := COORDS.new()
	c.configure([0, 0], [64, 64])
	var cps: float = WALK.cells_per_second()
	evidence["walk_source"] = WALK.source()
	check(is_equal_approx(cps, 36.0 / 16.0), "base walk = PlayerFrameRate 36 / PlayerDelay 16 = 2.25 cells/s (%s)" % cps)
	check(is_equal_approx(WALK.step_seconds(), 16.0 / 36.0), "one cell step = 0.444 s")
	var sideways: Vector2 = WALK.velocity(c, Vector2.RIGHT, cps)
	var vertical: Vector2 = WALK.velocity(c, Vector2.DOWN, cps)
	var axis: Vector2 = WALK.velocity(c, Vector2(24, -12), cps)
	evidence["px_per_s"] = {"sideways": sideways.length(), "vertical": vertical.length(), "grid_axis": axis.length()}
	check(absf(sideways.length() - 108.0) < 0.01, "sideways 2.25 cells x 48 px = 108 px/s")
	check(absf(vertical.length() - 54.0) < 0.01, "up/down 2.25 cells x 24 px = 54 px/s")
	check(absf(axis.length() - 2.25 * Vector2(24, -12).length()) < 0.01, "grid axis 2.25 x 26.8 px")
	# Every direction: exactly 2.25 Chebyshev cells per second.
	var all_equal: bool = true
	for degrees: int in range(0, 360, 7):
		var direction := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		var v: Vector2 = WALK.velocity(c, direction, cps)
		var g: Vector2 = c.world_to_grid(v) - c.world_to_grid(Vector2.ZERO)
		all_equal = all_equal and absf(maxf(absf(g.x), absf(g.y)) - cps) < 0.0001
	check(all_equal, "every screen direction covers 2.25 cells/s (Chebyshev)")
	check(WALK.velocity(c, Vector2.RIGHT, cps * 1.5).length() > sideways.length() * 1.49, "speed bonuses keep scaling the walk")
	# Off a 523 field nothing changes.
	check(WALK.coordinates_of(null) == null and WALK.coordinates_of(FakeField.new()) == null, "non-523 fields keep the legacy flat speed")
	var player: Node = load("res://scenes/Player.tscn").instantiate() if ResourceLoader.exists("res://scenes/Player.tscn") else null
	if player != null:
		root.add_child(player)
		var legacy: Vector2 = player.call("_walk_velocity", Vector2.RIGHT, 210.0)
		check(absf(legacy.length() - 210.0) < 0.01, "legacy maps: flat 210 px/s unchanged")
		player.queue_free()
	# Animation: the walk cycle is stretched to one cell step.
	var scale: float = preload("res://scripts/player.gd").walk_clock_scale(0.6, 1.0)
	check(absf(scale - 0.6 / (16.0 / 36.0)) < 0.0001, "walk clock scale = cycle / step time")
	check(is_equal_approx(preload("res://scripts/player.gd").walk_clock_scale(0.0, 1.0), 1.0), "untimed walk tracks are left alone")
	# Map teleport rows without the original archive: nothing listed, no error.
	if DEF.not_installed():
		check(MAP_TELEPORT.destinations().is_empty(), "no original archive: no invented destinations")
		check(not MAP_TELEPORT.quote(Node.new(), "m523area:20").get("ok", true), "no original archive: quote refuses")
	check(MAP_TELEPORT.is_destination_id("m523area:20") and not MAP_TELEPORT.is_destination_id("aden_world"), "destination ids are namespaced")
	check(MAP_TELEPORT._strip_tags("[던전] [기란] 용의 던전") == "용의 던전", "tag stripping fallback for names")
	# 2026-11-20 "하딘의 텔레포트도 안되고": Gem (다이아) rows are listed and
	# paid with the game's 다이아; the tab's NPC_On clip shows 이동하기.
	check(MAP_TELEPORT.CURRENCY_NAMES.get(MAP_TELEPORT.GEM) == "다이아" and MAP_TELEPORT.CURRENCY_NAMES.has(MAP_TELEPORT.ADENA), "LandTeleport CurrencyID 1 (아데나) and 4 (Gem = 다이아) are listed")
	var window_text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_teleport_window.gd")
	check(TELEPORT_WINDOW.INTRO_CLIP == "NPC_On" and window_text.contains("_intro(next,out,"), "the teleport tab plays its NPC_On clip (이동하기 and 비용 fade in from alpha 0)")
	check(window_text.contains("GEM_ICON if _gem(chosen) else ADENA_ICON"), "a 하딘 row shows the pack's Com_Icn_Gem price icon")

func _cell() -> Vector2i:
	return world.field_map.world_to_cell(world.player.global_position) + world.field_map.coordinates.origin

func _walk(direction: Vector2, frames: int) -> Vector2:
	var s0: Vector2 = world.field_map.coordinates.to_source(world.player.global_position)
	var started: int = Time.get_ticks_usec()
	world.player.set_touch_vector(direction)
	for i: int in frames:
		await physics_frame
		var key: String = "%s/%s/%.2f" % [world.player.motion.state, world.player.original_source_preview.source_role(), float(world.player.get("_walk_clock_scale"))]
		walk_roles[key] = int(walk_roles.get(key, 0)) + 1
	world.player.set_touch_vector(Vector2.ZERO)
	var seconds: float = float(frames) / float(Engine.physics_ticks_per_second)
	var s1: Vector2 = world.field_map.coordinates.to_source(world.player.global_position)
	evidence["walk_wall_s_" + str(direction)] = (Time.get_ticks_usec() - started) / 1000000.0
	return (s1 - s0) / seconds

func real_main(base: String) -> void:
	if root.get_node_or_null("Source523Pack") == null or not bool(root.get_node("Source523Pack").get("configured")):
		var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
		check(read.ok, "installed pack descriptor")
		if read.ok: PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base)))
	HOST.refresh()
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var opened: bool = await _wait_for(func() -> bool: return bool(world.get("current523_aden_play_active")), 1500)
	if not check(opened, "523 play mode active: " + str(world.get("current523_aden_play_problem"))): return
	# A fresh profile starts at the class window; play as a player would.
	check(QA.enter_game(world), "class chosen (game entered)")
	await _wait_for(func() -> bool: return world.player.original_source_preview.installed(), 600)
	for i: int in 60: await process_frame
	world.level = maxi(int(world.level), 60)
	world.gold = 2000000
	evidence["old_map_list"] = {"maps": (world.get("maps") as Array).size(), "oman_01": (world.get("maps_by_id") as Dictionary).has("oman_01")}
	evidence["start"] = {"land": world.field_map.native_land.get("ID"), "cell": [_cell().x, _cell().y]}
	# 1) speed
	var mult: float = world.player.walk_speed_multiplier()
	var cps: float = WALK.cells_per_second() * mult
	var side: Vector2 = await _walk(Vector2.RIGHT, 60)
	var down: Vector2 = await _walk(Vector2.DOWN, 60)
	var side_back: Vector2 = await _walk(Vector2.LEFT, 60)
	evidence["measured_cells_per_s"] = {"right": [side.x, side.y], "down": [down.x, down.y], "left": [side_back.x, side_back.y], "expected": cps, "multiplier": mult}
	var cheb := func(v: Vector2) -> float: return maxf(absf(v.x), absf(v.y))
	# Collisions may cut a walk short, never make it faster.
	check(cheb.call(side) <= cps * 1.05 and cheb.call(down) <= cps * 1.05 and cheb.call(side_back) <= cps * 1.05, "no walk is faster than the original 2.25 cells/s x bonuses")
	check(maxf(cheb.call(side), maxf(cheb.call(down), cheb.call(side_back))) >= cps * 0.8, "an open walk reaches the original speed")
	var walk_scale: float = float(world.player.get("_walk_clock_scale"))
	evidence["walk_clock_scale"] = walk_scale
	var preview: Node = world.player.original_source_preview
	evidence["walk_cycle_s"] = preview.call("role_cycle_seconds", "walk")
	var track_info: Dictionary = {}
	var tracks: Variant = preview.get("_playback_tracks")
	if tracks is Dictionary:
		for role: Variant in tracks:
			var t: Dictionary = tracks[role]
			var dirs: Array = t.get("directions", [])
			track_info[str(role)] = {"static": t.get("static_pending_timing"), "fps": t.get("fps"), "frames": (dirs[0] as Array).size() if not dirs.is_empty() else 0, "cycle": preview.call("role_cycle_seconds", str(role)), "cooked": t.get("cooked", false)}
	evidence["player_tracks"] = {"installed": preview.installed(), "source_only": world.player.get("_source_only_class"), "transform": world.player.transform_active, "tracks": track_info, "walk_roles": walk_roles}
	# 2) teleport scroll (순간이동 주문서, ItemClass 313)
	var scroll: String = ""
	for key: Variant in world.inventory.keys():
		if str(key).contains("순간이동 주문서"): scroll = str(key); break
	if scroll.is_empty():
		evidence["scroll"] = "not in starter bag"
	else:
		var before: Vector2i = _cell()
		var count: int = int(world.inventory.get(scroll, 0))
		world.portal_cooldown = 0.0
		world._use_quick_item(scroll)
		for i: int in 20: await process_frame
		evidence["scroll"] = {"name": scroll, "from": [before.x, before.y], "to": [_cell().x, _cell().y], "msg": str(world.hud.message_label.text)}
		check(_cell() != before and bool(world.current523_aden_play_active), "순간이동 주문서 moves on the current 523 Land")
		check(int(world.inventory.get(scroll, 0)) == count - 1, "the scroll is consumed once")
		check(world.field_map.walkable(world.player.global_position), "the scroll lands on a walkable cell")
	# 3) teleporter window -> original destinations
	var rows: Array = TELEPORT_WINDOW.destinations(world)
	evidence["teleport_rows"] = rows.size()
	check(rows.size() >= 50 and str(rows[0].id).begins_with("m523area:"), "the teleport window lists the original UIMapArea rows (%d)" % rows.size())
	var gludin_row: Dictionary = MAP_TELEPORT.destination("m523area:12")
	check(gludin_row.get("price") == 4000 and gludin_row.get("land_id") == 4, "글루딘 마을: LandTeleport 3 = 4000 Adena, Land 4")
	# A Land 4 village the player is not standing in (the scroll may have landed in one).
	var gludin: Dictionary = {}
	for id: String in ["m523area:12", "m523area:20", "m523area:26", "m523area:13"]:
		if MAP_TELEPORT.quote(world, id).get("ok", false): gludin = MAP_TELEPORT.destination(id); break
	check(not gludin.is_empty(), "a Land 4 village destination is quotable")
	evidence["teleport_target"] = gludin.get("id", "")
	world.player.set_auto_enabled(true)
	var gold_before: int = int(world.gold)
	world.hud.call("open_npc_teleport")
	for i: int in 5: await process_frame
	var controller: Object = world.hud.original_main_ui_controller
	var window: Variant = controller.call("teleport_window") if is_instance_valid(controller) and controller.has_method("teleport_window") else null
	var result: Dictionary = {}
	if window != null and window.is_open():
		window._select(str(gludin.get("id", "")))
		result = window._teleport_requested()
	else:
		result = {"result": world.current523_map_teleport(str(gludin.get("id", "")))}
	for i: int in 30: await process_frame
	evidence["teleport_result"] = result
	var cell: Vector2i = _cell()
	var b: Array = gludin.get("bounds", [0, 0, -1, -1])
	check(bool(result.get("moved", result.get("result", {}).get("ok", false))), "이동하기 moved: " + str(result))
	check(int(world.field_map.native_land.get("ID", -1)) == 4 and cell.x >= int(b[0]) and cell.x <= int(b[2]) and cell.y >= int(b[1]) and cell.y <= int(b[3]), "arrived inside the destination Territories box")
	check(int(world.gold) == gold_before - int(gludin.get("price", -1)), "%d Adena debited (%d -> %d)" % [int(gludin.get("price", -1)), gold_before, int(world.gold)])
	check(not world.player.auto_enabled, "auto hunting is off on arrival")
	check(not MAP_TELEPORT.quote(world, str(gludin.get("id", ""))).get("ok", true), "already there: the quote refuses")
	world.player.set_auto_enabled(false)
	# 3b) 하딘의 텔레포트 (다이아): the window's own 이동하기 after NPC_On.
	var hadin: Dictionary = MAP_TELEPORT.destination("m523area:913")
	check(hadin.get("currency_id") == MAP_TELEPORT.GEM and hadin.get("price") == 10 and hadin.get("land_id") == 4, "[맵텔] [하딘] 용의 계곡 정상: LandTeleport 613 = 10 Gem (다이아), Land 4")
	check(not MAP_TELEPORT.destination("m523area:1061").is_empty(), "이계의 균열 (TerritoryID 0) lands in its LandTeleportTerritories box")
	world.inventory["다이아"] = 0
	check(str(MAP_TELEPORT.quote(world, "m523area:913").get("reason", "")) == "이동 비용 다이아가 부족합니다", "다이아 0: the 하딘 row refuses")
	world.inventory["다이아"] = 25
	world.hud.call("open_npc_teleport")
	for i: int in 5: await process_frame
	window = controller.call("teleport_window") if is_instance_valid(controller) and controller.has_method("teleport_window") else null
	var hadin_result: Dictionary = {}
	if window != null and window.is_open():
		window._select("m523area:913")
		var located: Dictionary = preload("res://scripts/ui/original_ui/source_main_named_tree.gd").locate(window.get("_scene"), window.node_keys(), window.P_TAB + "Teleport_Enabled")
		var player: Variant = located.get("player")
		check(is_instance_valid(player) and str(player.playback_status().get("clip", "")) == "NPC_On", "the rebuilt tab shows its NPC_On end state")
		hadin_result = window._teleport_requested()
	else:
		hadin_result = {"result": world.current523_map_teleport("m523area:913")}
	for i: int in 30: await process_frame
	evidence["hadin_result"] = hadin_result
	var hb: Array = hadin.get("bounds", [0, 0, -1, -1])
	var hc: Vector2i = _cell()
	check(bool(hadin_result.get("moved", hadin_result.get("result", {}).get("ok", false))) and hc.x >= int(hb[0]) and hc.x <= int(hb[2]) and hc.y >= int(hb[1]) and hc.y <= int(hb[3]), "하딘 이동하기 moved into the destination box: " + str(hadin_result))
	check(int(world.inventory.get("다이아", 0)) == 15, "10 다이아 debited (%d left)" % int(world.inventory.get("다이아", 0)))
	world.inventory.erase("다이아")
	# 4) walk-in portal on this Land
	var cells: Dictionary = world.call("_aden_play_controller").call("source_portal_cells")
	evidence["portal_cells"] = cells.size()
	var picked: Dictionary = {}
	for portal_cell: Vector2i in cells:
		var row: Dictionary = DEF.row("Portal", int(cells[portal_cell]))
		var target: Dictionary = DEF.row("Territories", int(row.get("TargetTerritoryID", 0)))
		if target.is_empty() or int(target.LandID) == 4: continue
		var next: Vector2 = world.field_map.coordinates.to_world(Vector2(portal_cell + Vector2i(1, 0)))
		if not world.field_map.walkable(next): continue
		picked = {"portal": row, "target": target, "cell": portal_cell}
		break
	if check(not picked.is_empty(), "a Land 4 portal into another Land exists (%d portal cells)" % cells.size()):
		world.portal_cooldown = 0.0
		world.player.global_position = world.field_map.coordinates.to_world(Vector2(picked.cell + Vector2i(1, 0)))
		for i: int in 20: await physics_frame
		world.player.global_position = world.field_map.coordinates.to_world(Vector2(picked.cell))
		evidence["portal_gate"] = {"class_picker_initial": world.hud.get("class_picker_initial"), "cooldown": world.portal_cooldown, "auto": world.player.auto_enabled}
		var arrived: bool = await _wait_for(func() -> bool: return int(world.field_map.native_land.get("ID", -1)) == int(picked.target.LandID), 120)
		evidence["portal"] = {"id": picked.portal.ID, "target_land": picked.target.LandID, "result": world.call("_aden_play_controller").get("last_walk_in_portal")}
		check(arrived, "stepping onto Portal %d moves to Land %d" % [int(picked.portal.ID), int(picked.target.LandID)])
		if arrived:
			var t: Dictionary = picked.target
			var c2: Vector2i = _cell()
			check(c2.x >= int(t.StartX) and c2.x <= int(t.EndX) and c2.y >= int(t.StartY) and c2.y <= int(t.EndY), "landed inside the TargetTerritory box")
			for i: int in 30: await physics_frame
			check(int(world.field_map.native_land.get("ID", -1)) == int(picked.target.LandID), "the arrival cell does not fire another portal")
	# 5) world map: registered and a picked source point walks
	var status: Dictionary = world.current523_world_map_status
	evidence["world_map_status"] = {"ok": status.get("ok"), "registered": status.get("registered"), "reason": status.get("reason")}
	check(bool(status.get("ok", false)), "world map input registered: " + str(status.get("reason", "")))
	var field = world.field_map
	var here: Vector2i = _cell()
	var goal: Vector2i = Vector2i(-1, -1)
	for r: int in range(3, 12):
		for candidate: Vector2i in [here + Vector2i(r, 0), here + Vector2i(0, r), here + Vector2i(-r, 0), here + Vector2i(0, -r)]:
			if field.walkable(field.coordinates.to_world(Vector2(candidate))): goal = candidate; break
		if goal.x >= 0: break
	if goal.x >= 0:
		var ticket: Dictionary = WORLD_MAP_WALK.ticket(world, field)
		var again: Dictionary = WORLD_MAP_WALK.ticket(world, field)
		var changed: Array = []
		for key: Variant in ticket:
			if not again.has(key) or str(again[key]) != str(ticket[key]) or again[key] != ticket[key]: changed.append(str(key))
		evidence["world_map_ticket_unstable_keys"] = changed
		var walk: Dictionary = WORLD_MAP_WALK.request(world, field, [float(goal.x) + 0.5, float(goal.y) + 0.5], ticket)
		evidence["world_map_walk"] = {"ok": walk.get("ok"), "reason": walk.get("reason")}
		check(bool(walk.get("ok", false)), "world map point walk accepted: " + str(walk.get("reason", "")))
		var reached: bool = await _wait_for(func() -> bool: return _cell() == goal, 600)
		check(reached, "the player walks to the picked world map point")

func _run() -> void:
	# Actual Main first: the synthetic player scene must not stand in the tree
	# while Main starts.
	var base: String = _pack_root()
	if not base.is_empty():
		await real_main(base)
		if is_instance_valid(world): world.queue_free()
		for i: int in 5: await process_frame
	synthetic()
	evidence["real_input_checked"] = not base.is_empty()
	print("MOVE_SPEED_MAP_TRAVEL_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	await process_frame
	quit(0 if failures.is_empty() else 1)
