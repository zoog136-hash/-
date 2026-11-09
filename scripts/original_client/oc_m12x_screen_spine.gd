extends RefCounted
## M122 ScreenEffect Spine display (C04, C11, C13; F122, corrected_v2). DESIGN_NOT_RECOVERED_API.
## 02F7C1D0/02F7CCA0 -> 0338A300 -> 0338AE60 -> 0338A620. JSON/atlas stem, scale 1, first animation
## on track 0 with loop=true when autoFirst (row.isLoop is NOT that flag). The selected callers do
## NOT apply UISpine OffsetX/OffsetY/Flip and have NO parent fallback for a missing target.
## A file existing is not factory success; the Spine evaluator/renderer is not modelled.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const TARGET_ALIAS := "SCREEN_EFFECT_SPINE_TARGET_NODE"
const LISTENER_COMPLETE := 3
const LISTENER_EVENT := 5
const EVIDENCE := {"loader_path": C.EVIDENCE_CONFIRMED, "factory_internals": C.EVIDENCE_UNKNOWN, "rendering": C.EVIDENCE_UNKNOWN}

## 0338A300: path field row+18; stem = path[0:last_dot] (dot search does not stop at '/').
static func stem_of(path: String) -> String:
	var dot: int = path.rfind(".")
	return path if dot < 0 else path.substr(0, dot)

## env: {"asset_rows": sorted AssetView-like rows|null, "files": {path: true}, "spine_data": {json_path: {"animations": [...]}},
##       "factory_null": bool, "trace": []}. event_fn/complete_fn: Callable or null (empty function).
static func load_by_asset(asset_id: int, auto_first: bool, event_fn: Variant, complete_fn: Variant, env: Dictionary) -> Variant:
	var trace: Array = env.trace
	var rows: Variant = env.get("asset_rows")
	if rows == null:
		trace.append("destroy-incoming-callables")
		return null
	var idx: int = C.lower_bound_exact(rows, func(r: Dictionary) -> Array: return [int(r.AssetId)], [asset_id])
	if idx < 0:
		trace.append("destroy-incoming-callables")
		return null
	var stem: String = stem_of(str(rows[idx].FilePath))
	return load_stem(stem, stem, auto_first, event_fn, complete_fn, env)

static func load_stem(json_stem: String, atlas_stem: String, auto_first: bool, event_fn: Variant, complete_fn: Variant, env: Dictionary) -> Variant:
	var trace: Array = env.trace
	var json_path: String = "Spine/" + json_stem + ".json"
	var atlas_path: String = "Spine/" + atlas_stem + ".atlas"
	trace.append(["paths", json_path, atlas_path])
	if not (env.files as Dictionary).has(json_path):
		trace.append("json-missing-null")
		return null
	if not (env.files as Dictionary).has(atlas_path):
		trace.append("atlas-missing-null")
		return null
	var data: Variant = (env.get("spine_data", {}) as Dictionary).get(json_path)
	if data == null:
		# 0352D668 dereferences parsed data without a guard after partial writes.
		trace.append("parsed-data-null")
		return {"outcome": C.UNGUARDED_BOUNDARY}
	if bool(env.get("factory_null", false)):
		trace.append("factory-null")
		return null
	var node := {"record": "SkeletonAnimation", "json": json_path, "atlas": atlas_path, "scale": 1.0, "data": data,
		"complete508": null, "event548": null, "tracks": {}, "queue_reentrancy_flag": false, "attached_to": null}
	if complete_fn != null:
		node["complete508"] = complete_fn  # owned wrapper 04521A20 only when nonempty
	node["event548"] = {"raw_node": node, "fn": event_fn}  # wrapper 04521A58 always installed
	if auto_first:
		var anims: Array = data.get("animations", [])
		if anims.is_empty():
			return {"outcome": C.UNGUARDED_BOUNDARY, "node": node}  # count>0 required, no fallback
		var first_name: String = str(anims[0])
		node.tracks[0] = {"animation": first_name, "loop": true}  # track0, loop=true; return ignored
	return node

## 0352D7E8: exact C-string name scan; miss -> log + null (no CSB name/frame mapping).
static func set_animation(node: Dictionary, track: int, anim_name: String, loop: bool) -> Variant:
	if not (node.data.get("animations", []) as Array).has(anim_name):
		return null
	node.tracks[track] = {"animation": anim_name, "loop": loop}
	return node.tracks[track]

## Selected caller. layout: {"root50": tree|null, "aliases": {...}, "trace": []}. CSB/group/timeline
## work happens BEFORE the optional Spine and is not undone by a later null skeleton/target.
static func screen_effect_spine(layout: Dictionary, row: Dictionary, uispine_rows: Dictionary, env: Dictionary) -> Dictionary:
	var trace: Array = layout.trace
	trace.append("csb-group-timeline")
	var result := {"node": null, "attached": false}
	var spine_id: int = int(row.UISpineID)
	if spine_id != 0 and uispine_rows.has(spine_id) and int(uispine_rows[spine_id].AssetID) != 0:
		var node: Variant = load_by_asset(int(uispine_rows[spine_id].AssetID), true, null, {"cleanup": "screen-cleanup"}, env)
		result["node"] = node
		if node is Dictionary and node.get("record") == "SkeletonAnimation":
			var alias: String = C.resolve_alias(layout.aliases, TARGET_ALIAS)
			var target: Variant = null
			if not alias.is_empty() and layout.root50 != null:
				target = C.dot_path(layout.root50, alias)
			if target != null:
				(target.children as Array).append(node)
				node["attached_to"] = target.name
				result["attached"] = true
			# no parent fallback; OffsetX/OffsetY/Flip not read; AnimationSpeed not -> timeScale
	trace.append("shake-audio-continue")
	return result

## Event queue 03531A14: track listener then state listener per entry, NO catch. The reentrancy
## flag is cleared only at the normal tail. listener_fn(type, entry) returns {"throw": bool}.
static func dispatch_queue(node: Dictionary, events: Array, listener_fn: Callable) -> Dictionary:
	node["queue_reentrancy_flag"] = true
	var delivered: Array = []
	for ev: Dictionary in events:
		var r: Variant = listener_fn.call(int(ev.type), ev)
		delivered.append(int(ev.type))
		if r is Dictionary and bool(r.get("throw", false)):
			return {"delivered": delivered, "aborted": true, "flag_left_set": bool(node.queue_reentrancy_flag)}
	node["queue_reentrancy_flag"] = false
	return {"delivered": delivered, "aborted": false, "flag_left_set": false}

## Event wrapper 033865E0: built-in Loop/Action handling writes the entry BEFORE invoking eventFn.
static func handle_event(entry: Dictionary, event: Variant, event_fn: Variant) -> Dictionary:
	if event == null or event.get("name") == null:
		return {"handled": false}
	var ev_name: String = str(event.name)
	var time: float = float(event.time)
	var invoked: bool = false
	if ev_name == "Loop" and (float(entry.t34) != time or (float(entry.t3C) < 0.0 and time == 0.0)):
		entry["t3C"] = time
		entry["t34"] = time
		entry["f48"] = 0
		entry["f24"] = 1
		if event_fn != null:
			(event_fn as Callable).call(entry)
			invoked = true
	elif ev_name == "Action":
		entry["t3C"] = 0.0
		entry["t34"] = 0.0
		entry["t38"] = time
		entry["f48"] = 0
		entry["f24"] = 1
	var parsed: Variant = C.parse_json_quiet(ev_name)
	var sound: Variant = null
	if parsed is Dictionary and (parsed as Dictionary).get("EventSound") is String:
		sound = parsed.EventSound
	return {"handled": true, "event_fn_invoked": invoked, "sound_name": sound}
