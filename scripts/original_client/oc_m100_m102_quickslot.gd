extends RefCounted
## M100 quickslot count display (event 8A1 -> refresh -> set_count), M102 corrected_v2 packet370
## ammo/reload (C20/C17/C11/C04). DESIGN_NOT_RECOVERED_API.
## SpellManager+188 counters (M99), +D0 Bonus lists (M97), +90 reload pairs and +C0 ammo counts
## are FOUR different stores. Every slot/metadata/BulletID read is a separate observation:
## the world model counts reads and lets a test mutate state between them.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")
const EVENT_ON := 0x9EE
const EVENT_OFF := 0x9EF
const MAPPING_ROW_BULLET_ID := 0x24      # payload(row+8)+0x1C
const LOADED_ROW_WITHOUT_AMMO := 0x28    # payload(row+8)+0x20  (NOT full-row+0x20)

## world keys:
##  slots: Dictionary bucket*1000+index -> slot {"metadata_id": int|null, "dword10": int, "is_spell": bool}
##  remap: Callable(id)->id (identity if absent); stackable: Callable(id)->bool; stack_count: Callable(id)->int
##  mapping_rows: Dictionary raw key -> PackedByteArray full row (BulletID at +0x24)
##  loaded_rows: Dictionary bullet id -> PackedByteArray full row (flag byte at +0x28)
##  service_c0: Dictionary bullet id -> i32 count; reload_90: Dictionary id -> [remain_i64, total_i64]
##  reads: Array (observation log); on_read: Callable(world, what) optional mutation hook
static func _observe(world: Dictionary, what: String) -> void:
	(world.reads as Array).append(what)
	var hook: Variant = world.get("on_read")
	if hook is Callable and (hook as Callable).is_valid():
		(hook as Callable).call(world, what)

static func _slot(world: Dictionary, bucket: int, index: int, tag: String) -> Variant:
	_observe(world, tag)
	return world.slots.get(bucket * 1000 + index)

static func _remap(world: Dictionary, id: int) -> int:
	var f: Variant = world.get("remap")
	return int((f as Callable).call(id)) if f is Callable else id

static func _bullet_id(world: Dictionary, raw_key: int, tag: String) -> Variant:
	_observe(world, tag)
	var row: Variant = world.mapping_rows.get(V.i32(raw_key))
	if row == null:
		return null
	return (row as PackedByteArray).decode_s32(MAPPING_ROW_BULLET_ID)

## 00C0EA70 get-or-create: a miss INSERTS 0 (normal allocator assumed).
static func ammo_get_or_create(service_c0: Dictionary, id: int) -> int:
	var k: int = V.i32(id)
	if not service_c0.has(k):
		service_c0[k] = 0
	return int(service_c0[k])

## Event 8A1 -> per item: first slot lookup, compare remap(metadata ID) with payload spellId.
## Missing "spellId" gives 0. Metadata null is not guarded by the original (rejected here).
static func on_event_8A1(world: Dictionary, payload: Dictionary, items: Array) -> Dictionary:
	var spell_id: int = V.i32(int(payload.get("spellId", 0)))
	var refreshed: Array = []
	for item: Dictionary in items:
		var s: Variant = _slot(world, int(item.bucket), int(item.index), "first_slot")
		if s == null or not bool(s.get("is_spell", false)):
			continue
		if s.metadata_id == null:
			return {"status": V.REJECTED_UNDEFENDED, "note": "metadata null is not guarded"}
		_observe(world, "first_metadata")
		if _remap(world, int(s.metadata_id)) == spell_id:
			refreshed.append(refresh(world, item))
	return {"spell_id": spell_id, "refreshed": refreshed}

## 031F9B60 selected spell-count slice.
static func refresh(world: Dictionary, item: Dictionary) -> Dictionary:
	var count: int = 0
	var flag34: int = 0
	var flag35: int = 0
	var s: Variant = _slot(world, int(item.bucket), int(item.index), "second_slot")
	if s != null and bool(s.get("is_spell", false)):
		if s.metadata_id != null:
			_observe(world, "second_metadata")
			var raw_id: int = int(s.metadata_id)
			if (world.stackable as Callable).call(raw_id):
				count = int((world.stack_count as Callable).call(raw_id))
		var key: int = int(s.dword10)
		var b1: Variant = _bullet_id(world, key, "bullet_read_1")
		if b1 != null:
			var loaded: Variant = world.loaded_rows.get(int(b1))
			if loaded == null:
				return {"status": V.REJECTED_UNDEFENDED, "note": "LoadedSpellBullet miss is unguarded at 031FA7FD"}
			flag35 = 1 if (loaded as PackedByteArray)[LOADED_ROW_WITHOUT_AMMO] != 0 else 0
			var _b2: Variant = _bullet_id(world, key, "bullet_read_2")
			var b3: Variant = _bullet_id(world, key, "bullet_read_3")
			count = ammo_get_or_create(world.service_c0, int(b3))
			flag34 = 1
			return set_count(item, count, flag34, flag35, {"bullet_read_1": b1, "bullet_read_3": b3})
	return set_count(item, count, flag34, flag35, {})

## 03216030: formatter mode1 with the sign-extended count (no clamp; the formatter output is not
## assumed to be plain decimal). flag35 hides first; flag35==0 requests 9EF then writes visible.
static func set_count(item: Dictionary, count: int, flag34: int, flag35: int, reads: Dictionary) -> Dictionary:
	var ops: Array = [["formatter", 1, V.i32(count)], ["Text108.setString"]]
	if flag35 != 0:
		ops.append(["Nd_Count.visible", false])
		if flag34 != 0:
			ops.append(["publish", EVENT_ON if V.i32(count) > 0 else EVENT_OFF])
	else:
		ops.append(["publish", EVENT_OFF])
		ops.append(["Nd_Count.visible", flag34 != 0 or V.i32(count) > 0])
	return {"count": V.i32(count), "flag34": flag34, "flag35": flag35, "ops": ops, "reads": reads, "render_status": V.NOT_OBSERVED}

# ---------------------------------------------------------------- M102
## 024684D0: four packet fields to a DynamicMap, request event 92D. Field5 (+20) is not carried.
static func packet370_callback(native: Dictionary) -> Dictionary:
	return {"event": 0x92D, "map": {"bulletId": V.i32(int(native.dword10)), "bulletCount": V.i32(int(native.dword14)),
		"reloadRemainTime": V.i32(int(native.dword18)), "reloadTotalTime": V.i32(int(native.dword1C))}}

## 031B8C20: cast null returns; missing keys read 0; reload pair (+90) FIRST, then ammo (+C0)
## replace (zero/negative kept, no erase/clamp/remap), then traverse the slots.
static func receive_92D(world: Dictionary, event: Variant, items: Array) -> Dictionary:
	if event == null:
		return {"order": []}
	var m: Dictionary = (event as Dictionary).map
	var id: int = V.i32(int(m.get("bulletId", 0)))
	var cnt: int = V.i32(int(m.get("bulletCount", 0)))
	var remain: int = V.i32(int(m.get("reloadRemainTime", 0)))
	var total: int = V.i32(int(m.get("reloadTotalTime", 0)))
	var order: Array = []
	world.reload_90[id] = [remain, total]
	order.append("write_reload_90")
	world.service_c0[id] = cnt
	order.append("write_ammo_C0")
	var refreshed: Array = []
	for item: Dictionary in items:
		var r: Variant = slot_refresh_92D(world, item, id)
		if r != null:
			refreshed.append(r)
	order.append("traverse")
	return {"order": order, "refreshed": refreshed}

## 03181EC0: raw slot key -> mapping payload; bullet1 must equal capture id; flag from loaded
## payload+20 (= full row +0x28); bullet2 / bullet3 are fresh reads.
static func slot_refresh_92D(world: Dictionary, item: Dictionary, capture_id: int) -> Variant:
	var s: Variant = _slot(world, int(item.bucket), int(item.index), "slot")
	if s == null or not bool(s.get("is_spell", false)):
		return null
	var key: int = int(s.dword10)
	var b1: Variant = _bullet_id(world, key, "bullet_read_1")
	if b1 == null or int(b1) != capture_id:
		return null
	var loaded: Variant = world.loaded_rows.get(int(b1))
	if loaded == null:
		return {"status": V.REJECTED_UNDEFENDED, "note": "flag payload has no null guard"}
	var flag: int = (loaded as PackedByteArray)[LOADED_ROW_WITHOUT_AMMO]
	var _b2: Variant = _bullet_id(world, key, "bullet_read_2")
	var target: String = "item+118" if flag != 0 else "item+110"
	var b3: Variant = _bullet_id(world, key, "bullet_read_3")
	var count: int = ammo_get_or_create(world.service_c0, int(b3))
	var sc: Dictionary = set_count(item, count, 1, 1 if flag != 0 else 0, {"bullet_read_1": b1, "bullet_read_3": b3})
	sc["progress_target"] = target
	return sc
