extends RefCounted
## M103 TimeClear request/duplicate/cleanup, M105 real CSB authored-data contract, M107 UiEffect
## last-owner destructor, M108 real atlas frames (C11/C13/C17/C20). DESIGN_NOT_RECOVERED_API.
## Requests and authored data only: effect+20 is a "requested" flag, not Start success; frame
## numbers are not seconds; atlas rectangles are not runtime SpriteFrame/UV/pixel results.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")
const RUNTIME_TAG := 0x2329  # 9001: effect instance dedup/cleanup tag set by code
const FX_FILE_KEY := "TIME_CLEAR_SLOT_FX_FILE"
const ANIM_NAME_KEY := "TIME_CLEAR_SLOT_ANIM_NAME"

# ---------------------------------------------------------------- M103
## E0312E220: page_index / button_index are looked up separately; a missing or wrong-typed value
## is NOT integer zero: no call happens.
static func on_event_9EE(owner: Dictionary, event: Variant, on: bool = true) -> Dictionary:
	if event == null:
		return {"called": false}
	var map: Variant = (event as Dictionary).get("map")
	if not (map is Dictionary):
		return {"called": false}
	var p: Variant = (map as Dictionary).get("page_index")
	var b: Variant = (map as Dictionary).get("button_index")
	if not (p is int) or not (b is int):
		return {"called": false}
	return {"called": true, "result": slot_request(owner, int(p), int(b), on)}

## E031F0F70 page/current-page/slot gates, then E031F0A30.
static func slot_request(owner: Dictionary, page32: int, button32: int, on: bool) -> Dictionary:
	var p: int = V.i32(page32)
	var i: int = V.i32(button32)
	if p != int(owner.current_page_80):
		if p != int(owner.current_page_88) + V.i32(int(owner.first_count)) or not bool(owner.visible_88):
			if V.u32(p) != V.u32(int(owner.special)) or not bool(owner.visible_90) or i >= V.i32(int(owner.limit)):
				return {"gate": "page_mismatch_return"}
	var page: Variant = (owner.pages as Dictionary).get(p)
	if page == null:
		return {"gate": "page_missing_return"}
	var slots: Array = page
	if i < 0 or i >= slots.size():  # unsigned64 compare: a negative index is huge
		return {"gate": "slot_index_return"}
	var slot: Variant = slots[i]
	if slot == null:
		return {"gate": "slot_null"}
	return slot_effect(owner.manager, slot, on)

## E031F0A30. slot invisible OR on==false -> cleanup every target/tag match (unlink first, then
## release; final destruction only on last strong). Hidden third ancestor -> return, no cleanup.
static func slot_effect(manager: Dictionary, slot: Dictionary, on: bool) -> Dictionary:
	var target: String = slot.target
	if not bool(slot.visible_28) or not on:
		var removed: Array = []
		var kept: Array = []
		for e: Dictionary in manager.list:
			if e.target == target and int(e.tag) == RUNTIME_TAG:
				removed.append(e)
			else:
				kept.append(e)
		manager["list"] = kept
		for e: Dictionary in removed:
			e["strong"] = int(e.strong) - 1
			e["destroyed"] = int(e.strong) == 0
		return {"action": "cleanup", "removed": removed.size()}
	var chain: Array = slot.get("ancestors", [])  # [P(N), P(P(N)), P(P(P(N)))] evaluated in order
	if chain.size() >= 3 and chain[0] != null and chain[1] != null and chain[2] != null and not bool(chain[2].visible):
		return {"action": "hidden_ancestor_return_no_cleanup"}
	var pair: Dictionary = create_effect(manager, target, slot.get("factory_ok", true))
	if pair.object == null:
		return {"action": "no_effect", "reason": pair.reason}
	var obj: Dictionary = pair.object
	obj["position"] = effect_position(slot.converted, slot.anchor, slot.size)
	if obj.timeline != null:
		obj["play_request"] = ["virtual40", "Start", true]
		obj["byte20"] = 1
	return {"action": "requested", "effect": obj}

## E03192D00: duplicate target+tag returns a NULL pair (no reuse/restart/reposition).
static func create_effect(manager: Dictionary, target: Variant, factory_ok: bool) -> Dictionary:
	if target == null:
		return {"object": null, "reason": "target_null"}
	for e: Dictionary in manager.list:
		if e.target == target and int(e.tag) == RUNTIME_TAG:
			return {"object": null, "reason": "duplicate_null_pair"}
	if not factory_ok:
		return {"object": null, "reason": "factory_null"}
	var obj := {"target": target, "tag": RUNTIME_TAG, "timeline": "ActionTimeline", "byte20": 0, "strong": 1, "destroyed": false}
	(manager.list as Array).append(obj)
	return {"object": obj}

## Per axis round32(round32(converted - round32(anchor*size)) + round32(size/2.0f)) (divss).
static func effect_position(converted: Vector2, anchor: Vector2, size: Vector2) -> Vector2:
	var out := Vector2()
	for ax: int in 2:
		var c: float = V.f32(converted[ax])
		var as_: float = V.f32(V.f32(anchor[ax]) * V.f32(size[ax]))
		var half: float = V.f32(V.f32(size[ax]) / V.f32(2.0))
		out[ax] = V.f32(V.f32(c - as_) + half)
	return out

# ---------------------------------------------------------------- M105
## Contract checks on the REAL authored data (fixture.real.m105_csb).
static func csb_contract(csb: Dictionary) -> Dictionary:
	var keys: Array = csb.keyframes
	var tracks := {}
	var file_keys: Array = []
	var alpha_tween_absent := true
	var file_tween_false := true
	for k: Dictionary in keys:
		tracks[int(k.track)] = true
		if k.property == "FileData":
			file_keys.append(k)
			if not (bool(k.tween_present) and int(k.tween) == 0):
				file_tween_false = false
		elif k.property == "Alpha" and bool(k.tween_present):
			alpha_tween_absent = false
	file_keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.index) < int(b.index))
	var unique := {}
	for k: Dictionary in file_keys:
		unique[k.resource] = true
	var authored_tags := {}
	for n: Dictionary in csb.nodes:
		if n.action_tag != null:
			authored_tags[int(n.action_tag)] = true
		authored_tags[int(n.node_tag)] = true
	var anim: Dictionary = csb.animations[0]
	return {"nodes": csb.nodes.size(), "tracks": tracks.size(), "keys": keys.size(), "file_keys": file_keys.size(),
		"file_unique": unique.size(), "last_file_key": [int(file_keys[-1].index), file_keys[-1].resource],
		"alpha_tween_loader_value": true if alpha_tween_absent else null, "file_tween_explicit_false": file_tween_false,
		"start": [anim.name, int(anim.start), int(anim.end)], "duration_frames": int(csb.action.duration), "speed": float(csb.action.speed),
		"duration_seconds": V.UNKNOWN, "runtime_tag_is_authored": authored_tags.has(RUNTIME_TAG),
		"loop_from_code_request": true, "loop_in_file": false}

## The Alpha easing slot3 table is NOT applied (the Alpha reader never reads slot3); FileData's
## slot3 is passed to the easing loader.
static func easing_slot3_consumed(property: String) -> bool:
	return property == "FileData"

## Optional real-byte check of the CSB: SHA256 and every recorded int32/byte offset.
static func csb_raw_check(bytes: PackedByteArray, csb: Dictionary) -> Dictionary:
	var bad: Array = []
	if bytes.size() != int(csb.bytes) or V.sha256_bytes(bytes) != csb.sha256:
		bad.append("size/sha256")
	if bytes.decode_s32(int(csb.action.duration_offset)) != int(csb.action.duration):
		bad.append("duration")
	if not is_equal_approx(bytes.decode_float(int(csb.action.speed_offset)), float(csb.action.speed)):
		bad.append("speed")
	for a: Dictionary in csb.animations:
		if bytes.decode_s32(int(a.start_offset)) != int(a.start) or bytes.decode_s32(int(a.end_offset)) != int(a.end):
			bad.append("anim")
	for n: Dictionary in csb.nodes:
		if bytes.decode_s32(int(n.node_tag_offset)) != int(n.node_tag):
			bad.append("node_tag " + str(n.name))
		if n.action_tag_offset != null and bytes.decode_s32(int(n.action_tag_offset)) != int(n.action_tag):
			bad.append("action_tag " + str(n.name))
	for k: Dictionary in csb.keyframes:
		if bytes.decode_s32(int(k.index_offset)) != int(k.index):
			bad.append("index@%d" % int(k.index_offset))
		if k.alpha_offset != null and bytes.decode_s32(int(k.alpha_offset)) != int(k.alpha):
			bad.append("alpha@%d" % int(k.alpha_offset))
		if bool(k.tween_present) and bytes[int(k.tween_offset)] != int(k.tween):
			bad.append("tween@%d" % int(k.tween_offset))
	return {"mismatches": bad}

# ---------------------------------------------------------------- M107
## E0318F780 UiEffect destructor (flags 0 on the known control path). The parent is queried NOW
## (getParent virtual), the child and the released node are separate reads; target+10 is never
## used as the parent. Callables at +68 then +28 are DESTROYED (not invoked).
## effect: {"node": Dictionary|null, "target": String, "optional_control": Dictionary|null,
##          "callable68": Variant, "callable28": Variant}
## node: {"id": String, "parent": Variant}; get_parent: Callable(effect, node) -> parent (may mutate)
static func ui_effect_destroy(effect: Dictionary, get_parent: Callable, remove_child: Callable, flags: int = 0) -> Array:
	var ev: Array = []
	var node_first: Variant = effect.get("node")
	if node_first != null:
		var parent: Variant = get_parent.call(effect, node_first)
		if parent != null:
			var child_now: Variant = effect.get("node")
			ev.append(["removeChild", parent, child_now.id if child_now != null else null, true])
			remove_child.call(effect, parent, child_now)
		var node_for_release: Variant = effect.get("node")
		ev.append(["Ref_release", node_for_release.id if node_for_release != null else null])
	var oc: Variant = effect.get("optional_control")
	if oc != null:
		oc["strong"] = int(oc.strong) - 1
		if int(oc.strong) == 0:
			ev.append(["control.virtual0"])
			oc["weak"] = int(oc.weak) - 1
			if int(oc.weak) == 0:
				ev.append(["control.virtual8"])
	for slot: String in ["callable68", "callable28"]:
		if effect.get(slot) != null:
			ev.append(["destroy", slot])
			effect[slot] = null
	if (flags & 1) != 0:
		ev.append(["sized_free", 0xC0])
	return ev

# ---------------------------------------------------------------- M108
## Contract checks on the REAL frame table (fixture.real.m108_atlas).
static func atlas_contract(atlas: Dictionary) -> Dictionary:
	var by_plist := {}
	var untrimmed := true
	for f: Dictionary in atlas.frames:
		by_plist[f.plist] = int(by_plist.get(f.plist, 0)) + 1
		var w: int = int(f.xywh[2])
		var h: int = int(f.xywh[3])
		if bool(f.rotated) or f.offset != "{0,0}" or f.sourceColorRect != "{{0,0},{%d,%d}}" % [w, h] or f.sourceSize != "{%d,%d}" % [w, h]:
			untrimmed = false
	return {"selected": atlas.frames.size(), "per_plist": by_plist, "all_unrotated_untrimmed": untrimmed,
		"runtime_spriteframe_claimed": false, "metadata_premultiply_is_runtime_pma": false}

## Optional real-byte check: parse frame entries from the authored plist XML text.
static func plist_frames(text: String, names: Array) -> Dictionary:
	var out := {}
	for n: String in names:
		var at: int = text.find("<key>" + n + "</key>")
		if at < 0:
			continue
		var fk: int = text.find("<key>frame</key>", at)
		var s0: int = text.find("<string>", fk) + 8
		var s1: int = text.find("</string>", s0)
		var rk: int = text.find("<key>rotated</key>", at)
		var rot: String = text.substr(rk + 18, 12).strip_edges()
		out[n] = {"frame": text.substr(s0, s1 - s0), "rotated": rot.begins_with("<true")}
	return out
