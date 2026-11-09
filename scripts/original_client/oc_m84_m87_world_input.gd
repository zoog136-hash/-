extends RefCounted
## M84 (C10/C13) world visibility producers, M85 (C10/C15) nonzero-range path caller,
## M86 (C09/C13) actor cleanup partial order, M87 (C12) focus-loss input release.
## DESIGN_NOT_RECOVERED_API. Requests and orders only; no OS delivery or lifetime is claimed.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")

# ---------------------------------------------------------------- M84
const KEY_LAYOUT := "LayoutManager"
const KEY_POWER := "PowerSavingModeSystem"
const KEY_APP := "AppDelegate"

## RenderSkipManager update 01FF49C0: writes the byte (0 is a retained value, not erase or
## decrement) and visible = no entry whose byte is exactly 1.
static func skip_update(skip_map: Dictionary, key: String, value: int) -> Dictionary:
	var m: Dictionary = skip_map.duplicate()
	m[key] = value & 0xFF
	var visible := true
	for k: String in m:
		if int(m[k]) == 1:
			visible = false
	return {"map": m, "visible": visible}

## PowerSavingModeSystem 01FBB3D0 (set) / 01FBC040 (clear). Exact-1 / exact-0 skip with force 0.
static func power_set(owner: Dictionary, force: int, skip_map: Dictionary) -> Dictionary:
	var o: Dictionary = owner.duplicate()
	if int(o.byte31) == 1 and force == 0:
		return {"owner": o, "skipped": true, "events": [], "map": skip_map}
	o["byte31"] = 1
	var upd: Dictionary = skip_update(skip_map, KEY_POWER, 1)
	return {"owner": o, "skipped": false, "map": upd.map, "visible": upd.visible,
		"events": ["byte31=1", "01FEE340", "update(PowerSavingModeSystem,1)", "01FF5290(0)", "event463"]}

static func power_clear(owner: Dictionary, force: int, skip_map: Dictionary) -> Dictionary:
	var o: Dictionary = owner.duplicate()
	if int(o.byte31) == 0 and force == 0:
		return {"owner": o, "skipped": true, "events": [], "map": skip_map}
	o["byte31"] = 0
	o["byte51"] = 0
	var upd: Dictionary = skip_update(skip_map, KEY_POWER, 0)
	return {"owner": o, "skipped": false, "map": upd.map, "visible": upd.visible,
		"events": ["byte31=0", "byte51=0", "01FEE340", "update(PowerSavingModeSystem,0)", "01FF5290(1)", "event464"]}

## AppDelegate gate 00F151F0: two SEPARATE calls of 01C4AF10, whose domain is exactly 0/4.
## `first_ok` / `second_ok` are the three-lookup results of each call. The 5 compare never hits.
static func app_gate(first_ok: bool, second_ok: bool) -> Dictionary:
	var first: int = (1 if first_ok else 0) << 2
	if first == 4:
		return {"gate": true, "calls": 1}
	var second: int = (1 if second_ok else 0) << 2
	return {"gate": second == 5, "calls": 2, "second_value": second}

static func app_slot(slot: String, gate: bool, skip_map: Dictionary) -> Dictionary:
	if gate:
		return {"events": [], "map": skip_map}
	var value: int = 1 if slot == "+10" else 0
	var upd: Dictionary = skip_update(skip_map, KEY_APP, value)
	var ev: Array = (["event2EE", "self68_store", "update(AppDelegate,1)"] if value == 1 else ["event2EF", "update(AppDelegate,0)"])
	return {"events": ev, "map": upd.map, "visible": upd.visible}

## LayoutManager 01C19F20. show!=0: A (publish 93D), then C, then B (set). show==0: only the
## bound pure B membership (A/C not re-applied). Typed-cast failure does nothing.
static func layout_event(cast_ok: bool, layout_name: String, show: int, groups: Dictionary, skip_map: Dictionary) -> Dictionary:
	var ev: Array = []
	if not cast_ok:
		return {"events": ev, "map": skip_map}
	var m: Dictionary = skip_map
	if show != 0:
		if layout_name in groups.A:
			ev.append_array(["hide_peers(A)", "publish093D"])
		elif layout_name in groups.C:
			ev.append("hide_peers(C)")
		elif layout_name in groups.B:
			ev.append("hide_peers(B)")
			m = skip_update(skip_map, KEY_LAYOUT, 1).map
			ev.append("update(LayoutManager,1)")
	else:
		if layout_name in groups.B:
			m = skip_update(skip_map, KEY_LAYOUT, 0).map
			ev.append("update(LayoutManager,0)")
	return {"events": ev, "map": m}

## DLL 0030EB5C: exact focused==1 picks the focused name; everything else unfocused. No
## AppDelegate slot is dispatched from this body.
static func glfw_focus_event_name(focused: int) -> String:
	return "glview_window_focused" if focused == 1 else "glview_window_unfocused"

# ---------------------------------------------------------------- M85
## 01F5E8D0 caller arguments (new direct-site connection).
static func caller_01F5E8D0(source_type_dword: int) -> Dictionary:
	return {"range": 2 if V.u32(source_type_dword) == 4 else 1, "rayAllow40": 0, "callbackMode": 0, "distanceOnly": 0, "callback": "01F84C00"}

## The returned AL is discarded; the next gate (01F5E8D8) is unsigned QWORD local list size >= 2.
static func caller_next_gate(_returned_al: bool, local_list_size: int) -> bool:
	return local_list_size < 0 or local_list_size >= 2  # unsigned compare: a negative QWORD is huge

## 01C0E470 callers: categories 2/5 use range1/ray0/01C0B8D0, others range from 022006C0,
## ray1, 01C0B7D0. callbackMode = category in {5,12,32,42} (mask 0x40100001020, unsigned <=42).
static func caller_01C0E470(category: int, range_from_022006C0: int) -> Dictionary:
	var mode: int = 0
	if V.u32(category) <= 42 and ((0x40100001020 >> category) & 1) == 1:
		mode = 1
	if category == 2 or category == 5:
		return {"range": 1, "rayAllow40": 0, "callback": "01C0B8D0", "callbackMode": mode, "distanceOnly": 0}
	return {"range": V.i32(range_from_022006C0), "rayAllow40": 1, "callback": "01C0B7D0", "callbackMode": mode, "distanceOnly": 0}

## abs32 by NEG then CMOVS: INT_MIN stays INT_MIN.
static func abs32(v: int) -> int:
	var x: int = V.i32(v)
	var n: int = V.i32(-x)
	return x if n < 0 else n

## A := signed max(sar(abs32(low32(dx)),1), abs32(low32(dy))) <= signed R
static func distance_predicate(candidate: Vector2i, target: Vector2i, r: int) -> bool:
	var ax: int = abs32(candidate.x - target.x) >> 1
	var ay: int = abs32(candidate.y - target.y)
	return maxi(ax, ay) <= V.i32(r)

## budget = low32(sar(low32(x - signmask(x)),1) + 8), x = low32(range*8)
static func accept_budget(path_range: int) -> int:
	var x: int = V.i32(path_range * 8)
	var signmask: int = -1 if x < 0 else 0
	return V.i32(V.sar32(V.i32(x - signmask), 1) + 8)

## Search prologue. distanceOnly is deliberately not consulted for the initial H test.
static func search_prologue(start: Vector2i, target: Vector2i, path_range: int, h_result: bool) -> Dictionary:
	if start == target:
		return {"returned": true, "output_added": false, "reason": "same packed coordinate"}
	if V.i32(path_range) > 0 and h_result:
		return {"returned": true, "output_added": false, "reason": "initial H accepted"}
	return {"returned": false, "searches": true}

# ---------------------------------------------------------------- M86
const CLEANUP_EDGES := [
	["019374C9", "01937500"],
	["current_global_null", "current_shutdown"], ["current_shutdown", "current_delete"],
	["current_delete", "pending_global_null"], ["pending_global_null", "pending_observer_unregister"],
	["pending_observer_unregister", "pending_packet_release"], ["pending_packet_release", "pending_root_free"],
	["weak_oid_clear", "vector08_clear"], ["vector08_clear", "vector20_clear"], ["vector20_clear", "vector38_clear"],
	["vector38_clear", "inactive_trim"]]
const ACTOR_OWNERS := ["current+08", "current+20", "current+38"]
const NOT_ACTOR_OWNERS := {"pending packet tree": "shared ENTER packet", "pending embedded raw observer": "raw", "current OID weak tree": "weak"}

## Normal-progress trace of 01937500. `abort_after` names the last event that completed before
## a throw/abort/reentrancy stop: everything later is absent (a prefix, never reordered).
static func cleanup_trace(current_present: bool, pending_present: bool, abort_after: String = "") -> Array:
	var seq: Array = []
	if current_present:
		seq.append_array(["current_global_null", "registry_remove(current)", "current_shutdown", "weak_oid_clear", "vector08_clear", "vector20_clear", "vector38_clear", "inactive_trim", "current_delete"])
	if pending_present:
		seq.append_array(["pending_global_null", "registry_remove(pending)", "pending_observer_unregister", "pending_packet_release", "pending_root_free"])
	if abort_after.is_empty():
		return seq
	var cut: int = seq.find(abort_after)
	return seq if cut < 0 else seq.slice(0, cut + 1)

## Relative order from the recorded local edges only. Anything not connected (pool shutdown,
## registry 03522750, scheduler snapshot) is UNKNOWN; the DESIGN does not invent a slot.
static func relative_order(a: String, b: String) -> String:
	if _reaches(a, b):
		return "BEFORE"
	if _reaches(b, a):
		return "AFTER"
	return V.UNKNOWN

static func _reaches(a: String, b: String) -> bool:
	var frontier: Array = [a]
	var seen := {}
	var inner := {"current_shutdown": ["weak_oid_clear"], "inactive_trim": ["current_delete"]}
	while not frontier.is_empty():
		var n: String = frontier.pop_back()
		if seen.has(n):
			continue
		seen[n] = true
		var nexts: Array = []
		for e: Array in CLEANUP_EDGES:
			if e[0] == n:
				nexts.append(e[1])
		nexts.append_array(inner.get(n, []))
		for x: String in nexts:
			if x == b:
				return true
			frontier.append(x)
	return false

# ---------------------------------------------------------------- M87
const KEY_LAST := 348
const MOUSE_LAST := 7

static func make_window() -> Dictionary:
	var keys: Array = []
	keys.resize(KEY_LAST + 1)
	keys.fill(0)
	var mouse: Array = []
	mouse.resize(MOUSE_LAST + 1)
	mouse.fill(0)
	return {"key": keys, "mouse": mouse, "sticky_key": 0, "sticky_mouse": 0, "flag78": 0, "log": []}

## D004DF810. The focus callback runs FIRST. When focused==0, keys 0..348 then mouse 0..7 are
## released only when the CURRENT byte (live load each iteration, no snapshot) is exactly 1.
## Release writes sticky?3:0 BEFORE the user callback, and the callback still gets action 0.
## Callables: focus_cb(window, focused); key_cb(window, key, action, mods); mouse_cb(window, b, action, mods)
static func focus_changed(window: Dictionary, focused: int, focus_cb: Callable, key_cb: Callable, mouse_cb: Callable) -> Dictionary:
	if focus_cb.is_valid():
		focus_cb.call(window, focused)
	(window.log as Array).append("custom:" + glfw_focus_event_name(focused))
	if focused != 0:
		return window
	for key: int in KEY_LAST + 1:
		if (window.key as Array)[key] == 1:
			(window.key as Array)[key] = 3 if int(window.sticky_key) != 0 else 0
			var mods: int = 0  # mods0 is 0 under both flag78 branches (mask 0xFFFFFFCF)
			(window.log as Array).append("key_release:%d" % key)
			if key_cb.is_valid():
				key_cb.call(window, key, 0, mods)
	for b: int in MOUSE_LAST + 1:
		if (window.mouse as Array)[b] == 1:
			(window.mouse as Array)[b] = 3 if int(window.sticky_mouse) != 0 else 0
			(window.log as Array).append("mouse_release:%d" % b)
			if mouse_cb.is_valid():
				mouse_cb.call(window, b, 0, 0)
	return window

## Conditional game keyboard consumer E00CA8060 for a release: blocked directional release keeps
## the held vector (no other clear is implied).
static func game_key_release(held: Array, mapped_key: int, block30: bool, block31: bool) -> Dictionary:
	var h: Array = held.duplicate()
	if (block30 or block31) and mapped_key != 6:
		return {"held": h, "event": null}
	if mapped_key >= 26 and mapped_key <= 29:
		var i: int = h.find(mapped_key)
		if i >= 0:
			h.remove_at(i)
		return {"held": h, "event": "C5" if h.is_empty() else "C4"}
	return {"held": h, "event": "nonmovement_branch_not_modelled"}
