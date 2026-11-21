extends SceneTree
## 물약·버프 (user report 2026-11-21 "아직 아이템 구현 안 돼서 사용 안 되는
## 거 많아"). The item-use audit found original 523 buff potions and scrolls
## (성장 물약, 요리, 버프 주문서 …) refused as storage items because their
## BuffClass used rules the projection did not read. Now:
## - AbsoluteExperienceAdditionPercent is the experience percent (TWILIGHT 근사),
##   HPPotionIncreasePercent 물약 회복률, EinasadSavingPercent 아인하사드 절약,
##   CastSpeedBonus 시전 속도, CarryPlus 소지 무게 (UIUnit Denominator 100),
##   RegenHP/RegenMP per tick of the existing regeneration interval;
## - EraseBuffOnExperience / EraseOnLevel end the buff at that level (and refuse
##   the item from that level on), IsAbsoluteTimeBuff runs in real time,
##   IgnoreUseItemDuringBuff refuses while the same buff runs, CannotUseBuffGroup
##   while that group runs; a missing ItemConsumeDelay is no delay, and a
##   non-overlapping group's newest buff replaces the older one.
## Without the pinned 523 tables only the rules run. With them every original
## consumable timed buff is projected; with --runtime each newly usable one is
## drunk from the bag in actual Main (--per limits each rule, default all).
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const NEW_KEYS = ["erase_at_level","absolute_time","ignore_use_during_buff","cannot_use_buff_groups"]
const NEW_EFFECTS = ["carry","regen_hp","regen_mp","potion_heal_pct","ain_saving_pct","cast_speed","xp"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func effect(name_value: String, unit: String, value: float) -> Dictionary:
	return {"link":{"ID":1.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},
		"bonus":{"ID":2.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":value},
		"type":{"Name":name_value},"unit":{"ID":1.0,"Name":unit}}

func definition(effects: Array, extra_rows: Array = [], buff_extra: Dictionary = {}, delay: bool = true) -> Dictionary:
	var buff: Dictionary = {"ID":77.0,"BuffGroupID":27.0,"IsGood":true,"IsBuffGroup":true,"IsEraseOnTimeEnd":true,"BuffGroupPriority":1.0,"IsImmuneToDead":false,"IsImmuneToCancellation":false}
	buff.merge(buff_extra, true)
	var group: Dictionary = {"ID":27.0,"IsAllowPriority":false,"IsEraseBySpellLevel":false,"IsAllowOverlap":false}
	var rows: Array = []
	var pairs: Array = [["BuffClassID","BuffClassID",77.0],["BuffDuration","Seconds",300.0]] + ([["ItemConsumeDelay","MilliSeconds",500.0]] if delay else []) + extra_rows
	for pair: Array in pairs:
		rows.append({"ID":float(rows.size()+10),"IsPossession":false,"bonus_type":{"Name":pair[0]},"unit":{"Name":pair[1]},"bonus":{"ID":float(rows.size()+20),"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":pair[2]}})
	return {"item_bonus":rows,"original_item":{"ID":9003.0,"TargettingTypeID":1.0,"ServiceRegionCode":""},"category":{"Name":"Potion","IsConsumable":true},
		"source_typed_references":[{"item_bonus_id":10.0,"id":77,"buff_definition":{"source":SOURCE.identity(),"ok":true,"buff_class":buff,"group":group,"bonuses":effects}}]}

class Host extends Node:
	var level: int = 50
	var active_item_buffs: Dictionary = {}

func rules() -> void:
	var regen: Dictionary = PROJECTION.timed_buff(definition([effect("RegenHP","Value",3.0),effect("RegenMP","Value",2.0),effect("EraseBuffOnExperience","CharacterLevel",80.0)],
		[["IgnoreUseItemDuringBuff","TrueFalse",1.0],["CannotUseBuffGroup","BuffGroupID",624.0]], {"IsAbsoluteTimeBuff":true}, false))
	check(regen.get("activation_status") == "unrestricted", "a regen buff with the new rules is usable: %s" % str(regen.get("blocked_reasons")))
	check(regen.get("typed_effects") == {"regen_hp":3,"regen_mp":2}, "RegenHP/RegenMP are per-tick amounts")
	check(regen.get("erase_at_level") == 80 and regen.get("absolute_time") == true and regen.get("ignore_use_during_buff") == true and regen.get("cannot_use_buff_groups") == [624], "level end, real time and the two item use rules are kept")
	check(regen.get("consume_delay_ms") == 0, "a missing ItemConsumeDelay is no delay")
	var level_end: Dictionary = PROJECTION.timed_buff(definition([effect("RegenHP","Value",1.0)], [], {"EraseOnLevel":70.0}))
	check(level_end.get("activation_status") == "unrestricted" and level_end.get("erase_at_level") == 70, "BuffClass EraseOnLevel ends the buff at that level")
	var priority: Dictionary = PROJECTION.timed_buff(definition([effect("RegenHP","Value",1.0)], [], {"BuffGroupPriority":2.0}))
	check(not priority.get("blocked_reasons", []).has("unsupported_buff_priority_or_spell_level_rule"), "a non-overlapping group with priority 2 keeps the newest buff")
	var other: Dictionary = PROJECTION.timed_buff(definition([effect("PolymorphSetID","Value",2.0)]))
	check(other.get("activation_status") == "blocked", "an unread effect still blocks")
	var host := Host.new()
	var spec: Dictionary = {"buff_class_id":77,"erase_at_level":80,"ignore_use_during_buff":true,"cannot_use_buff_groups":[624]}
	check(STACK.buff_rule_problem(host, spec).is_empty(), "below the level and with no running buff the item is usable")
	host.level = 80
	check(STACK.buff_rule_problem(host, spec).contains("Lv.79"), "from the end level the item is refused")
	host.level = 50
	host.active_item_buffs = {"a":{"source_buff_class":{"ID":77,"BuffGroupID":1}}}
	check(STACK.buff_rule_problem(host, spec).contains("같은 효과"), "IgnoreUseItemDuringBuff refuses while the same buff runs")
	host.active_item_buffs = {"a":{"source_buff_class":{"ID":5,"BuffGroupID":624}}}
	check(STACK.buff_rule_problem(host, spec).contains("함께 사용할 수 없는"), "CannotUseBuffGroup refuses while that group runs")
	host.free()

func buff_ids() -> Dictionary:
	var counts: Dictionary = {"unrestricted":0,"blocked":0}
	var usable: Array = []
	for row: Dictionary in SOURCE.rows("ItemClass"):
		if row.get("TestItem", true) != false or int(row.get("ID", 0)) <= 0: continue
		var summary: Dictionary = D.definition_id(str(int(row.ID)))
		if summary.is_empty(): continue
		var record: Dictionary = D.variant_item(summary.get("native_record", {}), 1)
		if record.is_empty() or D.equipment(record): continue
		var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {})
		if spec.get("kind") != "source_timed_buff": continue
		var status: String = str(spec.get("activation_status", ""))
		counts[status] = int(counts.get(status, 0)) + 1
		if status != "unrestricted": continue
		var uses_new: bool = false
		for key: String in NEW_KEYS: uses_new = uses_new or spec.has(key)
		for key: String in ["carry","regen_hp","regen_mp","potion_heal_pct","ain_saving_pct"]: uses_new = uses_new or spec.get("typed_effects", {}).has(key)
		if uses_new: usable.append(int(row.ID))
	return {"counts":counts,"new":usable}

var baseline: Dictionary = {}
func use(world: Node, id: int) -> Dictionary:
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}; world.active_item_buffs = {}
	world.consumable_service.import_state(baseline.duplicate(true))
	world.hp = maxi(1, world._effective_max_hp() / 2); world.mp = maxi(1, world._effective_max_mp() / 2)
	var staged: Dictionary = INV.stage(world, [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK: return {"ok":false,"reason":"stage:" + str(staged.get("error",""))}
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var name: String = ""
	for key: Variant in world.inventory: name = str(key)
	var carry_before: int = world._carrying_capacity()
	world.hud.message_label.text = ""
	world._on_inventory_item_activated(name)
	var buff: Dictionary = world.active_item_buffs.get(name, {})
	var outcome: Dictionary = {"name":name,"message":world.hud.message_label.text,"left":int(world.inventory.get(name, 0)),"buff":not buff.is_empty()}
	outcome["ok"] = outcome.left == 1 and outcome.buff
	if outcome.ok and int(buff.get("carry", 0)) > 0: outcome["carry"] = world._carrying_capacity() - carry_before == int(buff.carry)
	if outcome.ok and (int(buff.get("regen_hp", 0)) > 0 or int(buff.get("regen_mp", 0)) > 0):
		var hp_before: int = world.hp; var mp_before: int = world.mp
		world._tick_item_buffs(float(buff.get("tick_interval", 30.0)) + 0.01)
		outcome["regen"] = world.hp >= hp_before + int(buff.get("regen_hp", 0)) or world.mp >= mp_before + int(buff.get("regen_mp", 0))
	if outcome.ok and int(buff.get("erase_at_level", 0)) > 0:
		var keep: int = world.level
		world.level = int(buff.erase_at_level)
		world._tick_item_buffs(0.01)
		outcome["level_end"] = not world.active_item_buffs.has(name)
		world.level = keep
	# A refusal by the item's own original rule (직업·레벨·지역) keeps it.
	var text: String = str(outcome.message)
	if not outcome.ok and outcome.left == 2 and (text.contains("직업") or text.contains("Lv.") or text.contains("레벨") or text.contains("지역")): outcome["rule_refusal"] = true
	outcome["problem"] = str(world.patch523_owner_state_problem)
	world.patch523_owner_state_problem = ""
	return outcome

func runtime(ids: Array) -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var save_path: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.level = 40
	baseline = world.consumable_service.export_state()
	var used: int = 0; var kept: int = 0; var refused: Dictionary = {}
	var checked: Dictionary = {"carry":0,"regen":0,"level_end":0}
	for id: Variant in ids:
		var outcome: Dictionary = use(world, int(id))
		if outcome.get("rule_refusal", false): kept += 1; continue
		var good: bool = outcome.get("ok", false) and str(outcome.get("problem","")).is_empty()
		for key: String in checked:
			if outcome.has(key):
				good = good and bool(outcome[key])
				checked[key] += 1
		if good: used += 1
		else: refused[str(id)] = outcome
	check(refused.is_empty(), "every newly usable buff item is drunk from the bag: " + JSON.stringify(refused).left(1500))
	evidence["runtime"] = {"used":used,"original_rule_refused":kept,"refused":refused.size(),"checked":checked}
	world.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		var found: Dictionary = buff_ids()
		evidence["timed_buffs"] = found.counts
		evidence["newly_usable"] = found.new.size()
		check(found.new.size() > 0, "original buff items use the new rules")
		for id: int in [119392, 123592]:
			var spec: Dictionary = FIELDS.full(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1)).get("source_use_spec", {})
			evidence["spec_" + str(id)] = {"status":spec.get("activation_status"),"reasons":spec.get("blocked_reasons"),"typed":spec.get("typed_effects")}
		if "--runtime" in OS.get_cmdline_user_args(): await runtime(found.new)
	print("ITEM_USE523_BUFFS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
