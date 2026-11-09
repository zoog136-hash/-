extends RefCounted
## M115 (C09, C14; F115) actor outline: 18-pair first-true priority, UIOutlineRef -> UIOutline,
## ColorTable RGB input, RGB565 colour/alpha sample vectors and the low16 period.
## DESIGN_NOT_RECOVERED_API; corrected_v3 leaf ranges. Actor state names are NOT inferred: types
## 2/3/6/7/22 and actor+B8 0/-1 stay numeric. Outline actor fields are separate from M45/target UI.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const ATTR_OUTLINE := 0x8000
const EFFECT_KEY_OUTLINE := 4
const DEFAULT_PERIOD := 100
const DEFAULT_ALPHA := 100
const DEFAULT_COLOR := 0
const COLOR_ROW_ELVEN_GATE := 11441
const EVIDENCE := {"priority": C.EVIDENCE_CONFIRMED, "current_rows": C.EVIDENCE_CONDITIONAL, "gpu": C.EVIDENCE_UNKNOWN}

## DECISION_TABLE.json order (01C998E0). kind -> predicate; ref = UIOutlineRef key passed to the
## resolver (null for the NPC resolver, which uses the inherited UINpcOutline path).
const PAIRS := [
	{"priority": 1, "kind": "identity", "type": 6, "ref": 8},
	{"priority": 2, "kind": "b8_zero", "type": 6, "ref": 111},
	{"priority": 3, "kind": "b8_not_minus1", "type": 6, "ref": 18},
	{"priority": 4, "kind": "npc", "type": null, "ref": null},
	{"priority": 5, "kind": "byte7e", "type": 6, "ref": 68},
	{"priority": 6, "kind": "byte7f", "type": 6, "ref": 78},
	{"priority": 7, "kind": "b8_not_minus1", "type": 22, "ref": 28},
	{"priority": 8, "kind": "byte7e", "type": 22, "ref": 68},
	{"priority": 9, "kind": "b8_not_minus1", "type": 3, "ref": 38},
	{"priority": 10, "kind": "b8_not_minus1", "type": 3, "ref": 48},
	{"priority": 11, "kind": "elven", "type": 2, "ref": 88},
	{"priority": 12, "kind": "identity", "type": 2, "ref": 8},
	{"priority": 13, "kind": "b8_zero", "type": 2, "ref": 111},
	{"priority": 14, "kind": "b8_not_minus1", "type": 2, "ref": 18},
	{"priority": 15, "kind": "elven", "type": 7, "ref": 88},
	{"priority": 16, "kind": "identity", "type": 7, "ref": 8},
	{"priority": 17, "kind": "b8_zero", "type": 7, "ref": 111},
	{"priority": 18, "kind": "b8_not_minus1", "type": 7, "ref": 18},
]

## 024CA0F0
static func blocked(character: Dictionary) -> bool:
	return character.get("ptr18") == null or int(character.get("byte10", 0)) != 0 or int(character.ptr18.get("i78", 0)) == 8

## 00CCF980: identity of selection+30 vs actor+F0 (not plain pointer equality).
static func identity_equal(left: Variant, right: Variant) -> bool:
	if left == null or right == null:
		return is_same(left, right)
	if is_same(left, right):
		return true
	if int(right.type24) != 0 and (int(right.i18) != 0 or int(right.i1C) != 0 or int(right.i20) != 0):
		return int(left.type24) == int(right.type24) and int(left.i18) == int(right.i18) and int(left.i1C) == int(right.i1C) \
			and int(left.i20) == int(right.i20) and str(left.name10) == str(right.name10)
	return int(left.type24) == 0 or (int(left.i18) == 0 and int(left.i1C) == 0 and int(left.i20) == 0)

## env: {"selection30": identity, "color_rows": {id: {"ColorTableID"}}, "npc_predicate": Callable(actor)->bool}
static func predicate(pair: Dictionary, actor: Dictionary, env: Dictionary) -> bool:
	var t: int = C.i32(int(actor.identity.type24))
	var ch: Variant = actor.get("character")
	match str(pair.kind):
		"identity":
			return t == int(pair.type) and identity_equal(env.get("selection30"), actor.identity)
		"b8_zero":
			return t == int(pair.type) and C.i32(int(actor.b8)) == 0
		"b8_not_minus1":
			return t == int(pair.type) and C.i32(int(actor.b8)) != -1
		"npc":
			return bool((env.npc_predicate as Callable).call(actor)) if env.has("npc_predicate") else false
		"byte7e":
			return (ch == null or not blocked(ch)) and t == int(pair.type) and int(actor.get("byte7e", 0)) != 0
		"byte7f":
			return (ch == null or not blocked(ch)) and t == int(pair.type) and int(actor.get("byte7f", 0)) != 0
		"elven":
			var color_row: Variant = (env.get("color_rows", {}) as Dictionary).get(COLOR_ROW_ELVEN_GATE)
			return t == int(pair.type) and ch != null and not blocked(ch) and color_row != null \
				and C.i32(int(color_row.ColorTableID)) != 0 and int(ch.get("byteE4", 0)) != 0
	return false

## 02159930: UIOutlineRef registry/table/row missing -> 0.
static func resolve_ref(ref_rows: Variant, key: int) -> int:
	if ref_rows == null:
		return 0
	var idx: int = C.lower_bound_exact(ref_rows, func(r: Dictionary) -> Array: return [int(r.ID)], [key])
	return C.i32(int(ref_rows[idx].UIOutlineID)) if idx >= 0 else 0

## refresh: every reached predicate is invoked separately (no caching; 9 and 10 are both called
## when 9 is false). First true -> resolver once -> apply, even for id 0. All false -> remove.
static func refresh(actor: Dictionary, env: Dictionary) -> Dictionary:
	var calls: Array = []
	for pair: Dictionary in PAIRS:
		calls.append(int(pair.priority))
		if predicate(pair, actor, env):
			var id: int
			if pair.ref == null:
				id = int((env.npc_resolver as Callable).call(actor)) if env.has("npc_resolver") else 0
			else:
				id = resolve_ref(env.get("ref_rows"), int(pair.ref))
			apply_outline(actor, id)
			return {"selected_priority": int(pair.priority), "outline_id": id, "predicate_calls": calls}
	remove_outline(actor)
	return {"selected_priority": null, "outline_id": null, "predicate_calls": calls}

static func apply_outline(actor: Dictionary, id: int) -> void:
	if actor.get("framecell") != null:
		actor.framecell["attr"] = int(actor.framecell.get("attr", 0)) | ATTR_OUTLINE
	actor["attr134"] = int(actor.get("attr134", 0)) | ATTR_OUTLINE
	if not actor.has("effect_map"):
		actor["effect_map"] = {}
	actor.effect_map[EFFECT_KEY_OUTLINE] = id
	if actor.get("associated") != null:
		apply_outline(actor.associated, id)

static func remove_outline(actor: Dictionary) -> void:
	if actor.get("framecell") != null:
		actor.framecell["attr"] = int(actor.framecell.get("attr", 0)) & ~ATTR_OUTLINE
	actor["attr134"] = int(actor.get("attr134", 0)) & ~ATTR_OUTLINE
	(actor.get("effect_map", {}) as Dictionary).erase(EFFECT_KEY_OUTLINE)  # key 5 untouched
	if actor.get("associated") != null:
		remove_outline(actor.associated)

## ---------------- colour manager (01944760 / 02207EB0) ----------------

## 0215C380 for well-formed values: drop ONE leading '#'; 3 pairs RGB; 4 pairs A,R,G,B; else 0.
static func parse_color(value: String) -> Array:
	var s: String = value.substr(1) if value.begins_with("#") else value
	var pairs: Array = []
	var i: int = 0
	while i + 1 < s.length():
		pairs.append(s.substr(i, 2).hex_to_int())
		i += 2
	if pairs.size() == 3:
		return [pairs[0], pairs[1], pairs[2]]
	if pairs.size() == 4:
		return [pairs[1], pairs[2], pairs[3]]  # Color3B drops A
	return [0, 0, 0]

## 0213EB90: direct ColorTableID lookup; missing -> Color4B(0,0,0,0) -> RGB 0. No Color alias hop.
static func color_from_table(color_table: Dictionary, table_id: int) -> Array:
	var row: Variant = color_table.get(table_id)
	return [0, 0, 0] if row == null else parse_color(str(row.Value))

## 035F5B30
static func rgb565(r: int, g: int, b: int) -> int:
	var cx: int = C.u16((C.u16(r) & 0xFFF8) << 5)
	var ax: int = C.u16((cx | C.u16(g)) & 0xFFFC)
	return C.u16(C.u16(ax << 3) | C.u16(C.i32(b) >> 3))

## 021F2B90: integer step floor(|b-a|/5) per channel; not floating interpolation.
@warning_ignore("integer_division")
static func color_vector(a: Array, b: Array, include_min: bool) -> Array:
	var d: Array = []
	for ch: int in 3:
		d.append(absi(int(b[ch]) - int(a[ch])) / 5)
	if not include_min:
		var v: Array = []
		for k: int in 5:
			v.append(rgb565(absi(int(b[0]) - k * int(d[0])), absi(int(b[1]) - k * int(d[1])), absi(int(b[2]) - k * int(d[2]))))
		return v + [v[3], v[2], v[1]]
	var out: Array = []
	var lo: Array = [mini(a[0], b[0]), mini(a[1], b[1]), mini(a[2], b[2])]
	var hi: Array = [maxi(a[0], b[0]), maxi(a[1], b[1]), maxi(a[2], b[2])]
	for k: int in 5:
		out.append(rgb565(absi(int(hi[0]) - k * int(d[0])), absi(int(hi[1]) - k * int(d[1])), absi(int(hi[2]) - k * int(d[2]))))
	for k: int in 5:
		out.append(rgb565(int(lo[0]) + k * int(d[0]), int(lo[1]) + k * int(d[1]), int(lo[2]) + k * int(d[2])))
	return out

## 021F2960
@warning_ignore("integer_division")
static func alpha_vector(a: int, b: int) -> Array:
	var lo: int = clampi(mini(a, b), 0, 100)
	var hi: int = clampi(maxi(a, b), 0, 100)
	var d: int = (hi - lo) / 5
	var out: Array = []
	for k: int in 5:
		out.append(absi(hi - k * d))
	for k: int in 5:
		out.append(lo + k * d)
	return out

## Builds the three maps. Duplicate ids keep the FIRST entry; the maps are not cleared first.
static func build_manager(outline_rows: Array, color_table: Dictionary, manager: Dictionary = {}) -> Dictionary:
	for key: String in ["color", "alpha", "period"]:
		if not manager.has(key):
			manager[key] = {}
	for row: Dictionary in outline_rows:
		var id: int = int(row.ID)
		if not (manager.color as Dictionary).has(id):
			manager.color[id] = color_vector(color_from_table(color_table, int(row.MinColorTableID)), color_from_table(color_table, int(row.MaxColorTableID)), bool(row.IsIncludeMinColor))
		if C.i32(int(row.MinAlpha)) >= 0 and C.i32(int(row.MaxAlpha)) >= 0 and not (manager.alpha as Dictionary).has(id):
			manager.alpha[id] = alpha_vector(int(row.MinAlpha), int(row.MaxAlpha))
		if C.i32(int(row.Period)) > 0 and not (manager.period as Dictionary).has(id):
			manager.period[id] = C.u16(int(row.Period))  # low16: 65536 -> 0
	return manager

## 02200820: absent -> 100, else WORD zero-extended.
static func period(manager: Dictionary, id: int) -> int:
	return int((manager.period as Dictionary).get(id, DEFAULT_PERIOD))

## nonempty sample index = (signed64 clock / signed32 divisor) % signed32 count (signed IDIV).
static func sample(vector: Variant, clock: int, divisor: int, default_value: int) -> Dictionary:
	if vector == null or (vector as Array).is_empty():
		return {"value": default_value}
	if divisor == 0:
		return {"value": null, "outcome": C.UNGUARDED_BOUNDARY}  # IDIV 0 remains a boundary
	var idx: int = C.rem_trunc(C.div_trunc(clock, C.i32(divisor)), (vector as Array).size())
	if idx < 0:
		return {"value": null, "outcome": C.EVIDENCE_UNKNOWN}  # negative clock is outside the contract
	return {"value": vector[idx], "index": idx}

static func alpha_at(manager: Dictionary, id: int, clock: int) -> Dictionary:
	return sample((manager.alpha as Dictionary).get(id), clock, period(manager, id), DEFAULT_ALPHA)

static func color_at(manager: Dictionary, id: int, clock: int) -> Dictionary:
	return sample((manager.color as Dictionary).get(id), clock, period(manager, id), DEFAULT_COLOR)
