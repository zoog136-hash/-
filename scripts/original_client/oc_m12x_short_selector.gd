extends RefCounted
## M123 short selector input arbitration and option writer (C12, C15, C16, C20; F123, corrected_v2).
## DESIGN_NOT_RECOVERED_API.
## Local C6 consumer 022046F0: GlobalData+132 (virtual_pad_use_select) == 0 -> facing-turn request
## with a 300 ms unsigned deadline; != 0 -> target list arbitration by AutoPlay and the stored LOW32
## target count (a count, not a category). Rotation 01C07070 is NOT a reset. Option writer
## 0195A6F0..0195A806 (three chained pdata pieces 57/125/96 bytes) separates the initial kind (row /
## widget choice) from the CURRENT kind re-read after callbacks (stored field and hasbit).
## A sender call is not transport or server acceptance. Nothing is rolled back.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const DEADLINE_STEP_MS := 300
const PACKET_DIRECTION := 0x77
const SELECTOR_AUTO := 3
const SELECTOR_MANUAL := 0x3D
const WRITER_PIECES := [[0x0195A6F0, 0x0195A729], [0x0195A729, 0x0195A7A6], [0x0195A7A6, 0x0195A806]]
const EVIDENCE := {"arbitration": C.EVIDENCE_CONFIRMED, "selector_predicates_M46": C.EVIDENCE_CONDITIONAL, "transport_clock_actor": C.EVIDENCE_UNKNOWN}

## M51 selector touch contract (inherited): phase2/armed=false -> local C6; phase2 armed or phase3 -> C5.
static func touch_route(phase: int, armed: bool) -> String:
	if phase == 2:
		return "C5" if armed else "C6"
	if phase == 3:
		return "C5"
	return "other"

## 02089320: world+20 in {1,2} blocks.
static func entry_allowed(player: Variant, world20: int) -> bool:
	return player != null and world20 != 1 and world20 != 2

static func next_direction(facing_byte: int) -> int:
	return C.rem_trunc(C.i32(C.i8(facing_byte) + 1), 8)

## actor motion check (01CA2450 / 01C8F130): table/key miss -> false.
static func motion_is(actor: Variant, value: int) -> bool:
	return actor != null and actor.get("motion") != null and int(actor.motion) == value

static func coord_equal(actor: Variant) -> bool:
	return actor != null and actor.get("coord148") == actor.get("coord150")

static func current_player(env: Dictionary) -> Variant:
	if env.hooks.has("player_read"):
		(env.hooks.player_read as Callable).call(env)
	return env.player

## env: {"player", "world20", "global": {"byte132","byte133","hasbits10","saves"}, "receiver": {"deadline"},
## "now": int (u64 pattern), "manager": {...}, "auto_owner": {"byte18": bool}, "actors": {id: actor},
## "selector": Callable(exclusion, flag, type)->{"list": []}, "trace": [], "requests": [], "hooks": {}}
static func on_local_c6(env: Dictionary) -> String:
	var trace: Array = env.trace
	if env.player == null:
		return "no-player"
	if not entry_allowed(env.player, int(env.world20)):
		return "world-blocked"
	if int(env.global.byte132) == 0:
		return facing_branch(env)
	return target_branch(env)

static func facing_branch(env: Dictionary) -> String:
	var trace: Array = env.trace
	trace.append("walking")
	if motion_is(current_player(env), 1):
		return "stop-walking"
	trace.append("coordinate1")
	if not coord_equal(current_player(env)):
		return "stop-coordinate1"
	var p: Variant = current_player(env)
	trace.append("facing-read")
	var facing: int = C.i8(int(p.facing125))
	trace.append("coordinate2")
	if not coord_equal(p):  # second call on the SAME p
		return "stop-coordinate2"
	trace.append("motion4")
	if not motion_is(current_player(env), 4):
		return "stop-motion4"
	var now: int = int(env.now)
	if C.u64_gt(int(env.receiver.deadline), now):  # unsigned; equality proceeds
		return "throttled"
	env.receiver["deadline"] = C.u64_add(now, DEADLINE_STEP_MS)  # stored BEFORE the packet
	var next: int = C.rem_trunc(C.i32(facing + 1), 8)
	if bool(env.hooks.get("packet_preparation_fails", false)):
		return "preparation-failed-deadline-kept"
	(env.requests as Array).append({"packet": PACKET_DIRECTION, "direction": next})
	return "direction-requested"

## Manager list: Array of LUID dicts {"id","type24","control"}; "size64" overrides the stored size
## to exercise the low32 read.
static func list_count_low32(manager: Dictionary) -> int:
	var size64: int = int(manager.get("size64", (manager.list as Array).size()))
	return size64 & 0xFFFFFFFF

static func resolve(env: Dictionary, luid: Variant) -> Variant:
	if luid == null:
		return null
	return (env.actors as Dictionary).get(luid.id)

static func front_actor(env: Dictionary) -> Variant:
	var manager: Dictionary = env.manager
	if list_count_low32(manager) == 0 or (manager.list as Array).is_empty():
		return null
	return resolve(env, manager.list[0])

## 021E9100 == 021E56E0 after relocation normalisation.
static func build_exclusion(env: Dictionary, n: int) -> Dictionary:
	(env.trace as Array).append("input-create")
	if C.u32(n) > 1:
		return {"list": [], "temp_counts": null}
	var actor: Variant = front_actor(env)  # live re-resolve, not the caller's n
	if actor == null:
		return {"list": [], "temp_counts": null}
	var pair: Dictionary = actor.luid
	C.retain(pair.control)  # 006B3880 temporary shared copy
	C.retain(pair.control)  # list node copy 01C04690
	var with_temp: int = int(pair.control.strong) if pair.control != null else 0
	C.release_local(pair.control)  # temporary destroyed 006B5A50
	var after: int = int(pair.control.strong) if pair.control != null else 0
	return {"list": [pair], "temp_counts": [with_temp, after]}

## Normal cleanup of an input list: per node strong decrement (vslot0/vslot8 on last), sized delete,
## then the sentinel.
static func destroy_list(list: Array, events: Array) -> void:
	for pair: Dictionary in list:
		var cb: Variant = pair.get("control")
		if cb != null:
			var before: int = (cb.events as Array).size()
			C.release_local(cb)
			events.append_array((cb.events as Array).slice(before))
		events.append("delete-node")
	events.append("delete-sentinel")

static func targetable(env: Dictionary, luid: Variant) -> bool:
	var actor: Variant = resolve(env, luid)
	if actor == null:
		return false
	if int(actor.luid.type24) == 3:
		return true
	var od: Variant = actor.get("object_data")
	if od == null:
		(env.trace as Array).append("diagnostic-import")
		return false
	return bool(od.v20)

static func target_branch(env: Dictionary) -> String:
	var trace: Array = env.trace
	var manager: Dictionary = env.manager
	var n: int = list_count_low32(manager)
	var auto: bool = bool(env.auto_owner.byte18)
	var outcome: String = ""
	if auto:
		if n == 0:
			return "none"
		var excl: Dictionary = build_exclusion(env, n)
		if not (excl.list as Array).is_empty():
			trace.append("select:3")
			outcome = "search"
			var desc: Dictionary = (env.selector as Callable).call(excl.list, false, SELECTOR_AUTO)
			if not (desc.list as Array).is_empty():
				trace.append("clear-call")
				manager["current"] = null
				trace.append("apply-call")
				env["applied"] = desc.list  # return value ignored
				trace.append("temporary-front-targetable")
				if targetable(env, desc.list[0]):
					trace.append("choose-call")
				trace.append("descriptor-destroy")
			else:
				trace.append("descriptor-destroy")
				trace.append("rotate-call")
				rotate(env)
		else:
			outcome = "rotate"
			trace.append("rotate-call")
			rotate(env)
		trace.append("input-destroy")
		return outcome
	if n == 0:
		trace.append("input-create")
		trace.append("select:61")
		var d0: Dictionary = (env.selector as Callable).call([], false, SELECTOR_MANUAL)
		trace.append("apply-call")  # no candidate-count guard
		env["applied"] = d0.list
		env["last_exclusion"] = []
		trace.append("descriptor-destroy")
		trace.append("input-destroy")
		return "search"
	var ex: Dictionary = build_exclusion(env, n)
	env["last_exclusion"] = ex.list
	if not (ex.list as Array).is_empty():
		trace.append("select:61")
		var d1: Dictionary = (env.selector as Callable).call(ex.list, false, SELECTOR_MANUAL)
		trace.append("apply-call")
		env["applied"] = d1.list
		trace.append("descriptor-destroy")
		outcome = "search"
	else:
		trace.append("rotate-call")
		rotate(env)
		outcome = "rotate"
	trace.append("input-destroy")
	return outcome

## 01C07070. manager: {"list", "gate": bool, "current": luid|null}. hooks.append_fails simulates an
## allocation failure AFTER deselection/front removal (partial state, no transaction).
static func rotate(env: Dictionary) -> Dictionary:
	var manager: Dictionary = env.manager
	var calls: Array = []
	env["rotate_calls"] = calls
	if not bool(manager.get("gate", true)):
		return {"rotated": false, "calls": calls}
	if C.u32(list_count_low32(manager)) <= 1:
		return {"rotated": false, "calls": calls}
	var cur: Variant = manager.get("current")
	var had_current: bool = cur != null and bool(cur.get("nonempty", true))
	if had_current:
		calls.append("deselect")
		manager["current"] = null
	var saved: Dictionary = manager.list[0]
	C.retain(saved.get("control"))
	(manager.list as Array).remove_at(0)
	if bool(env.hooks.get("append_fails", false)):
		calls.append("allocation-failure")
		return {"rotated": false, "calls": calls, "partial": true}
	(manager.list as Array).append(saved)
	var auto_now: bool = bool(env.auto_owner.byte18)  # re-read
	var front_type: int = int(manager.list[0].type24)
	if not (auto_now and (front_type == 2 or front_type == 7)):
		if had_current:
			calls.append("choose")
	calls.append("refresh")
	C.release_local(saved.get("control"))
	return {"rotated": true, "calls": calls}

## ---------------- option writer 0195A6F0 ----------------

## capture: {"page": page, "kind": int (capture+10)}; page: {"byte171","byte170","slots": {0xA0, 0x130},
## "widgets": {0x88, 0x118}}; hooks: row_update(capture,row), widget_set(capture,widget,value).
static func option_writer(capture: Dictionary, input_byte: int, env: Dictionary) -> Dictionary:
	var page: Dictionary = capture.page
	var hooks: Dictionary = env.get("hooks", {})
	if bool(page.get("byte171", false)) or bool(page.get("byte170", false)):
		return {"returned_early": true}
	var initial_kind: int = C.i32(int(capture.kind))  # 0195A733, before any callback
	var slot_address: int = 0xA0 if initial_kind == 0 else 0x130
	var row_index: int = C.i32(int(page.slots[slot_address]))
	var row_read: Variant = null
	if row_index != -1:
		row_read = row_index
		page.slots[slot_address] = -1
		if hooks.has("row_update"):
			(hooks.row_update as Callable).call(capture, row_index)  # may change capture/page
	var widget_address: int = 0x88 if initial_kind == 0 else 0x118
	var widget: Variant = page.widgets.get(widget_address)  # read after the row update
	if widget != null:
		if hooks.has("widget_set"):
			(hooks.widget_set as Callable).call(capture, widget, input_byte == 0)
	var g: Dictionary = env.global
	var current_kind: int = C.i32(int(capture.kind))  # 0195A7C2, live re-read
	var bit: int = 25 if current_kind == 0 else 24
	var field: int = 0x133 if current_kind == 0 else 0x132
	g["hasbits10"] = int(g.get("hasbits10", 0)) | (1 << bit)
	g["byte%x" % field] = input_byte
	g["saves"] = int(g.get("saves", 0)) + 1  # save result discarded, no rollback
	return {"tuple": [slot_address, row_read, int(page.slots[slot_address]), widget_address, widget, field, bit]}
