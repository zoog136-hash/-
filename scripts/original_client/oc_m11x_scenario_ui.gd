extends RefCounted
## M117 Conquest hero announcement (C11, C17; F117), M118 Albino LIFO pending queue (C11, C17; F118)
## and M119 Escaros priority/timer (C11, C17, C20; F119). DESIGN_NOT_RECOVERED_API.
## Each screen keeps ITS OWN policy: Conquest restarts on every valid event, Albino queues while
## visible and drains LIFO from the last-frame callback, Escaros replaces only on a smaller signed
## priority. None of them rolls back earlier partial UI writes. Authored frame ranges are data;
## wall-clock playback / callback timing / pixels are not modelled.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const EVENT_ALBINO := 423
const EVENT_ESCAROS := 0x727
const ESCAROS_INITIAL_PRIORITY := 99
const NPC_ATTRIBUTE_TITLE := 564
const SPELL_BONUS_TYPE_MARK := 6544
const EVIDENCE := {"branching": C.EVIDENCE_CONFIRMED, "current_rows": C.EVIDENCE_CONDITIONAL, "playback_callback_timing": C.EVIDENCE_UNKNOWN}

## Description lookup 02140920: absent -> empty string (inherited contract).
static func localize(descs: Dictionary, desc_id: int) -> String:
	return str(descs.get(desc_id, ""))

static func asset_path(assets: Dictionary, asset_id: int) -> String:
	return str(assets.get(asset_id, ""))

static func set_text(node: Dictionary, text: String, hooks: Dictionary) -> void:
	node["text"] = text
	node["set_calls"] = int(node.get("set_calls", 0)) + 1
	if hooks.has("after_set"):
		(hooks.after_set as Callable).call(node)  # virtual setter boundary may re-enter

static func set_texture(node: Dictionary, path: String) -> void:
	node["texture"] = path
	node["set_calls"] = int(node.get("set_calls", 0)) + 1

## ---------------- M118 Albino ----------------

static func make_albino_layout(root: Variant, aliases: Dictionary, timeline: Variant) -> Dictionary:
	return {"record": "AlbinoScreenEffectLayout", "design_status": C.DESIGN, "root": root, "aliases": aliases, "timeline58": timeline,
		"queue": {"capacity": 0, "head": 0, "count": 0, "map": []}, "published": [], "trace": [], "last_frame_capture": null}

## 032FD020: null root -> false; else the root's visibility.
static func albino_visible(layout: Dictionary) -> bool:
	return layout.root != null and bool(layout.root.visible)

static func albino_set_visible(layout: Dictionary, visible: bool, hooks: Dictionary) -> void:
	if layout.root != null:
		layout.root["visible"] = visible
	(layout.trace as Array).append(["set-visible", visible])
	if hooks.has("after_visibility"):
		(hooks.after_visibility as Callable).call(layout, visible)

## extract_pair: invalid only when the event is not SingleValueEvent<DynamicMap>.
static func extract_pair(event: Variant) -> Variant:
	if event == null or event.get("kind") != "SingleValueEvent<DynamicMap<string>>":
		return null
	return {"asset": C.typed_int_or_zero(event.map, "assetid"), "desc": C.typed_int_or_zero(event.map, "descid")}

static func albino_receive(capture: Dictionary, event: Variant, env: Dictionary) -> String:
	var hooks: Dictionary = env.get("hooks", {})
	var pair: Variant = extract_pair(event)
	if pair == null:
		return "invalid"
	if albino_visible(capture.layout):
		albino_append(capture.layout, event)  # ORIGINAL event, re-extracted
		return "queued"
	if capture.layout.timeline58 != null:
		albino_set_visible(capture.layout, true, hooks)
		var timeline: Variant = capture.layout.timeline58  # reread, no new null check
		if timeline == null:
			return C.UNGUARDED_BOUNDARY
		(capture.layout.trace as Array).append(["play", C.resolve_alias(capture.layout.aliases, "ALBINO_BOSS_SCREENEFFECT_ANIM"), false])
		var timeline_now: Variant = capture.layout.timeline58  # reread after play
		if timeline_now == null:
			return C.UNGUARDED_BOUNDARY
		capture.layout["last_frame_capture"] = capture.layout  # raw capture
	var sprite: Variant = C.typed_child(capture.layout.root, capture.layout.aliases, "ALBINO_BOSS_SCREENEFFECT_BOSS_SPRITE", "Sprite")
	if sprite == null:
		return "sprite-missing-text-skipped"  # after the animation requests
	set_texture(sprite, asset_path(env.assets, int(pair.asset)))
	var text: Variant = C.typed_child(capture.layout.root, capture.layout.aliases, "ALBINO_BOSS_SCREENEFFECT_BOSS_TEXT", "Text")
	if text != null:
		set_text(text, localize(env.descs, int(pair.desc)), hooks)
	return "presented"

## 0260D630 + 0264B120: circular pointer map; pair objects keep sign-extended 64-bit values.
static func albino_append(layout: Dictionary, event: Variant) -> void:
	var pair: Variant = extract_pair(event)
	if pair == null:
		return
	var q: Dictionary = layout.queue
	if int(q.capacity) <= int(q.count) + 1:
		grow(q, 1)
	q["head"] = int(q.head) & (int(q.capacity) - 1)
	var pos: int = int(q.head) + int(q.count)
	var index: int = pos & (int(q.capacity) - 1)
	if q.map[index] == null:
		q.map[index] = {}
	q.map[index]["first"] = int(pair.asset)  # sign_extend_i32 kept as a signed int
	q.map[index]["second"] = int(pair.desc)
	q["count"] = int(q.count) + 1

static func grow(q: Dictionary, extra: int) -> void:
	var old: int = int(q.capacity)
	var n: int = old if old != 0 else 1
	while n - old < extra or n < 8:
		n *= 2
	var head: int = int(q.head)
	var new_map: Array = []
	new_map.resize(n)
	for i: int in range(head, old):
		new_map[i] = q.map[i]
	var delta: int = n - old
	if head <= delta:
		for i: int in head:
			new_map[old + i] = q.map[i]
	else:
		for i: int in delta:
			new_map[old + i] = q.map[i]
		for i: int in head - delta:
			new_map[i] = q.map[delta + i]
	q["map"] = new_map
	q["capacity"] = old + delta

## 02647CB0: hide first (may re-enter), then ONE drain if count != 0.
static func albino_last_frame(capture_layout: Dictionary, env: Dictionary) -> void:
	albino_set_visible(capture_layout, false, env.get("hooks", {}))
	if int(capture_layout.queue.count) != 0:
		albino_drain(capture_layout)

## 0261DFD0: pop the NEWEST pair (LIFO), count decremented BEFORE publication, slot retained.
static func albino_drain(layout: Dictionary) -> void:
	var q: Dictionary = layout.queue
	var n: int = int(q.count)
	if n == 0:
		return
	var pair16: Dictionary = (q.map[(int(q.head) + n - 1) & (int(q.capacity) - 1)] as Dictionary).duplicate()
	q["count"] = n - 1
	if int(q.count) == 0:
		q["head"] = 0
	var map := {"assetid": C.i32(int(pair16.first)), "descid": C.i32(int(pair16.second))}  # lowDWORD
	(layout.published as Array).append({"event": EVENT_ALBINO, "kind": "SingleValueEvent<DynamicMap<string>>", "map": map})

## ---------------- M119 Escaros ----------------

static func make_escaros_owner(root: Variant, aliases: Dictionary, timeline: Variant) -> Dictionary:
	return {"record": "EscarosScreenEffectLayout", "design_status": C.DESIGN, "root": root, "aliases": aliases, "priority": ESCAROS_INITIAL_PRIORITY,
		"controller": {"timeline": timeline, "playing": false, "completion": null, "show_name": C.resolve_alias(aliases, "ESCAROS_SCREEN_EFFECT_SHOW_ANIM"), "hide_name": ""},
		"spell_pair100": null, "trace": [], "timers": []}

static func escaros_visible(owner: Dictionary) -> bool:
	return owner.root != null and bool(owner.root.visible)

## env: {"screen_effects": {id: row}, "npc": {id: row}, "npc_attr": {npc: value}, "titles": {id: row}|null,
##       "spells": {...}, "descs", "assets", "hooks"}
static func escaros_receive(capture: Dictionary, event: Variant, env: Dictionary) -> Dictionary:
	var hooks: Dictionary = env.get("hooks", {})
	if event == null or event.get("kind") != "SingleValueEvent<DynamicMap<string>>":
		return {"stage": "wrong-event"}
	var id: Variant = C.typed_int_pointer(event.map, "id")
	var npc: Variant = C.typed_int_pointer(event.map, "npcclassid")
	var spell: Variant = C.typed_int_pointer(event.map, "spellclassid")
	var desc: Variant = C.typed_int_pointer(event.map, "descid")
	if id == null and npc == null and spell == null and desc == null:
		return {"stage": "preflight-all-null"}
	if id == null:
		return {"stage": "id-pointer-null", "outcome": C.UNGUARDED_BOUNDARY}
	var effect: Variant = (env.screen_effects as Dictionary).get(id)
	if effect == null:
		return {"stage": "effect-missing"}
	var owner: Dictionary = capture.owner
	if escaros_visible(owner) and C.i32(int(owner.priority)) <= C.i32(int(effect.Priority)):
		return {"stage": "priority-rejected"}
	var spell_value: int = int(spell) if spell != null else 0
	owner.controller["completion"] = {"raw_owner": owner, "spell": spell_value}  # replaced first
	(owner.trace as Array).append("completion-replaced")
	if npc == null:
		return {"stage": "npc-pointer-null", "outcome": C.UNGUARDED_BOUNDARY}
	var npc_row: Variant = (env.npc as Dictionary).get(npc)
	if npc_row == null:
		return {"stage": "npc-missing"}
	var name_node: Variant = C.typed_child(capture.owner.root, owner.aliases, "ESCAROS_SCREEN_EFFECT_NPC_NAME_TEXT", "Text")
	if name_node == null:
		return {"stage": "name-text-missing"}
	set_text(name_node, localize(env.descs, int(npc_row.DescId)), hooks)
	var desc_node: Variant = C.typed_child(capture.owner.root, owner.aliases, "ESCAROS_SCREEN_EFFECT_NPC_DESC_TEXT", "Text")
	if desc_node == null:
		return {"stage": "desc-text-missing"}
	if desc == null:
		return {"stage": "desc-pointer-null", "outcome": C.UNGUARDED_BOUNDARY}  # no guard here
	set_text(desc_node, localize(env.descs, int(desc)), hooks)
	var attrs: Dictionary = env.get("npc_attr", {})
	if attrs.has(npc):
		var titles: Variant = env.get("titles")
		if titles == null or not (titles as Dictionary).has(int(attrs[npc])):
			return {"stage": "title-missing"}  # presence gate only; no title text write
	var icon: Variant = C.typed_child(capture.owner.root, owner.aliases, "ESCAROS_SCREEN_EFFECT_NPC_ICON_IMG", "Sprite")
	if icon == null:
		return {"stage": "icon-missing"}
	set_texture(icon, asset_path(env.assets, int(npc_row.IllustAssetID)))
	capture.owner["priority"] = C.i32(int(effect.Priority))  # late commit
	var shown: bool = false
	if escaros_can_show(capture.owner):
		shown = escaros_show(capture.owner)
	var spell_stage: String = escaros_optional_spell(capture.owner, spell_value, env)
	return {"stage": "committed", "shown": shown, "spell_stage": spell_stage}

## 032DDC10: owner hidden AND timeline not playing AND timeline nonnull.
static func escaros_can_show(owner: Dictionary) -> bool:
	return not escaros_visible(owner) and not bool(owner.controller.playing) and owner.controller.timeline != null

static func escaros_show(owner: Dictionary) -> bool:
	if not escaros_can_show(owner):  # 0331DC70 re-checks
		return false
	(owner.trace as Array).append("decoration-six-strings")
	if owner.root != null:
		owner.root["visible"] = true
	owner.controller["playing"] = true
	(owner.trace as Array).append(["play", owner.controller.show_name, false])
	owner.controller["last_frame"] = "controller+98-current"  # reads the CURRENT completion slot
	return true

## last-frame -> current completion; spell 0 -> finish (hide name empty -> hide + pause).
static func escaros_last_frame(owner: Dictionary) -> void:
	var completion: Variant = owner.controller.completion
	if completion == null:
		return
	if int(completion.spell) == 0:
		var raw_owner: Dictionary = completion.raw_owner
		if raw_owner.root != null:
			raw_owner.root["visible"] = false
		if bool(raw_owner.controller.playing):
			raw_owner.controller["playing"] = false
		(raw_owner.trace as Array).append("finish-hide")  # priority/text stay

static func escaros_optional_spell(owner: Dictionary, spell: int, env: Dictionary) -> String:
	var child_alias: String = C.resolve_alias(owner.aliases, "ESCAROS_SCREEN_EFFECT_SPELL_ROOT_NODE")
	var child: Variant = null if child_alias.is_empty() else C.dot_path(owner.root, child_alias)  # aliasNode, no cast
	if child == null:
		return "spell-child-missing"
	child["visible"] = spell != 0
	if spell == 0:
		return "spell-zero"  # no old timer/action reset
	var spells: Dictionary = env.get("spells", {})
	var spell_row: Variant = (spells.get("SpellClass", {}) as Dictionary).get(spell)
	if spell_row == null:
		return "spell-row-missing"
	var name_text: Variant = C.typed_child(child, owner.aliases, "ESCAROS_SCREEN_EFFECT_SPELL_NAME_TEXT", "Text")
	if name_text == null:
		return "spell-text-missing"
	set_text(name_text, localize(env.descs, int(spell_row.DescID)), {})
	var sprite: Variant = C.typed_child(child, owner.aliases, "ESCAROS_SCREEN_EFFECT_SPELL_ICON_IMG", "Sprite")
	if sprite == null:
		return "spell-icon-missing"
	var bonus: Variant = null
	for b: Dictionary in (spells.get("bonuses_by_spell", {}) as Dictionary).get(spell, []):
		if int(b.BonusTypeID) == SPELL_BONUS_TYPE_MARK:
			bonus = b
			break
	if bonus == null:
		return "bonus-missing"
	var mark: Variant = (spells.get("SpellMark", {}) as Dictionary).get(int(bonus.Value))
	if mark == null:
		return "mark-missing"
	var mark_type: Variant = (spells.get("SpellMarkType", {}) as Dictionary).get(int(mark.SpellMarkType))
	if mark_type != null:
		set_texture(sprite, asset_path(env.assets, int(mark_type.AssetID)))
	var action: Variant = child.get("action")
	if action == null:
		return "action-missing"
	action["played"] = ["SHOW_ANIM", false]
	var duration_ms: int = C.i32(int(mark.Delay)) * 1000
	var timer := {"record": "RemainsTimer", "period": duration_ms, "interval_remaining": duration_ms, "lifetime_remaining": duration_ms, "expired": false}
	var old: Variant = owner.spell_pair100
	owner["spell_pair100"] = timer  # store new, then release old
	if old != null:
		old["released"] = true
	(owner.timers as Array).append(timer)
	return "spell-timer-%d" % duration_ms

## RemainsTimer.update: signed 64-bit subtraction; expiry when lifetime <= 0.
static func remains_timer_update(timer: Dictionary, delta_ms: int) -> bool:
	timer["interval_remaining"] = int(timer.interval_remaining) - delta_ms
	timer["lifetime_remaining"] = int(timer.lifetime_remaining) - delta_ms
	if int(timer.interval_remaining) <= 0:
		timer["interval_remaining"] = int(timer.period)
	timer["expired"] = int(timer.lifetime_remaining) <= 0
	return bool(timer.expired)
