extends Node2D
class_name Source523TownNpcBodies
## Visible bodies of the original 523 town NPCs placed by source523_town_npcs.gd
## (field.data.npc_spawn). Pixels come only from the installed original source
## bank (the same current523 SP2 bank and shared prepared snapshots the field
## monsters use): EarthObjectClass.SpriteID, original idle action
## (ListSprAction 3) or, for sprites that declare no idle, the original
## walk action 0, facing EarthObjectSpawn.DirectionID. A sprite the bank does
## not carry leaves the NPC without a body (recorded in metrics); nothing is
## drawn, generated or substituted. Bodies are not monsters: they never join
## monsters_root, cannot be targeted or attacked, and talking still goes
## through the existing npc_spawn interaction (world_interactions / world.gd).
## Streaming: only NPCs within ACTIVE_RADIUS of the player get a body, at most
## one bank load per frame within FRAME_BUDGET_USEC; far bodies are released.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const SP2_BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const TOWN = preload("res://scripts/npc/source523_town_npcs.gd")
## Original ListSprAction rows: 3 = idle (MotionType 4), 0 = walk (MotionType 1).
## A sprite without idle stands in its first other original action
## (walk, hit, ...): TWILIGHT 근사 (user 2026-11-16 "근사치로 다 넣어").
const IDLE_ACTIONS: Array[int] = [3, 0, 2, 9, 8, 1]
const ACTIVE_RADIUS: float = 1500.0
const RELEASE_RADIUS: float = 2100.0
const FRAME_BUDGET_USEC: int = 6000
const LOADS_PER_FRAME: int = 1
const SCAN_INTERVAL: float = 0.35
const MAX_DEFERRALS: int = 40
## Same per-attempt bank budget as the current523 field population.
const ROLE_BUILDS_PER_LOAD: int = 1
const MEMBER_VERIFIES_PER_LOAD: int = 2
## Labels use the original DescData name already on the npc_spawn record.
const NAME_OFFSET := Vector2(-90, -118)

var world: Node = null
var records: Array = []
var bodies: Dictionary = {} ## npc id -> Node2D (holder with preview + label)
var missing: Dictionary = {} ## npc id -> reason (no original body)
var _deferrals: Dictionary = {}
var _queue: Array[int] = []
var _scan_clock: float = 0.0
var _action_memo: Dictionary = {} ## sprite id -> working action id, or -1
var loads: int = 0
var released: int = 0
var create_usec_total: int = 0
var create_usec_max: int = 0

func _init() -> void:
	name = "Current523TownNpcs"
	y_sort_enabled = true

func configure(controller: Node, field: Object) -> void:
	clear()
	world = controller
	records = field.data.get("npc_spawn", []) if field != null and field.get("data") is Dictionary else []
	records = records.filter(func(record: Dictionary) -> bool: return TOWN.is_town_npc_id(str(record.get("id", ""))))
	_scan_clock = 0.0

func clear() -> void:
	for holder: Node in bodies.values():
		if is_instance_valid(holder):
			remove_child(holder)
			holder.queue_free()
	bodies.clear()
	missing.clear()
	_deferrals.clear()
	_queue.clear()
	records = []

func _player_position() -> Vector2:
	if not is_instance_valid(world) or not is_instance_valid(world.get("player")): return Vector2.INF
	return world.player.global_position

static func record_position(record: Dictionary) -> Vector2:
	var p: Variant = record.get("position", [])
	return Vector2(float(p[0]), float(p[1])) if p is Array and p.size() == 2 else Vector2.INF

func _scan() -> void:
	var at: Vector2 = _player_position()
	if not at.is_finite(): return
	_queue.clear()
	var wanted: Array = []
	for index: int in records.size():
		var record: Dictionary = records[index]
		var id: String = str(record.id)
		var point: Vector2 = record_position(record)
		var distance: float = point.distance_to(at)
		if bodies.has(id):
			if distance > RELEASE_RADIUS: _release(id)
			continue
		if missing.has(id) or distance > ACTIVE_RADIUS: continue
		wanted.append([distance, index])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in wanted: _queue.append(int(entry[1]))

func _release(id: String) -> void:
	var holder: Node = bodies.get(id)
	bodies.erase(id)
	released += 1
	if is_instance_valid(holder):
		remove_child(holder)
		holder.queue_free()

func _process(delta: float) -> void:
	if records.is_empty(): return
	var started: int = HITCH.now()
	_scan_clock -= delta
	if _scan_clock <= 0.0:
		_scan_clock = SCAN_INTERVAL
		_scan()
	var frame_start: int = Time.get_ticks_usec()
	var made: int = 0
	while not _queue.is_empty() and made < LOADS_PER_FRAME and Time.get_ticks_usec() - frame_start < FRAME_BUDGET_USEC:
		var record: Dictionary = records[_queue.pop_front()]
		if bodies.has(str(record.id)) or missing.has(str(record.id)): continue
		made += 1
		var create_started: int = Time.get_ticks_usec()
		_create(record)
		var spent: int = Time.get_ticks_usec() - create_started
		create_usec_total += spent
		create_usec_max = maxi(create_usec_max, spent)
	for holder: Node2D in bodies.values():
		if is_instance_valid(holder) and holder.is_visible_in_tree():
			var preview: Node = holder.get_meta("preview") if holder.has_meta("preview") else null
			if is_instance_valid(preview): preview.advance_reference_source(delta, str(holder.get_meta("role")), int(holder.get_meta("direction")))
	HITCH.detail("town_npc_bodies", started)

func _selected(sprite_id: int, action: int, options: Dictionary) -> Dictionary:
	return {"manifest_path": str(options.manifest_path), "manifest_sha256": str(options.manifest_sha256),
		"sprite_id": sprite_id, "consumer": "npc", "role_actions": {"idle": action}, "loop_policy": {"idle": true}}

func _create(record: Dictionary) -> void:
	var id: String = str(record.id)
	var sprite_id: int = int(record.get("source523_sprite_id", 0))
	if sprite_id <= 0:
		missing[id] = "earth_object_sprite_missing"
		return
	var supplied: Dictionary = SOURCE.options()
	if not supplied.get("ok", false):
		missing[id] = "current523_source_bank_unavailable"
		return
	var options: Dictionary = supplied.options
	var actions: Array[int] = IDLE_ACTIONS.duplicate()
	if _action_memo.has(sprite_id):
		if int(_action_memo[sprite_id]) < 0:
			missing[id] = "original_sprite_action_unavailable"
			return
		actions = [int(_action_memo[sprite_id])]
	var preview := PREVIEW.new()
	var configured: bool = false
	var problem: String = ""
	loads += 1
	for action: int in actions:
		SP2_BANK.role_build_budget = ROLE_BUILDS_PER_LOAD
		SP2_BANK.member_verify_budget = MEMBER_VERIFIES_PER_LOAD
		configured = preview._configure_selected_roles(_selected(sprite_id, action, options), "idle")
		SP2_BANK.role_build_budget = -1
		SP2_BANK.member_verify_budget = -1
		problem = str(preview.reference_bank_status.get("error", ""))
		if configured:
			_action_memo[sprite_id] = action
			break
		if problem == SP2_BANK.ROLE_DEFERRED:
			# The bank build continues on a later frame (same as field monsters).
			preview.free()
			_deferrals[id] = int(_deferrals.get(id, 0)) + 1
			if int(_deferrals[id]) > MAX_DEFERRALS: missing[id] = "bank_build_deferred_too_often"
			return
	if not configured:
		preview.free()
		_action_memo[sprite_id] = -1
		missing[id] = "original_sprite_action_unavailable:" + problem.left(80)
		return
	var holder := Node2D.new()
	holder.name = id.replace(":", "_")
	holder.position = record_position(record)
	holder.set_meta("source523_npc_id", id)
	holder.set_meta("source523_sprite_id", sprite_id)
	holder.set_meta("role", "idle")
	var direction: int = int(record.get("source523_direction_id", 4))
	holder.set_meta("direction", direction if direction >= 0 and direction <= 7 else 4)
	holder.set_meta("preview", preview)
	holder.add_child(preview)
	var label := Label.new()
	label.text = str(record.get("name", ""))
	label.position = NAME_OFFSET
	label.size = Vector2(180, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("dfc58a"))
	label.add_theme_color_override("font_outline_color", Color("1b241c"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 15
	holder.add_child(label)
	add_child(holder)
	if not preview.advance_reference_source(0.0, "idle", int(holder.get_meta("direction"))):
		_release(id)
		released -= 1
		missing[id] = "original_first_frame_unavailable"
		return
	bodies[id] = holder

func metrics() -> Dictionary:
	var reasons: Dictionary = {}
	for reason: Variant in missing.values():
		var key: String = str(reason).get_slice(":", 0)
		reasons[key] = int(reasons.get(key, 0)) + 1
	return {"records": records.size(), "bodies": bodies.size(), "missing": missing.size(), "missing_reasons": reasons,
		"queued": _queue.size(), "loads": loads, "released": released, "sprites_known": _action_memo.size(),
		"create_ms_total": create_usec_total / 1000.0, "create_ms_max": create_usec_max / 1000.0}
