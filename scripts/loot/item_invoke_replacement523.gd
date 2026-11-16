extends RefCounted
## 신화 무기 발동 교체 (ItemBonus `ItemInvokeReplacementID`, 48종) — TWILIGHT 근사(근거 약함),
## 지시 2026-11-16. docs/items523_remaining_missing_rules.md 10.2.
## The tables give, per slot (ItemInvokeReplacementEntityView.SlotNumber), the candidate
## bonus groups and their Prob (1/1,000,000); each group's ItemInvokeReplacementBonus rows
## are InvokeOption rows (Value = chance, target = InvokeOption ID) per EnchantLevel.
## The tables do not say WHEN a slot is drawn or what a redraw costs. Approximation:
## each physical item draws every slot once, the first time it is seen (acquisition),
## kept under its own save key; no redraw (no consumer named in the tables).
## The drawn invokes join the item's existing equipment invokes in
## patch523_equipment_combat.active (same strongest-per-option rule), at the highest
## EnchantLevel row not above the item's level.
const SAVE_KEY := "item_invoke523"
const SCHEMA := 1
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ENABLED := true
const KINDS := {1:"attack_source_spell",61:"defence_fixed_counter",3:"attack_fixed_damage",5:"defence_flat_reduction",6:"attack_weapon_scale"}

var world: Node = null
var state: Dictionary = {"schema":SCHEMA,"rolled":{}}
var _elapsed: float = 0.0
var _replacement_cache: Dictionary = {}

func configure(owner: Node) -> void:
	world = owner

func export_state() -> Dictionary:
	return state.duplicate(true)

func import_state(value: Variant) -> void:
	state = {"schema":SCHEMA,"rolled":{}}
	if value is Dictionary and value.get("rolled") is Dictionary:
		for uid: Variant in value.rolled:
			var slots: Variant = value.rolled[uid]
			if not slots is Dictionary: continue
			var clean: Dictionary = {}
			for slot: Variant in slots:
				if typeof(slots[slot]) in [TYPE_INT,TYPE_FLOAT]: clean[str(slot)] = int(slots[slot])
			state.rolled[str(uid)] = clean

## ItemInvokeReplacementID of an original record (0 = none).
func replacement_id(record: Dictionary) -> int:
	var id: int = int(record.get("source_item_class_id",0))
	if id <= 0 or record.get("source_m_native_item") != true: return 0
	if _replacement_cache.has(id): return int(_replacement_cache[id])
	var found: int = 0
	for row: Dictionary in D.item_definition(record).get("item_bonus",[]):
		if str(row.get("bonus_type",{}).get("Name","")) == "ItemInvokeReplacementID" and row.get("IsPossession") != true:
			var value: Variant = row.get("bonus",{}).get("Value")
			if typeof(value) in [TYPE_INT,TYPE_FLOAT] and float(value) > 0: found = int(value)
	_replacement_cache[id] = found
	return found

## One weighted draw per slot (Prob over its own slot total).
func draw(replacement: int, rng: RandomNumberGenerator) -> Dictionary:
	var slots: Dictionary = {}
	for row: Dictionary in SOURCE.related("ItemInvokeReplacementEntityView","ItemInvokeReplacementID",replacement):
		var slot: String = str(int(row.get("SlotNumber",0)))
		if not slots.has(slot): slots[slot] = []
		slots[slot].append(row)
	var out: Dictionary = {}
	for slot: String in slots:
		var total: int = 0
		for row: Dictionary in slots[slot]: total += maxi(0,int(row.get("Prob",0)))
		if total <= 0: continue
		var roll: int = rng.randi_range(0,total-1)
		var upper: int = 0
		for row: Dictionary in slots[slot]:
			upper += maxi(0,int(row.get("Prob",0)))
			if roll < upper: out[slot] = int(row.ItemInvokeReplacementBonusGroupID); break
	return out

## Draws for items not yet drawn. Returns true when the ledger changed.
func sync() -> bool:
	if not ENABLED or world == null: return false
	var changed: bool = false
	for uid: Variant in world.item_instances:
		var physical: Variant = world.item_instances[uid]
		if not physical is Dictionary or not (physical as Dictionary).get("record") is Dictionary: continue
		if state.rolled.has(str(uid)): continue
		var replacement: int = replacement_id(physical.record)
		if replacement <= 0: continue
		state.rolled[str(uid)] = draw(replacement, world.rng)
		changed = true
	for uid: String in state.rolled.keys():
		if not world.item_instances.has(uid): state.rolled.erase(uid); changed = true
	return changed

func tick(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0: return
	_elapsed = 0.0
	if sync() and world.has_method("_request_deferred_save"): world._request_deferred_save()

## The drawn invoke effects of one physical item at its enchant level, in the
## shape patch523_equipment_combat.level_effects returns.
func effects(uid: String, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not ENABLED: return out
	var slots: Dictionary = state.rolled.get(uid, {})
	for slot: String in slots:
		var group: int = int(slots[slot])
		var best: Dictionary = {}
		for row: Dictionary in SOURCE.related("ItemInvokeReplacementBonus","ItemInvokeReplacementBonusGroupID",group):
			var at: int = int(row.get("EnchantLevel",0))
			if at > level or (not best.is_empty() and at < int(best.get("EnchantLevel",0))): continue
			best = row
		if best.is_empty(): continue
		for row: Dictionary in SOURCE.related("ItemInvokeReplacementBonus","ItemInvokeReplacementBonusGroupID",group):
			if int(row.get("EnchantLevel",0)) != int(best.EnchantLevel): continue
			var bonus: Dictionary = SOURCE.row("Bonus", int(row.get("BonusID",0)))
			if str(SOURCE.row("BonusType", int(bonus.get("BonusTypeID",0))).get("Name","")) != "InvokeOption" or int(bonus.get("BonusApplicationTypeID",0)) != 10: continue
			var option: Dictionary = SOURCE.row("InvokeOption", int(bonus.get("BonusApplicationTargetID",0)))
			var kind: int = int(option.get("InvokeOptionTypeID",0))
			if option.is_empty() or not KINDS.has(kind): continue
			var effect: Dictionary = {"kind":KINDS[kind],"probability":int(bonus.get("Value",0)),"row_id":int(row.ID),"option":option.duplicate(true),"option_id":int(option.ID),"approx_replacement_slot":int(slot),"approx_replacement_group":group}
			if kind == 1:
				effect["spell_name"] = str(SOURCE.row("SpellClass", int(option.get("Param1",0))).get("Name",""))
			out.append(effect)
	return out

## Names of the drawn groups (for the item tooltip / evidence).
func drawn_names(uid: String) -> Array:
	var names: Array = []
	var slots: Dictionary = state.rolled.get(uid, {})
	var keys: Array = slots.keys(); keys.sort()
	for slot: String in keys: names.append(str(SOURCE.row("ItemInvokeReplacementBonusGroup", int(slots[slot])).get("Name","")))
	return names
