extends RefCounted
## M120 Ziggurat ordered message variants (C04, C11, C17; F120, corrected_v4) and
## M121 WarZone authored weather (C10, C11, C19; F121). DESIGN_NOT_RECOVERED_API.
## M120: the event id is matched against ScreenEffectID (native record+1C = payload+14), NOT the
##       message ID. Every type variant is visited in native order: selected -> show, others ->
##       hide. A late Label failure returns without undoing earlier writes.
## M121: the selected weather start is gotoFrameAndPlay(0) -> loop=true, end=duration (0..500),
##       not play("Fx_Start"). Frame7 EventSound is a separate frame-event path.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const M120_EVIDENCE := {"selection": C.EVIDENCE_CONFIRMED, "duplicate_tie_order": C.EVIDENCE_UNKNOWN, "runtime_rows": C.EVIDENCE_CONDITIONAL}
const M121_EVIDENCE := {"start_contract": C.EVIDENCE_CONFIRMED, "malformed_plist_acceptance": C.EVIDENCE_UNKNOWN, "audio_playback": C.EVIDENCE_UNKNOWN}

## ---------------- M120 ----------------

## controller (+50): {"owner", "timeline": {"ranges": {...}, "playing": bool}|null, "show_name": "On",
## "hide_name": "", "end_callbacks": {name: capture}, "slot98": Callable|null}. Two callback stores.
static func make_ziggurat(root: Variant, aliases: Dictionary, timeline: Variant) -> Dictionary:
	var owner := {"record": "ZigguratScreenMessageLayout", "design_status": C.DESIGN, "root": root, "aliases": aliases, "trace": []}
	var controller := {"timeline": timeline, "show_name": C.resolve_alias(aliases, "ZIGGURAT_MESSAGE_ANIM_ON"), "hide_name": "",
		"end_callbacks": {}, "slot98": null, "last_frame_installed": false}
	owner["controller"] = controller
	# 03273FE0 + setAnimationEndCallFunc (v108): installed only when the named animation exists.
	if timeline != null and (timeline.ranges as Dictionary).has(controller.show_name):
		controller.end_callbacks[controller.show_name] = {"raw_layout": owner}
	return owner

static func ziggurat_visible(owner: Dictionary) -> bool:
	return owner.root != null and bool(owner.root.visible)

static func ziggurat_can_show(owner: Dictionary) -> bool:
	var ctl: Dictionary = owner.controller
	return not ziggurat_visible(owner) and not (ctl.timeline != null and bool(ctl.timeline.playing)) and ctl.timeline != null

static func ziggurat_show(owner: Dictionary) -> bool:
	if not ziggurat_can_show(owner):
		return false
	var ctl: Dictionary = owner.controller
	if owner.root != null:
		owner.root["visible"] = true
	var r: Variant = (ctl.timeline.ranges as Dictionary).get(ctl.show_name)
	if r != null:  # named play request: authored start/end, current=start, loop=false
		ctl.timeline["start"] = int(r[0])
		ctl.timeline["end"] = int(r[1])
		ctl.timeline["current"] = int(r[0])
		ctl.timeline["loop"] = false
		ctl.timeline["playing"] = true
	ctl["last_frame_installed"] = true  # setLastFrameCallFunc member 032B4738 (separate store)
	return true

## env: {"messages": native rows|null, "types": native rows|null, "descs": {...}}
static func ziggurat_receive(capture: Dictionary, event: Variant, env: Dictionary) -> Dictionary:
	if event == null or event.get("kind") != "SingleValueEvent<DynamicMap<string>>":
		return {"stage": "wrong-event"}
	var typed: Variant = C.typed_int_pointer(event.map, "id")
	if typed == null:
		return {"stage": "id-missing"}
	var incoming: int = int(typed)
	var messages: Variant = env.get("messages")
	var types: Variant = env.get("types")  # independent lookup
	if messages == null or (messages as Array).is_empty():
		return {"stage": "messages-missing"}
	var m: Variant = null
	for rec: Dictionary in messages:
		if C.i32(int(rec.ScreenEffectID)) == incoming:
			m = rec
			break
	if m == null:
		return {"stage": "no-match"}
	if types == null:
		return {"stage": "types-null", "outcome": C.UNGUARDED_BOUNDARY}
	var visited: Array = []
	for t: Dictionary in types:
		var alias_key: String = "ZIGGURAT_MESSAGE_BG_%s_NODE" % str(t.Type)  # type string, not ID
		var owner: Dictionary = capture.owner
		var root: Variant = owner.root  # re-read per variant
		var bg: Variant = null
		var bg_alias: String = C.resolve_alias(owner.aliases, alias_key)
		if not bg_alias.is_empty() and root != null:
			bg = C.dot_path(root, bg_alias)
		if bg == null:
			visited.append([t.Type, "absent"])
			continue
		if C.i32(int(t.ID)) != C.i32(int(m.ZigguratScreenMessageTypeID)):
			bg["visible"] = false
			visited.append([t.Type, "hide"])
			continue
		bg["visible"] = true  # committed BEFORE the label lookup
		visited.append([t.Type, "show"])
		var text: Variant = null
		var label_alias: String = C.resolve_alias(owner.aliases, "ZIGGURAT_MESSAGE_TEXT")
		if not label_alias.is_empty():
			var child: Variant = C.dot_path(bg, label_alias)  # relative to the variant, not global
			if child != null and child.type == "Text":
				text = child
		if text == null:
			return {"stage": "label-missing", "message_id": int(m.ID), "visited": visited}
		text["text"] = str((env.get("descs", {}) as Dictionary).get(int(m.DescID), ""))
		text["set_calls"] = int(text.get("set_calls", 0)) + 1
		var owner_now: Dictionary = capture.owner
		if ziggurat_can_show(owner_now):
			ziggurat_show(owner_now)
	return {"stage": "done", "message_id": int(m.ID), "visited": visited}

## On-specific end callback (constructor capture) -> 032F03C0 on CURRENT controller state.
static func ziggurat_on_end(callback_capture: Dictionary) -> void:
	var owner: Dictionary = callback_capture.raw_layout
	var ctl: Dictionary = owner.controller
	if not str(ctl.hide_name).is_empty() and ctl.timeline != null and (ctl.timeline.ranges as Dictionary).has(ctl.hide_name):
		(owner.trace as Array).append(["named-hide", ctl.hide_name])
		return
	if owner.root != null:
		owner.root["visible"] = false
	if ctl.timeline != null and bool(ctl.timeline.playing):
		ctl.timeline["playing"] = false  # stop -> pause; text/variants/last id untouched
	(owner.trace as Array).append("hide-and-pause")

## Generic last-frame member: invokes the CURRENT controller+98 function (empty at construction).
static func ziggurat_last_frame(owner: Dictionary) -> bool:
	var fn: Variant = owner.controller.slot98
	if fn == null:
		return false
	(fn as Callable).call(owner)
	return true

## ---------------- M121 ----------------

## action: {"duration": 500, "speed": 0.5, "ranges": {"Fx_Start": [5,500], "animation0": [1500,2000]}}
## 00246688 overload: frame0 -> loop=true, end=duration, current=start.
static func goto_frame_and_play(action: Dictionary, start: int) -> Dictionary:
	action["start"] = start
	action["end"] = int(action.duration)
	action["current"] = start
	action["loop"] = true
	action["playing"] = true
	return {"start": start, "end": int(action.duration), "loop": true}

## For comparison only: what a named play would request (NOT the selected weather start route).
static func named_play_request(action: Dictionary, anim_name: String, loop: bool) -> Variant:
	var r: Variant = (action.ranges as Dictionary).get(anim_name)
	return null if r == null else {"start": int(r[0]), "end": int(r[1]), "loop": loop}

## block: {"active", "path", "parent": {"children": []}}; hooks: create_node(path)->node|null,
## create_timeline(path)->action|null, find_particle(node)->particle|null.
static func start_weather(block: Dictionary, skip_prewarm: bool, hooks: Dictionary) -> Dictionary:
	if bool(block.active):
		return {"stage": "already-active"}
	var child: Variant = (hooks.create_node as Callable).call(block.path)
	if child == null:
		return {"stage": "node-null"}
	block["child"] = child
	(block.parent.children as Array).append(child)
	var action: Variant = (hooks.create_timeline as Callable).call(block.path)
	var request: Variant = null
	if action != null:
		action["frame_event_callback_installed"] = true
		request = goto_frame_and_play(action, 0)
		child["running_action"] = action  # attach after the start setup
	var prewarm_steps: Array = []
	if not skip_prewarm and hooks.has("find_particle"):
		var found: Variant = (hooks.find_particle as Callable).call(child)
		if found != null:
			for _i: int in 100:
				prewarm_steps.append(0.2)
	block["active"] = true  # an action == null does not undo node creation
	return {"stage": "started", "request": request, "prewarm_steps": prewarm_steps.size()}

## EventFrame::onEnter guard + game frame-event callback (JSON EventSound -> UI audio NAME lookup).
static func event_frame_on_enter(frame: Dictionary, action: Variant, current_frame: int, sound_lookup: Dictionary) -> Dictionary:
	if action == null:
		return {"emitted": false}
	if int(frame.index) < int(action.start) or int(frame.index) > int(action.end):
		return {"emitted": false}
	if current_frame < int(frame.index):
		return {"emitted": false}
	if not bool(action.get("frame_event_callback_installed", false)):
		return {"emitted": true, "callback": false}
	var parsed: Variant = C.parse_json_quiet(str(frame.text))
	if parsed is Dictionary and (parsed as Dictionary).get("EventSound") is String:
		var sound_name: String = parsed.EventSound
		return {"emitted": true, "callback": true, "sound_name": sound_name, "sound_lookup": sound_lookup.get(sound_name), "playback_observed": false}
	return {"emitted": true, "callback": true, "sound_name": null}

## Strict whole-document check vs. first-document-only interpretation. Original bytes are never
## trimmed or repaired; the native acceptance of the trailing bytes stays UNKNOWN.
static func inspect_plist(original: PackedByteArray) -> Dictionary:
	var marker: PackedByteArray = "</plist>".to_utf8_buffer()
	var end_offset: int = -1
	for i: int in range(0, original.size() - marker.size() + 1):  # byte offsets (a UTF-8 BOM counts)
		if original.slice(i, i + marker.size()) == marker:
			end_offset = i + marker.size()
			break
	if end_offset < 0:
		return {"strict": "REJECTED", "first_document_end": null}
	var text: String = original.slice(0, end_offset).get_string_from_utf8()
	var first_end: int = text.length()
	var tail: PackedByteArray = original.slice(end_offset)
	var strict_ok: bool = tail.get_string_from_utf8().strip_edges().is_empty()
	var texture: Variant = null
	var key_at: int = text.find("<key>textureFileName</key>")
	if key_at >= 0 and key_at < first_end:
		var s0: int = text.find("<string>", key_at) + "<string>".length()
		texture = text.substr(s0, text.find("</string>", s0) - s0)
	return {"strict": "ACCEPTED" if strict_ok else "REJECTED", "first_document_end": end_offset, "tail_hex": tail.hex_encode(),
		"interpretation": "first-document-only authored interpretation; native acceptance unresolved", "textureFileName": texture,
		"original_size": original.size(), "native_acceptance": C.EVIDENCE_UNKNOWN}
