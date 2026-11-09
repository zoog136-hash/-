extends SceneTree
## P3-A step 1: while a 523 source field is active, the hidden prior field
## renderer is released and an equivalent one is rebuilt on return. Fixture
## world only (no Main, no pack); the world.gd factory is checked by contract.
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
var checks: int = 0
var failures: Array[String] = []

class ProbeRenderer extends FieldRenderer:
	var refreshes: int = 0
	func configure(value: PlayableField, actor: Node2D) -> void:
		field = value; player = actor
	func refresh_visible() -> void: refreshes += 1
	func set_visual_mode(requested: String) -> void: visual_mode = VISUAL_STYLE.normalize(requested)
	func _process(_delta: float) -> void: pass

class ProbeField extends PlayableField:
	func region_at(_p: Vector2) -> Dictionary: return {}

class ProbePlayer extends Node2D:
	var velocity := Vector2.ZERO
	var camera := Camera2D.new()
	func _init() -> void: add_child(camera)
	func clear_click_path() -> void: pass
	func set_touch_vector(_v: Vector2) -> void: pass

class ProbeService extends RefCounted:
	var calls: Array = []
	func activate(id: String) -> void: calls.append(id)
	func configure(_world: Node, _field: Variant) -> void: calls.append("configure")
	func set_map_name(_name: String) -> void: pass
	func show_message(_text: String) -> void: pass

class FakeWorld extends Node2D:
	var field_renderer: FieldRenderer
	var field_map: Variant
	var field_physics: StaticBody2D
	var world_size := Vector2.ONE
	var astar: AStarGrid2D
	var player := ProbePlayer.new()
	var world_interactions: Node
	var ground_loot := ProbeService.new()
	var field_minimap := ProbeService.new()
	var field_population := ProbeService.new()
	var hud := ProbeService.new()
	var region_id := ""
	var active_map_id := "aden_world"
	var active_map := {"name":"Aden"}
	var current523_prior_rebuild_suppressed := false
	var saved_mode := "twilight"
	var factory_calls: int = 0
	var factory_abort := false
	var saves: Array = []
	var set_map_calls: Array = []
	func _new_field_renderer(_field: PlayableField) -> Dictionary:
		factory_calls += 1
		return {"renderer":null,"abort":true} if factory_abort else {"renderer":ProbeRenderer.new(),"abort":false}
	func _mount_field_renderer(renderer: FieldRenderer, field: PlayableField) -> void:
		if not renderer.is_inside_tree():
			renderer.name = "FieldRenderer"
			add_child(renderer)
		renderer.configure(field, player)
	func _saved_visual_mode() -> String: return saved_mode
	func _save_game(_quiet: bool, _override: Dictionary) -> Error:
		saves.append({"renderer":field_renderer,"field":field_map})
		return OK
	func _set_map(id: String, keep: bool) -> void: set_map_calls.append([id, keep])

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

## Mirrors the end of `_open_source`: hide the prior, publish the source view.
func _enter(controller: RefCounted, world: FakeWorld, host: PlayableField, source: OriginalPlayableField) -> ProbeRenderer:
	var prior: FieldRenderer = world.field_renderer
	controller.set("_prior", prior)
	controller.set("_prior_visible", prior.visible); controller.set("_prior_mode", prior.process_mode)
	controller.set("_prior_world", {"field":host,"physics":null,"position":world.player.global_position,"world_size":world.world_size,"astar":null,
		"camera":{"left":0,"top":0,"right":4096,"bottom":4096},"physics_layer":0,"physics_mode":Node.PROCESS_MODE_INHERIT})
	prior.hide(); prior.process_mode = Node.PROCESS_MODE_DISABLED
	var view := ProbeRenderer.new()
	view.name = "Current523AdenSourceRenderer"
	world.add_child(view)
	world.field_map = source; world.field_renderer = view
	controller.set("_renderer", view); controller.set("_source_field", source)
	controller.source_owned = true; controller.active = true
	controller.call("_release_prior_renderer", world)
	return view

func _fixture(world: FakeWorld) -> ProbeRenderer:
	var before := Node2D.new(); before.name = "Before"
	world.add_child(before)
	var prior := ProbeRenderer.new()
	prior.name = "FieldRenderer"; prior.visual_mode = "classic"
	world.add_child(prior)
	var after := Node2D.new(); after.name = "After"
	world.add_child(after)
	world.field_renderer = prior
	return prior

func _save(controller: RefCounted, world: FakeWorld, options: Dictionary) -> Error:
	# The checkpoint cursor is not under test; settings stay the fixture profile.
	controller.settings = options.duplicate(true); controller.source_owned = false
	var result: Error = controller.call("save_source_progress", true, {})
	controller.source_owned = true
	return result

func _run() -> void:
	if FileAccess.file_exists(OPTIONS.PATH):
		push_error("Prior renderer guard requires an empty isolated user profile")
		quit(1); return
	var options: Dictionary = OPTIONS.validate({"enabled":true,"navigation_profile":OPTIONS.LEGACY,"offset_x":0,"offset_y":0,"raw_root":"/fixture/raw","tile_root":"/fixture/tiles"})
	check(CONTROLLER.RELEASE_PRIOR_RENDERER and bool(CONTROLLER.new().get("release_prior_renderer")), "release is on by default behind one flag")
	_contract()
	# --- flag on: release while the source field is active, rebuild on return ---
	var world := FakeWorld.new()
	root.add_child(world)
	world.add_child(world.player)
	var host := ProbeField.new()
	world.field_map = host
	var prior: ProbeRenderer = _fixture(world)
	var expected: Dictionary = CONTROLLER.renderer_signature(prior)
	var controller = CONTROLLER.new()
	controller.set("_world_ref", weakref(world))
	var source := OriginalPlayableField.new()
	var view: ProbeRenderer = _enter(controller, world, host, source)
	check(controller.get("_prior") == null and prior.get_parent() == null and prior.is_queued_for_deletion(), "entering 523 releases the hidden prior renderer")
	check(world.field_renderer == view and view.get_parent() == world, "the active 523 view stays published")
	await process_frame
	check(not is_instance_valid(prior), "the released renderer is actually freed")
	check(world.factory_calls == 0, "release builds nothing")
	# Save during 523: the host snapshot is written with its own field; nothing
	# in the save path needs a host renderer.
	check(_save(controller, world, options) == OK and world.saves.size() == 1, "save during 523 still commits")
	check(world.saves[0].field == host and world.saves[0].renderer == null, "save swaps to the host field with the released renderer")
	check(world.field_map == source and world.field_renderer == view, "save restores the active source field and view")
	DirAccess.remove_absolute(OPTIONS.PATH)
	world.saved_mode = "twilight" # changed while in 523; the prior's own mode wins as before
	check(controller.close(false), "return closes the source field")
	var rebuilt: Variant = world.field_renderer
	check(rebuilt is ProbeRenderer and world.factory_calls == 1, "return rebuilds through the world factory")
	if rebuilt is ProbeRenderer:
		var now: Dictionary = CONTROLLER.renderer_signature(rebuilt)
		for key: String in ["script","name","index","visible","process_mode","visual_mode","png_review_active","debug_collision"]:
			check(now[key] == expected[key], "rebuilt renderer keeps " + key + ": " + str(now[key]) + " vs " + str(expected[key]))
		check(rebuilt.field == host and rebuilt.refreshes >= 1, "rebuilt renderer is configured on the host field and refreshed")
	check(world.field_map == host and controller.get("_prior") == null and (controller.get("_prior_released") as Dictionary).is_empty(), "host field restored and no stale record")
	var report: Dictionary = controller.get("prior_renderer_report")
	check(report.get("rebuilt") == true and (report.get("mismatch") as Array).is_empty(), "rebuild report: equivalent")
	# --- factory failure: no renderer now, the existing map reopen later ---
	var failing := CONTROLLER.new()
	failing.set("_world_ref", weakref(world))
	world.factory_abort = true
	_enter(failing, world, host, OriginalPlayableField.new())
	check(failing.close(false) and world.field_renderer == null, "failed rebuild leaves no half-built renderer")
	await process_frame
	check(world.set_map_calls == [["aden_world", true]], "failed rebuild reopens the current map once: " + str(world.set_map_calls))
	# --- a caller that discards the map anyway (map change, exit) skips it ---
	world.factory_abort = false; world.set_map_calls.clear()
	var discard := ProbeRenderer.new(); world.add_child(discard); world.field_renderer = discard
	var skipped := CONTROLLER.new()
	skipped.set("_world_ref", weakref(world))
	_enter(skipped, world, host, OriginalPlayableField.new())
	var calls: int = world.factory_calls
	world.current523_prior_rebuild_suppressed = true
	check(skipped.close(false) and world.field_renderer == null and world.factory_calls == calls, "suppressed return does not rebuild")
	world.current523_prior_rebuild_suppressed = false
	await process_frame
	check(world.set_map_calls.is_empty(), "suppressed return leaves the map change to its caller")
	# --- flag off: the old retained renderer, exactly as before ---
	var kept := ProbeRenderer.new(); kept.name = "Kept"; world.add_child(kept); world.field_renderer = kept
	var old := CONTROLLER.new()
	old.set("_world_ref", weakref(world))
	old.set("release_prior_renderer", false)
	calls = world.factory_calls
	_enter(old, world, host, OriginalPlayableField.new())
	check(old.get("_prior") == kept and kept.get_parent() == world and not kept.visible and kept.process_mode == Node.PROCESS_MODE_DISABLED, "flag off keeps the hidden prior renderer")
	world.saves.clear()
	check(_save(old, world, options) == OK and world.saves[0].renderer == kept, "flag off save swaps to the retained renderer")
	DirAccess.remove_absolute(OPTIONS.PATH)
	check(old.close(false) and world.field_renderer == kept and kept.visible and kept.process_mode == Node.PROCESS_MODE_INHERIT, "flag off return restores the same instance")
	check(world.factory_calls == calls, "flag off never rebuilds")
	world.queue_free()
	await process_frame
	print("CURRENT523_PRIOR_RENDERER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)

## The real factory is `_set_map`'s, unchanged, and release follows every
## fallible step of `_open_source`.
func _contract() -> void:
	var world_text: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	var set_map: String = _body(world_text, "func _set_map(")
	check(set_map.contains("_new_field_renderer(field_map)") and set_map.contains("_mount_field_renderer(field_renderer, field_map)"), "_set_map uses the shared renderer factory")
	var factory: String = _body(world_text, "func _new_field_renderer(")
	var order: Array[String] = ["base508_source_test", "field is NativePngField", "CURRENT523_HOST.is_host(field)", "source_map84", "field is RemakePlayableField", "field is AuthoredRemakeField", "SOURCE_RENDERER.new() if field is OriginalPlayableField else FIELD_RENDERER.new()"]
	var at: int = -1
	for marker: String in order:
		var found: int = factory.find(marker)
		check(found > at, "factory keeps branch order: " + marker)
		at = maxi(found, at)
	var text: String = FileAccess.get_file_as_string("res://scripts/maps/current523_aden_play_controller.gd")
	var open: String = _body(text, "func _open_source(")
	var release: int = open.find("_release_prior_renderer(world)")
	check(release > open.rfind("return false") and open.find("return true") > release and open.count("return true") == 1, "release is the last step before the only success return")

func _body(text: String, header: String) -> String:
	var start: int = text.find(header)
	if start < 0: return ""
	var finish: int = text.length()
	for next: String in ["\nfunc ", "\nstatic func "]:
		var found: int = text.find(next, start + header.length())
		if found > 0: finish = mini(finish, found)
	return text.substr(start, finish - start)
