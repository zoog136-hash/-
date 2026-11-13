extends SceneTree
## Original 523 equipment base rows connected from the tables in actual Main:
## - ElementalResistance / ElementalDamage (BonusApplicationType 3, target =
##   ElementalType) -> element_resist_<channel> / source_elemental_flat_<channel>.
## - Direct typed rows (critical, critical resist, typed reduction %, evasion,
##   pierce, cast speed, ...) -> the record fields the enchantment projection
##   already writes, read by the existing combat stat owners.
## - EquipGroupID + EquipSlotConfig MaxDuplicationPer* -> equip refusal.
## physical grant -> equip -> stat -> save -> reload -> unequip. Without the
## original definition ZIP only the static rules are checked.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const F = preload("res://scripts/loot/current523_native_fields.gd")
const LIMIT = preload("res://scripts/loot/current523_equip_group_limit.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const COMBAT = preload("res://scripts/crafting/patch523_equipment_combat.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_EQUIP_TYPED_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(P.TYPED.get("RangeCritical")==["ranged_crit","ValuePercent"] and P.TYPED.get("MeleeCriticalResist")==["melee_critical_resistance","Percentage"] and P.TYPED.get("PVEDamageReductionPercent")==["pve_damage_reduction_pct","Percentage"], "typed rows reuse the enchantment record fields")
	check(not P.TYPED.has("FinalBlowProbability") and not P.TYPED.has("AttackDrainHP") and not P.TYPED.has("RegenHP"), "rows with their own owner are not duplicated")
	check(P.TYPED.get("PiercePVPDamageReduction")==["source_pvp_flat_reduction_ignore","Value"] and P.TYPED.get("PVPSpellByLevelAdditionLevel")==["source_pvp_status_success_level","Value"], "user decision 2026-11-13: base PVP rows use the enchant single-player fields")
	check(COMBAT.BASE_KEYS==["source_pvp_flat_reduction_ignore","source_pvp_status_success_level"], "only the two PVP keys are read from base rows")
	check(LIMIT.enforce_loaded(null,{"schema":1,"applied":true,"released":[]})=={"schema":1,"applied":true,"released":[]}, "a saved marker is returned unchanged (applied once)")
	for key: String in P.TYPED: check(not P.FLAT.has(key), "typed key %s is not also a flat Value row" % key)
	check(P.ELEMENT_CHANNELS=={"Fire":"fire","Water":"water","Air":"wind","Earth":"earth"}, "ElementalType names -> existing NPC spell channels")
	# Synthetic duplication check (no table needed beyond the group logic).
	var a: Dictionary = {"source_m_native_item":true,"source_item_class_id":1,"source_equip_group_ids":[128.0,148.0]}
	var b: Dictionary = {"source_m_native_item":true,"source_item_class_id":2,"source_equip_group_ids":[128,138]}
	check(LIMIT.groups(a)==[128,148] and LIMIT.groups(b)==[128,138], "float group IDs compare as integers (#411)")
	check(LIMIT.reason({"source_m_native_item":false},"earring1",{})=="" and LIMIT.reason(a,"weapon",{})=="", "non-native or single slots are not limited")

func level_ok(world: Node, full: Dictionary) -> void:
	world.level = maxi(int(world.level),int(full.get("source_level_limit_min",0)))
	var classes: Array = full.get("source_class_names",[])
	if not classes.is_empty() and not classes.has(world.job_class): world.job_class = str(classes[0])

func usable(full: Dictionary, record: Dictionary) -> bool:
	return not record.get("source_delete_time_unresolved",false) and not full.has("source_delete_time_raw") and int(full.get("source_max_level_limit_max",0))==0 and int(full.get("source_level_limit_max",0))==0 and str(full.get("source_category_name",""))!="FishingRod"

func scan(world: Node) -> Dictionary:
	var fields: Dictionary = {}; var items: Dictionary = {}; var picks: Dictionary = {}; var groups: Dictionary = {}
	var typed_fields: Array = []
	for spec: Array in P.TYPED.values(): typed_fields.append(spec[0])
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item")!=true or not D.equipment(record): continue
		var full: Dictionary = F.full(record)
		var id: int = int(record.source_item_class_id)
		for applied: Dictionary in full.get("source_mapped_bonuses",[]):
			var field: String = str(applied.get("field",""))
			if not (field.begins_with("element_resist_") or field.begins_with("source_elemental_flat_") or field=="source_equip_group_ids" or field in typed_fields): continue
			fields[field] = int(fields.get(field,0))+1
			if not items.has(field): items[field] = {}
			items[field][id] = true
			if not usable(full,record): continue
			if field=="element_resist_earth" and not picks.has("resist") and int(full.get("source_level_limit_min",0))<=90: picks["resist"] = {"id":id,"field":field,"value":float(record.get(field,0)),"slot":str(record.slot)}
			if field=="source_elemental_flat_fire" and not picks.has("flat") and str(record.slot)=="weapon": picks["flat"] = {"id":id,"value":int(record.get(field,0))}
			if field=="ranged_crit" and not picks.has("ranged_crit"): picks["ranged_crit"] = {"id":id,"value":int(record.get(field,0)),"slot":str(record.slot)}
			if field=="melee_critical_resistance" and not picks.has("crit_resist"): picks["crit_resist"] = {"id":id,"value":float(record.get(field,0))}
			if field=="pve_damage_reduction_pct" and not picks.has("pve_pct"): picks["pve_pct"] = {"id":id,"value":float(record.get(field,0))}
		var passive: Dictionary = preload("res://scripts/loot/patch523_passive_items.gd").effects(record)
		if usable(full,record):
			if int(passive.get("RegenHP",0))>0 and not passive.has("AbsoluteRegenHP") and not picks.has("regen"): picks["regen"] = {"id":id,"value":int(passive.RegenHP)}
			if int(passive.get("AttackDrainHP",0))>0 and not picks.has("drain"): picks["drain"] = {"id":id,"value":int(passive.AttackDrainHP)}
		if record.has("source_equip_group_ids") and str(record.slot)=="earring" and usable(full,record):
			for group: Variant in record.source_equip_group_ids:
				if not groups.has(int(group)): groups[int(group)] = []
				groups[int(group)].append(id)
	var counts: Dictionary = {}
	for field: String in items: counts[field] = items[field].size()
	evidence["rows_by_field"] = fields; evidence["items_by_field"] = counts
	var resist_items: Dictionary = {}; var damage_items: Dictionary = {}
	for field: String in items:
		if field.begins_with("element_resist_"): resist_items.merge(items[field])
		if field.begins_with("source_elemental_flat_"): damage_items.merge(items[field])
	evidence["element_items"] = {"resistance":resist_items.size(),"damage":damage_items.size()}
	check(resist_items.size()==90, "90 items project ElementalResistance (%d) %s" % [resist_items.size(),JSON.stringify(counts)])
	check(damage_items.size()==46, "46 items project ElementalDamage (%d)" % damage_items.size())
	check(int(counts.get("source_equip_group_ids",0))==78, "78 equipment items carry EquipGroupID (%d)" % int(counts.get("source_equip_group_ids",0)))
	# A pair of different earrings sharing one group, and a third with none of it.
	for group: int in groups:
		if groups[group].size()>=2 and not picks.has("group"):
			for other: int in groups:
				if other==group: continue
				for candidate: int in groups[other]:
					if not picks.has("group") and not groups[group].has(candidate):
						var record_c: Dictionary = world._catalog_item_from_source_id("m523:item:"+str(candidate))
						var shared: bool = false
						for g: Variant in record_c.get("source_equip_group_ids",[]): if int(g)==group: shared = true
						if not shared: picks["group"] = {"group":group,"a":groups[group][0],"b":groups[group][1],"free":candidate}
	return picks

func fresh_grant(world: Node, ids: Array) -> Array[String]:
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.inventory = {}; world.item_instances = {}
	var lines: Array = []
	for id: Variant in ids: lines.append({"item_class_id":int(id),"amount":1,"bless_raw":1,"enchant":0})
	var staged: Dictionary = INVENTORY.stage(world,lines,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	var out: Array[String] = []
	if not check(staged.get("ok",false) and world._save_game(true,staged.overrides)==OK, "physical grant of %s: %s" % [str(ids),str(staged.get("error",""))]): return out
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	for id: Variant in ids:
		for key: String in world.item_instances:
			if out.has(key): continue
			if int(world.item_instances[key].get("record",{}).get("source_item_class_id",-1))==int(id): out.append(key); break
	return out

func equip(world: Node, physical: String, slot: String = "") -> bool:
	world._equip_or_acquire_item(world.item_instances[physical].record,false,physical,slot)
	world._invalidate_equipment_static()
	return world._is_instance_equipped(physical)

func reload(world: Node) -> void:
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world._load_game(true)
	await process_frame
	world._invalidate_equipment_static()

## One item: stat before -> equipped -> after reload -> removed.
func stat_case(world: Node, name: String, pick: Dictionary, reader: Callable, expected: float) -> void:
	var full: Dictionary = F.full(world._catalog_item_from_source_id("m523:item:"+str(int(pick.id))))
	level_ok(world,full)
	var physical: Array[String] = fresh_grant(world,[pick.id])
	if physical.is_empty(): return
	var before: float = float(reader.call())
	var equipped: bool = equip(world,physical[0])
	var after: float = float(reader.call())
	check(equipped and is_equal_approx(after-before,expected), "%s #%d equipped: %.2f -> %.2f (source +%.2f)" % [name,int(pick.id),before,after,expected])
	check(world._save_game(true)==OK, "save with #%d equipped" % int(pick.id))
	await reload(world)
	var reloaded: float = float(reader.call())
	check(world._is_instance_equipped(physical[0]) and is_equal_approx(reloaded,after), "%s #%d after reload %.2f" % [name,int(pick.id),reloaded])
	world.equipped_items.clear(); world._invalidate_equipment_static()
	check(is_equal_approx(float(reader.call()),before), "%s returns to %.2f without the item" % [name,before])
	evidence[name] = {"id":pick.id,"before":before,"after":after,"reloaded":reloaded}

func group_case(world: Node, pick: Dictionary) -> void:
	for id: int in [pick.a,pick.b,pick.free]: level_ok(world,F.full(world._catalog_item_from_source_id("m523:item:"+str(id))))
	var physical: Array[String] = fresh_grant(world,[pick.a,pick.b,pick.free,pick.a])
	if physical.size()!=4: check(false,"four earrings granted"); return
	check(equip(world,physical[0],"earring1"), "earring #%d equipped" % int(pick.a))
	check(not equip(world,physical[1],"earring2"), "earring #%d sharing group %d is refused" % [int(pick.b),int(pick.group)])
	check(not equip(world,physical[3],"earring2"), "a second copy of #%d is refused (Ear MaxDuplicationPerItemClassID 1)" % int(pick.a))
	check(equip(world,physical[1],"earring1") and not world._is_instance_equipped(physical[0]), "#%d can replace #%d in the same slot" % [int(pick.b),int(pick.a)])
	check(equip(world,physical[2],"earring2"), "earring #%d outside the group is allowed" % int(pick.free))
	check(world._save_game(true)==OK, "save with the two earrings")
	await reload(world)
	check(world._is_instance_equipped(physical[1]) and world._is_instance_equipped(physical[2]), "both earrings stay equipped after reload")
	evidence["group"] = pick

## Existing owner (patch523_passive_items): RegenHP per TWILIGHT interval tick.
func regen_case(world: Node, pick: Dictionary) -> void:
	level_ok(world,F.full(world._catalog_item_from_source_id("m523:item:"+str(int(pick.id)))))
	var physical: Array[String] = fresh_grant(world,[pick.id])
	if physical.is_empty() or not check(equip(world,physical[0]), "#%d equipped for regen" % int(pick.id)): return
	world._refresh_equipment_effects()
	world.inventory = {} # light load: the TWILIGHT weight gate stays open
	world.hp = maxi(1,world._effective_max_hp()-1000)
	var before: int = world.hp
	world.source_item_regen_elapsed = 0.0
	var interval: float = float(world.ui_preferences.get("patch523_item_regen_interval_seconds",30.0))
	preload("res://scripts/loot/patch523_passive_items.gd").tick(world,interval)
	check(world.hp-before==int(pick.value), "#%d RegenHP tick +%d (%d -> %d)" % [int(pick.id),int(pick.value),before,world.hp])
	evidence["regen"] = {"id":pick.id,"before":before,"after":world.hp,"interval_s":interval}

## Existing owner: AttackDrainHP on a normal hit.
func drain_case(world: Node, pick: Dictionary) -> void:
	level_ok(world,F.full(world._catalog_item_from_source_id("m523:item:"+str(int(pick.id)))))
	var physical: Array[String] = fresh_grant(world,[pick.id])
	if physical.is_empty() or not check(equip(world,physical[0]), "#%d equipped for drain" % int(pick.id)): return
	world._refresh_equipment_effects()
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.setup({"name":"흡수 대상","hp":100,"atk":1,"speed":0,"drop":[]},world.player,world,null)
	monster.set_physics_process(false)
	world.hp = maxi(1,world._effective_max_hp()-1000)
	var before: int = world.hp
	var stolen: int = preload("res://scripts/loot/patch523_passive_items.gd").drain(world,monster)
	check(stolen==mini(int(pick.value),monster.hp) and world.hp-before==stolen, "#%d AttackDrainHP %d on hit (HP %d -> %d)" % [int(pick.id),int(pick.value),before,world.hp])
	monster.queue_free()
	evidence["drain"] = {"id":pick.id,"stolen":stolen}

## Normal-hit fire flat damage against a new target with no resistance (a
## reload clears the field, so each read spawns its own target).
func flat_against_fresh_target(world: Node) -> float:
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.setup({"name":"속성 대상","hp":100,"atk":1,"speed":0,"drop":[]},world.player,world,null)
	monster.set_physics_process(false); monster.element_resistance = {}
	var amount: int = world._source_elemental_flat_damage(monster)
	monster.free()
	return float(amount)

## User decision 2026-11-13: base PVP rows through the enchant single-player policy.
func pvp_case(world: Node, id: int, name: String, reader: Callable, expected: int) -> void:
	level_ok(world,F.full(world._catalog_item_from_source_id("m523:item:"+str(id))))
	var physical: Array[String] = fresh_grant(world,[id])
	if physical.is_empty(): return
	var before: int = int(reader.call())
	var equipped: bool = equip(world,physical[0])
	var after: int = int(reader.call())
	check(equipped and after-before==expected, "%s #%d: %d -> %d (source +%d)" % [name,id,before,after,expected])
	check(world._save_game(true)==OK, "save with #%d" % id)
	await reload(world)
	check(int(reader.call())==after, "%s #%d after reload %d" % [name,id,int(reader.call())])
	evidence[name] = {"id":id,"before":before,"after":after}

## User decision 2026-11-13: a save already wearing two earrings of one group
## keeps earring1 and returns earring2 to the bag once; the marker stops reruns.
func load_correction_case(world: Node, pick: Dictionary) -> void:
	for id: int in [pick.a,pick.b]: level_ok(world,F.full(world._catalog_item_from_source_id("m523:item:"+str(id))))
	var physical: Array[String] = fresh_grant(world,[pick.a,pick.b])
	if physical.size()!=2: check(false,"two earrings granted"); return
	check(equip(world,physical[0],"earring1"), "#%d in earring1" % int(pick.a))
	# An older save: both worn (written directly, as before the limit existed).
	var forced: Dictionary = world.item_instances[physical[1]].record.duplicate(true)
	forced["instance_id"] = physical[1]
	world.equipped_items["earring2"] = forced
	world.equip_group_marker = {}
	check(world._save_game(true)==OK, "older-style save with both earrings")
	await reload(world)
	check(world._is_instance_equipped(physical[0]) and not world._is_instance_equipped(physical[1]) and world.item_instances.has(physical[1]), "load keeps earring1 #%d, unequips earring2 #%d to the bag" % [int(pick.a),int(pick.b)])
	var marker: Dictionary = world.equip_group_marker
	check(marker.get("applied")==true and marker.get("released",[]).size()==1 and str(marker.released[0].slot)=="earring2", "marker records the one release (%s)" % JSON.stringify(marker))
	# Applied once: the same state written again is not re-judged on the next load.
	world.equipped_items["earring2"] = forced
	check(world._save_game(true)==OK, "save with marker and both earrings again")
	await reload(world)
	check(world._is_instance_equipped(physical[1]), "with the saved marker the correction does not run again")
	evidence["load_correction"] = {"kept":pick.a,"released":pick.b,"marker":marker}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var picks: Dictionary = scan(world)
	evidence["picks"] = picks
	if check(picks.has("resist"), "an equipable earth-resistance item"):
		await stat_case(world,"element_resist_earth",picks.resist,func() -> float: return world._player_element_resistance("earth"),float(picks.resist.value))
	if check(picks.has("flat"), "an equipable fire-damage weapon"):
		await stat_case(world,"source_elemental_flat_fire",picks.flat,func() -> float: return flat_against_fresh_target(world),float(picks.flat.value))
	if check(picks.has("ranged_crit"), "an equipable ranged-critical item"):
		await stat_case(world,"ranged_crit",picks.ranged_crit,func() -> float: return world._player_critical_rate("ranged"),float(picks.ranged_crit.value))
	if check(picks.has("crit_resist"), "an equipable melee-critical-resistance item"):
		await stat_case(world,"melee_critical_resistance",picks.crit_resist,func() -> float: return world._critical_resistance_stat("melee"),float(picks.crit_resist.value))
	if check(picks.has("pve_pct"), "an equipable PvE reduction % item"):
		await stat_case(world,"pve_damage_reduction_pct",picks.pve_pct,func() -> float: return world._pve_reduction_percent(""),float(picks.pve_pct.value))
	if check(picks.has("regen"), "an equipable RegenHP item"): await regen_case(world,picks.regen)
	if check(picks.has("drain"), "an equipable AttackDrainHP item"): await drain_case(world,picks.drain)
	if check(picks.has("group"), "two earrings sharing an EquipGroupID and one outside it"):
		await group_case(world,picks.group)
		await load_correction_case(world,picks.group)
	await pvp_case(world,286641,"pvp_flat_ignore",func() -> int: return COMBAT.pvp_flat_ignore(world,"melee"),12)
	await pvp_case(world,315922,"pvp_status_level",func() -> int: return COMBAT.status_caster_level(world,10),1)
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEMS523_EQUIP_TYPED_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
