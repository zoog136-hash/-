extends RefCounted
## M121 WarZone authored weather (C10, C11, C19; F121). DESIGN_NOT_RECOVERED_API.
## (M120 Ziggurat was removed with the cut Ziggurat tables, user decision 2026-11-10.)
## M121: the selected weather start is gotoFrameAndPlay(0) -> loop=true, end=duration (0..500),
##       not play("Fx_Start"). Frame7 EventSound is a separate frame-event path.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const M121_EVIDENCE := {"start_contract": C.EVIDENCE_CONFIRMED, "malformed_plist_acceptance": C.EVIDENCE_UNKNOWN, "audio_playback": C.EVIDENCE_UNKNOWN}

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
