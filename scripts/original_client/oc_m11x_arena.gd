extends RefCounted
## M114 (C10, C11, C13; F114) Arena fog 0x424/0x425 -> StatusEffectScreenLayout receivers and
## M116 (C04, C10; F116) Arena mode selection / physical keys. DESIGN_NOT_RECOVERED_API.
## The ordinary 0x422 group/speed/top policy is NOT used here. Map keys are signed int32 ids.
## layout: {"map60": {id: action|null}, "map70": {id: timer|null}, "map80": {id: timer|null},
##          "parent50": {"children": []}, "events": [], "trace": []}
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const EVENT_FOG_SHOW := 0x424
const EVENT_FOG_REMOVE := 0x425
const EVENT_FIRST_EFFECT := 0x297
const ARENA_CONSTANT_FOG := 562
const ARENA_CONSTANT_MODE_CANDIDATE := 42
const ARENA_TYPE_FOG := 12
const M114_EVIDENCE := {"routing": C.EVIDENCE_CONFIRMED, "renderer": C.EVIDENCE_UNKNOWN, "scheduler_time_unit": C.EVIDENCE_CONDITIONAL}
const M116_EVIDENCE := {"selection": C.EVIDENCE_CONFIRMED, "type12_value2352": C.EVIDENCE_CONDITIONAL}

static func make_layout() -> Dictionary:
	return {"record": "StatusEffectScreenLayout", "design_status": C.DESIGN, "map60": {}, "map70": {}, "map80": {},
		"parent50": {"children": []}, "events": [], "trace": [], "timers": []}

## ---------------- M114 receivers ----------------

static func parse_bool(map: Dictionary, key: String, default_value: bool) -> bool:
	var v: Variant = map.get(key)
	return bool(v) if v is bool else default_value

## capture: {"layout": layout} - the capture holds the layout pointer and is re-read (*capture).
## env: {"rows": {id: ScreenEffect row}, "config": {...}, "hooks": {...}}
static func receive_424(capture: Dictionary, event_map: Dictionary, env: Dictionary) -> void:
	var id: int = C.typed_int_or_zero(event_map, "id")
	var is_new: bool = parse_bool(event_map, "is_new", true)
	if id == 0:
		return  # separate id0 gate; negative ids are still looked up
	var row: Variant = (env.rows as Dictionary).get(id)
	(capture.layout.trace as Array).append(["lookup", id])
	if row == null:
		return
	var delay: int = C.i32(int(row.EffectDelay))
	var layout: Dictionary = capture.layout  # fresh read after lookup
	if delay > 0:
		var fn := {"layout": layout, "id": id, "is_new": is_new}
		var timer := {"record": "DelayTimer", "delay": delay, "fn": fn}
		(layout.timers as Array).append(timer)
		var slot_layout: Dictionary = capture.layout  # reread after the scheduler
		slot_layout.map70[id] = timer  # inserts the slot if absent; replacement releases the old one
		(layout.trace as Array).append(["timer", id, is_new, delay])
	else:
		display(layout, id, is_new, env)

## 02A41270: delayed callback. Display, then reread fn.layout/fn.id and RESET map70[id] (insert if
## absent; no generation/identity comparison -> clears whatever is current, NOT erase).
static func fire_delay_timer(timer: Dictionary, env: Dictionary) -> void:
	var fn: Dictionary = timer.fn
	display(fn.layout, int(fn.id), bool(fn.is_new), env)
	fn.layout.map70[int(fn.id)] = null

static func receive_425(capture: Dictionary, event_map: Dictionary, env: Dictionary) -> void:
	var id: int = C.typed_int_or_zero(event_map, "id")
	var soft: bool = parse_bool(event_map, "soft", false)
	if id == 0:
		return
	capture.layout.map70[id] = null  # reset-or-insert, keys are not erased
	(capture.layout.trace as Array).append(["reset70", id])
	capture.layout.map80[id] = null  # reread after the first release
	(capture.layout.trace as Array).append(["reset80", id])
	remove(capture.layout, id, soft, env)  # proceeds even if map60 then misses

## 02A2C6F0 local display policy. hooks: node_factory(asset)->node|null, path(asset)->String,
## after_attach(layout,id) (re-entry point before the second map60 check), before_insert(layout,id).
static func display(layout: Dictionary, id: int, is_new: bool, env: Dictionary) -> void:
	var hooks: Dictionary = env.get("hooks", {})
	var trace: Array = layout.trace
	if (layout.map60 as Dictionary).has(id):
		trace.append(["display-skip-existing", id])  # includes an existing NULL value
		return
	var row: Variant = (env.rows as Dictionary).get(id)
	if row == null:
		return
	var asset: int = int(row.EffectAssetId)
	var node: Variant = (hooks.node_factory as Callable).call(asset) if hooks.has("node_factory") else {"asset": asset}
	if node == null:
		return
	(layout.parent50.children as Array).append(node)  # attach BEFORE the path guard
	trace.append(["attach", id])
	trace.append(["flash-callable", "//Nd_Flash"])
	var path: String = (hooks.path as Callable).call(asset) if hooks.has("path") else "path/%d" % asset
	if C.i32(int(row.ShakeDuration)) > 0 and is_new:
		if C.i32(int(row.ShakeDelay)) > 0:
			layout.map80[id] = {"record": "ShakeTimer", "delay": int(row.ShakeDelay)}
			trace.append(["shake-timer", id])
		else:
			trace.append(["shake-now", id])
	if path.is_empty():
		trace.append(["path-empty-return", id])  # node stays attached, no insert, no 0x297
		return
	if hooks.has("after_attach"):
		(hooks.after_attach as Callable).call(layout, id)
	if not (layout.map60 as Dictionary).has(id):
		var anim: String = str(row.AnimationName)
		var config: Dictionary = env.get("config", {})
		var special: bool = not anim.is_empty() and anim == str(config.get("SCREENEFFECT_START_ON_ANIM", ""))
		var action := {"record": "ScreenAction", "id": id, "node": node, "anim": anim, "started": false, "loop_name": null}
		if special:
			if is_new:
				action["completion_installed"] = true
				action["started"] = true
			else:
				var loop_name: String = str(config.get("SCREENEFFECT_START_LOOP_ANIM", ""))
				if (row.get("available_animations", []) as Array).has(loop_name):
					action["loop_name"] = loop_name
		else:
			action["started"] = true  # is_new does not gate this branch
		trace.append(["action", id, special, action.started])
		if hooks.has("before_insert"):
			(hooks.before_insert as Callable).call(layout, id)
		if not (layout.map60 as Dictionary).has(id):
			layout.map60[id] = action  # unique insert; a duplicate is NOT replaced, result ignored
		else:
			trace.append(["insert-failed-no-replace", id])
	else:
		trace.append(["second-check-existing", id])
	if (layout.map60 as Dictionary).size() == 1:
		(layout.events as Array).append(EVENT_FIRST_EFFECT)

## 029FE540 narrow removal policy.
static func remove(layout: Dictionary, id: int, soft: bool, env: Dictionary) -> void:
	var hooks: Dictionary = env.get("hooks", {})
	var trace: Array = layout.trace
	if not (layout.map60 as Dictionary).has(id):
		trace.append(["remove-miss", id])
		return
	var hold: Variant = layout.map60[id]
	if hold == null:
		trace.append(["remove-null-hold", id])  # no erase, no helper, no visual call
		return
	trace.append(["action-call", id])
	var node: Variant = hold.node  # loaded AFTER that call
	(layout.map60 as Dictionary).erase(id)
	var duration: float = float((hooks.duration as Callable).call(node)) if (soft and node != null and hooks.has("duration")) else 0.0
	if soft and node != null and duration > 0.0:
		trace.append(["delay-remove-self", id, duration])
	else:
		(layout.parent50.children as Array).erase(node)
		trace.append(["remove-child-now", id])

## ---------------- Arena state publishers (00CD16A0 / 00CD1890) ----------------

static func publish_state1(arena: Dictionary, constant_rows: Array, mode_env: Dictionary) -> Variant:
	arena["state98"] = 1
	if int(arena.type90) != ARENA_TYPE_FOG:
		return null
	return {"event": EVENT_FOG_REMOVE, "map": {"id": lookup_constant(arena, constant_rows, ARENA_CONSTANT_FOG, 0, ARENA_TYPE_FOG, mode_env)}}

static func publish_state2(arena: Dictionary, constant_rows: Array, mode_env: Dictionary) -> Variant:
	arena["state98"] = 2
	if int(arena.type90) != ARENA_TYPE_FOG:
		return null
	# No callback key inside the map; the timer capture is independent.
	return {"event": EVENT_FOG_SHOW, "map": {"id": lookup_constant(arena, constant_rows, ARENA_CONSTANT_FOG, 0, ARENA_TYPE_FOG, mode_env), "is_new": true}}

## ---------------- M116 ----------------

## 01466A10: ArenaConstant physical key = [ArenaModeTypeID, ArenaConstantTypeID, ArenaTypeID].
static func constant_physical_key(message: Dictionary) -> Array:
	return [C.i32(int(message.ArenaModeTypeID)), C.i32(int(message.ArenaConstantTypeID)), C.i32(int(message.ArenaTypeID))]

## 00F15C80: ArenaModeType physical key = ID.
static func mode_physical_key(message: Dictionary) -> Array:
	return [C.i32(int(message.ID))]

## 00CD2A50 compare order: signed (row+8 ArenaType, row+4 Constant, row+0 Mode).
static func constant_compare_key(row: Dictionary) -> Array:
	var k: Array = constant_physical_key(row)
	return [k[2], k[1], k[0]]

## rows must be in valid native sorted order for this lookup (prerequisite, not checked).
static func lookup_constant(arena: Dictionary, sorted_rows: Variant, constant: int, caller_default: int, arena_type: int, mode_env: Dictionary) -> int:
	if sorted_rows == null:
		return caller_default
	var mode: int = resolve_mode(arena, arena_type, mode_env)
	var idx: int = C.lower_bound_exact(sorted_rows, constant_compare_key, [arena_type, constant, mode])
	if idx >= 0:
		return C.i32(int(sorted_rows[idx].Value))
	if mode == 0:
		return caller_default
	idx = C.lower_bound_exact(sorted_rows, constant_compare_key, [arena_type, constant, 0])
	return C.i32(int(sorted_rows[idx].Value)) if idx >= 0 else caller_default

## 00CD2FB0. arena: {"override1A8": int}. mode_env: {"mode_rows": sorted ArenaModeType rows|null,
## "constant_rows_native": ArenaConstant rows in NATIVE row order|null, "map_system": {"f0C": int},
## "hooks": {"after_mode_getter": Callable(arena)}}.
static func resolve_mode(arena: Dictionary, requested_type: int, mode_env: Dictionary) -> int:
	var hooks: Dictionary = mode_env.get("hooks", {})
	if C.i32(int(arena.get("override1A8", 0))) != 0:  # first current read
		var mt: Variant = mode_env.get("mode_rows")
		if mt != null:
			if hooks.has("after_mode_getter"):
				(hooks.after_mode_getter as Callable).call(arena)
			var stored: int = C.i32(int(arena.get("override1A8", 0)))  # fresh read AFTER the getter
			var idx: int = C.lower_bound_exact(mt, mode_physical_key, [stored])
			if idx >= 0 and C.i32(int(mt[idx].ArenaTypeID)) == C.i32(requested_type):
				return stored  # captured value, no third read
	var world: int = C.i32(int(mode_env.map_system.f0C))  # exactly ONE read
	if hooks.has("after_world_capture"):
		(hooks.after_world_capture as Callable).call(mode_env)
	var candidates: Dictionary = build_candidates(mode_env.get("constant_rows_native"), requested_type)
	var modes: Array = candidates.keys()
	modes.sort()  # signed int32 ascending
	for m: int in modes:
		if C.i32(int(candidates[m])) == world:
			return m
	return 0

## 00CD3D80: constant42 rows of the requested type in native order; same mode -> LAST row wins.
## No ArenaModeType validation; no ContentsControlID/SelectWeight/random choice.
static func build_candidates(native_rows: Variant, requested_type: int) -> Dictionary:
	var tree: Dictionary = {}
	if native_rows == null:
		return tree
	for row: Dictionary in native_rows:
		if C.i32(int(row.ArenaTypeID)) == C.i32(requested_type) and C.i32(int(row.ArenaConstantTypeID)) == ARENA_CONSTANT_MODE_CANDIDATE:
			tree[C.i32(int(row.ArenaModeTypeID))] = C.i32(int(row.Value))
	return tree

## Sort helper reproducing the native table order assumption for the 00CD2A50 lookup.
static func sort_constants(rows: Array) -> Array:
	var out: Array = rows.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return C.lex_less(constant_compare_key(a), constant_compare_key(b)))
	return out
