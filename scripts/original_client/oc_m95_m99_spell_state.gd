extends RefCounted
## M95 stackable local admission, M97 Bonus list producer, M99 packet363 counter store (C20/C04/C15/C17).
## DESIGN_NOT_RECOVERED_API. Client-local reads only: server combat eligibility, damage, drop and
## spawn rules are NOT decided here. Every getter does its own remap and lookup (no snapshot).
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")
const TYPE_IS_STACKABLE := 9492      # 0x2514
const TYPE_STACKABLE_MAX := 9482     # 0x250A
const RESULT_CURRENT_NOT_POSITIVE := 0xD1DA
const RESULT_ACTIVE_AT_MAX := 0xD1E4

## World model used by the getters:
##  remap: Array of [from, to] records (stride 0x1C list order, restart after each hit)
##  tree188: Dictionary signed key -> {"current": i32 (+20), "packet_max": i32 (+24), "active": i32 (+28)}
##  bonus_lists: Dictionary spell id -> Array of Bonus IDs (cache_list order)
##  bonus_rows: Dictionary Bonus ID -> {"type": int, "value": i32}; registry_present: bool
static func remap_id(world: Dictionary, id: int, trace: Array) -> Dictionary:
	trace.append("remap_id(%d)" % id)
	var records: Array = world.get("remap", [])
	if records.is_empty():
		return {"id": id}
	var seen := {id: true}
	var cur: int = id
	var restarted := true
	while restarted:
		restarted = false
		for rec: Array in records:
			if V.u32(int(rec[0])) == V.u32(cur):
				cur = int(rec[1])
				if seen.has(cur):
					return {"id": null, "status": V.REJECTED_UNDEFENDED, "note": "remap cycle: the native loop has no cycle detection; no reject/message path is invented"}
				seen[cur] = true
				restarted = true
				break
	return {"id": cur}

static func _node_field(world: Dictionary, id: int, field: String, trace: Array) -> Variant:
	var r: Dictionary = remap_id(world, id, trace)
	if r.id == null:
		return r
	trace.append("tree188_lookup(%d).%s" % [r.id, field])
	var tree: Dictionary = world.get("tree188", {})
	if not tree.has(V.i32(int(r.id))):
		return 0
	return V.i32(int(tree[V.i32(int(r.id))][field]))

## 0216A0C0 / 02156BE0: walk the cached Bonus list in order; a missing registry/table/row skips
## the item. membership ignores the value; max returns the FIRST matching value (0 counts).
static func bonus_property(world: Dictionary, id: int, type_id: int, membership: bool, trace: Array) -> Variant:
	var r: Dictionary = remap_id(world, id, trace)
	if r.id == null:
		return r
	trace.append("bonus_list(%d)" % r.id)
	for bonus_id: int in world.get("bonus_lists", {}).get(int(r.id), []):
		if not world.get("registry_present", true):
			continue
		var row: Variant = world.get("bonus_rows", {}).get(bonus_id)
		if row == null:
			continue
		if int(row.type) == type_id:
			return true if membership else V.i32(int(row.value))
	return false if membership else 0

## 0216364E..021636A6. Passing means "continue to the next validation", NOT final success.
static func stackable_admission(world: Dictionary, id: int) -> Dictionary:
	var trace: Array = []
	var member: Variant = bonus_property(world, id, TYPE_IS_STACKABLE, true, trace)
	if member is Dictionary:
		return {"result": "rejected_input", "detail": member, "trace": trace}
	if not member:
		return {"result": "continue_next_validation", "trace": trace}
	var a: Variant = _node_field(world, id, "current", trace)
	if a is Dictionary:
		return {"result": "rejected_input", "detail": a, "trace": trace}
	if int(a) <= 0:
		return {"result": "false", "byte0": 0, "code": RESULT_CURRENT_NOT_POSITIVE, "trace": trace}
	var c: Variant = _node_field(world, id, "active", trace)
	var m: Variant = bonus_property(world, id, TYPE_STACKABLE_MAX, false, trace)
	if c is Dictionary or m is Dictionary:
		return {"result": "rejected_input", "trace": trace}
	if int(c) >= int(m):
		return {"result": "false", "byte0": 0, "code": RESULT_ACTIVE_AT_MAX, "trace": trace}
	return {"result": "continue_next_validation", "trace": trace}

# ---------------------------------------------------------------- M97
## 02109F90 construct: SpellBonus equal-key rows in native row order -> first Bonus lower_bound
## by BonusID -> append payload pointer. Missing Bonus skips. Duplicates kept. MinSpellLevel is
## never read on this path.
static func build_bonus_vector(spell_id: int, spell_bonus_rows: Array, bonus_table: Dictionary, registry_present: bool = true) -> Dictionary:
	var vec: Array = []
	var read_fields: Array = []
	if not registry_present:
		return {"vector8": vec, "read_fields": read_fields}
	for link: Dictionary in spell_bonus_rows:
		if V.i32(int(link.spell_id)) != V.i32(spell_id):
			continue
		read_fields.append("BonusID")
		var b: Variant = bonus_table.get(int(link.bonus_id))
		if b == null:
			continue
		vec.append(b)
	return {"vector8": vec, "read_fields": read_fields}

## M95 cache miss filled from manager+D0 (borrowed object+8 vector). A miss of the manager entry
## caches an EMPTY list; later hits return the cached list even if tables changed (stale).
static func cache_list(cache: Dictionary, manager_d0: Dictionary, spell_id: int) -> Dictionary:
	if cache.has(spell_id):
		return {"list": cache[spell_id], "hit": true, "producer_called": false}
	var ids: Array = []
	var obj: Variant = manager_d0.get(spell_id)
	if obj != null:
		for payload: Dictionary in obj.vector8:
			ids.append(int(payload.id))
	cache[spell_id] = ids
	return {"list": ids, "hit": false, "producer_called": true}

# ---------------------------------------------------------------- M99
const TREE188_LIMIT := 0x0555555555555555

## 02194EB0: hit overwrites +20/+24/+28 in place (no count change); miss inserts. Zero is a value,
## not an erase; negatives are kept (no clamp). The size guard applies to a MISS only.
static func counter_write(tree: Dictionary, raw_key: int, current: int, maximum: int, active: int) -> Dictionary:
	var k: int = V.i32(raw_key)
	if tree.has(k):
		tree[k] = {"current": V.i32(current), "packet_max": V.i32(maximum), "active": V.i32(active)}
		return {"inserted": false}
	if tree.size() == TREE188_LIMIT:
		return {"inserted": false, "status": "size_error_helper_requested"}
	tree[k] = {"current": V.i32(current), "packet_max": V.i32(maximum), "active": V.i32(active)}
	return {"inserted": true}

## 02469C70 handler: the writer runs with the RAW msg dword10 (no remap/validity gate), THEN the
## event 8A1 {spellId} is prepared and requested. Repeated identical values still dispatch.
static func handle_packet363(tree: Dictionary, msg: Dictionary, event_alloc_ok: bool = true) -> Dictionary:
	var ev: Array = []
	counter_write(tree, int(msg.dword10), int(msg.dword14), int(msg.dword18), int(msg.dword1C))
	ev.append("writer")
	ev.append("map{spellId:%d}" % V.i32(int(msg.dword10)))
	ev.append("sink(event8A1)" if event_alloc_ok else "sink(null_event)")
	return {"events": ev, "rollback": false}

## 02156B60: remapped key, node+24, missing -> 0 (present-zero and absent both return 0).
static func packet_max_get(world: Dictionary, requested_id: int) -> Dictionary:
	var trace: Array = []
	var v: Variant = _node_field(world, requested_id, "packet_max", trace)
	return {"value": v, "trace": trace}

## event529 0219ED90: all-clear (not proof of every logout/reconnect trigger).
static func reset529(tree: Dictionary) -> void:
	tree.clear()

## 00319EF0 parser projection: only encountered known fields are stored (last one wins);
## absent fields keep the fresh-construction 0. Unknown/wire-type behaviour is not modelled.
static func parse363(fields_in_wire_order: Array) -> Dictionary:
	var msg := {"dword10": 0, "dword14": 0, "dword18": 0, "dword1C": 0}
	var by_tag := {0x08: "dword10", 0x10: "dword14", 0x18: "dword18", 0x20: "dword1C"}
	for f: Array in fields_in_wire_order:
		if by_tag.has(int(f[0])):
			msg[by_tag[int(f[0])]] = V.i32(int(f[1]))
	return msg
