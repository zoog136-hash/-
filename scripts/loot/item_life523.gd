extends RefCounted
## 원본 523 ItemBonus `Life`(초) — 획득 후 수명 (TWILIGHT 근사, 사용자 지시 2026-11-16).
## The tables give the lifetime but no acquisition clock. This ledger keeps the
## acquisition time (unix seconds) per physical item ID under its own save key:
##  - an item with a Life row gets its time the first time it is seen (a new
##    grant within one tick; an item already in an older save gets the load time);
##  - when real time passes acquisition + Life the item is removed (equipped
##    items included: they are taken off first) and the change is saved.
## docs/items523_remaining_missing_rules.md 19.
const SAVE_KEY := "item_life523"
const SCHEMA := 1
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const ENABLED := true

var world: Node = null
var state: Dictionary = {"schema":SCHEMA,"acquired":{}}
var _life_cache: Dictionary = {}
var _elapsed: float = 0.0

func configure(owner: Node) -> void:
	world = owner

func export_state() -> Dictionary:
	return state.duplicate(true)

func import_state(value: Variant) -> void:
	state = {"schema":SCHEMA,"acquired":{}}
	if value is Dictionary and value.get("acquired") is Dictionary:
		for key: Variant in value.acquired:
			var at: Variant = value.acquired[key]
			if typeof(at) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(at)) and float(at) > 0: state.acquired[str(key)] = int(at)

static func now() -> int:
	return int(Time.get_unix_time_from_system())

## Life seconds of an original item record (0 = no Life row).
func life_seconds(record: Dictionary) -> int:
	var id: int = int(record.get("source_item_class_id", 0))
	if id <= 0 or record.get("source_m_native_item") != true: return 0
	if _life_cache.has(id): return int(_life_cache[id])
	var seconds: int = 0
	for row: Dictionary in D.item_definition(record).get("item_bonus", []):
		if str(row.get("bonus_type",{}).get("Name","")) == "Life" and str(row.get("unit",{}).get("Name","")) == "Seconds":
			var value: Variant = row.get("bonus",{}).get("Value")
			if typeof(value) in [TYPE_INT,TYPE_FLOAT] and float(value) > 0: seconds = int(value)
	_life_cache[id] = seconds
	return seconds

static func has_life_row(record: Dictionary) -> bool:
	for row: Dictionary in D.item_definition(record).get("item_bonus", []):
		if str(row.get("bonus_type",{}).get("Name","")) == "Life": return true
	return false

## Seconds left for one physical item (-1 when it has no lifetime).
func remaining(uid: String, at: int = -1) -> int:
	var physical: Variant = world.item_instances.get(uid)
	if not physical is Dictionary: return -1
	var life: int = life_seconds((physical as Dictionary).get("record", {}))
	if life <= 0: return -1
	var start: int = int(state.acquired.get(uid, now() if at < 0 else at))
	return maxi(0, start + life - (now() if at < 0 else at))

## Stamps unseen Life items and forgets removed ones. Returns true if changed.
func sync(at: int = -1) -> bool:
	if not ENABLED or world == null: return false
	var stamp: int = now() if at < 0 else at
	var changed: bool = false
	for key: Variant in world.item_instances:
		var physical: Variant = world.item_instances[key]
		if not physical is Dictionary or not (physical as Dictionary).get("record") is Dictionary: continue
		if life_seconds(physical.record) <= 0 or state.acquired.has(str(key)): continue
		state.acquired[str(key)] = stamp; changed = true
	for key: String in state.acquired.keys():
		if not world.item_instances.has(key): state.acquired.erase(key); changed = true
	return changed

## Removes expired items. Returns the removed names.
func sweep(at: int = -1) -> Array:
	var removed: Array = []
	if not ENABLED or world == null: return removed
	var moment: int = now() if at < 0 else at
	for key: String in state.acquired.keys():
		var physical: Variant = world.item_instances.get(key)
		if not physical is Dictionary: continue
		var life: int = life_seconds((physical as Dictionary).get("record", {}))
		if life <= 0 or int(state.acquired[key]) + life > moment: continue
		for slot: Variant in world.equipped_items.keys():
			var worn: Variant = world.equipped_items[slot]
			if worn is Dictionary and str((worn as Dictionary).get("instance_id","")) == key: world.equipped_items[slot] = {}
		var name_value: String = str(physical.get("name",""))
		var held: Dictionary = STACK.proof(world, key)
		world.item_instances.erase(key)
		var quantity: int = int(held.get("remaining", 1)) if not held.is_empty() else 1
		var count: int = int(world.inventory.get(name_value, 0)) - quantity
		if count > 0: world.inventory[name_value] = count
		else: world.inventory.erase(name_value)
		state.acquired.erase(key)
		removed.append(name_value)
	return removed

## Called by the world clock (about once per second).
func tick(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0: return
	_elapsed = 0.0
	sync()
	var removed: Array = sweep()
	if removed.is_empty(): return
	if world.has_method("_invalidate_equipment_static"): world._invalidate_equipment_static()
	if world.hud != null:
		world.hud.refresh_inventory(world.inventory)
		world.hud.show_message("수명이 끝난 아이템이 사라졌습니다 · " + ", ".join(PackedStringArray(removed)))
	world._update_hud()
	world._save_game(true)
