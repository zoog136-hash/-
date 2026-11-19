extends SceneTree
## Original 523 acceleration potions (초록 물약, 강화 초록 물약, 용기의 물약,
## 엘븐 와퍼, 악마의 피, 드래곤의 진주) are usable from the bag and the quick
## slot (user report 2026-11-19 "이동속도 공격속도 물약류 사용 안돼").
## Their BuffClass carries RunSpritePoint (BonusType 168) applied per
## RunSpriteLevel (BonusApplicationType 394), CastSpeedBonus, a
## ConsumeTerritoryClassID item row (사용 불가 지역) and, for some, a
## BuffGroupPriority 2 or a 12.5 % value; each of those used to block the item.
## Without the pinned 523 tables only the projection rules run. With them the
## real items are checked; with --runtime they are drunk in actual Main.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## ItemClass -> [BuffClass, stage, move/attack/cast percent, seconds].
const ITEMS = {380:[40,1,25,300],235:[11111,1,25,1800],19413:[11111,1,25,1800],335:[41,2,25,300],19423:[41,2,25,300],
	321:[42,2,12.5,300],19463:[42,2,12.5,300],317:[43,2,25,600],887:[237,3,10,600]}
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func effect(name_value: String, unit: String, value: float, application: String = "", target: float = 0.0) -> Dictionary:
	return {"link":{"ID":1.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},
		"bonus":{"ID":2.0,"BonusApplicationTypeID":394.0 if application == "RunSpriteLevel" else 0.0,"BonusApplicationTargetID":target,"Value":value},
		"type":{"Name":name_value},"unit":{"ID":3.0 if unit == "Percentage" else 1.0,"Name":unit},"application_type":{"ID":394.0,"Name":application} if not application.is_empty() else {}}

func definition(effects: Array, priority: float, extra_rows: Array = []) -> Dictionary:
	var buff: Dictionary = {"ID":77.0,"BuffGroupID":27.0,"IsGood":true,"IsBuffGroup":true,"IsEraseOnTimeEnd":true,"BuffGroupPriority":priority,"IsImmuneToDead":false,"IsImmuneToCancellation":false}
	var group: Dictionary = {"ID":27.0,"IsAllowPriority":false,"IsEraseBySpellLevel":false,"IsAllowOverlap":false}
	var rows: Array = []
	for pair: Array in [["BuffClassID","BuffClassID",77.0],["BuffDuration","Seconds",300.0],["ItemConsumeDelay","MilliSeconds",500.0]] + extra_rows:
		rows.append({"ID":float(rows.size()+10),"IsPossession":false,"bonus_type":{"Name":pair[0]},"unit":{"Name":pair[1]},"bonus":{"ID":float(rows.size()+20),"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":pair[2]}})
	return {"item_bonus":rows,"original_item":{"ID":9003.0,"TargettingTypeID":1.0,"ServiceRegionCode":""},"category":{"Name":"Potion","IsConsumable":true},
		"source_typed_references":[{"item_bonus_id":10.0,"id":77,"buff_definition":{"source":SOURCE.identity(),"ok":true,"buff_class":buff,"group":group,"bonuses":effects}}]}

func rules() -> void:
	var speeds: Array = [effect("MoveSpeedBonus","Percentage",250000.0),effect("AttackSpeedBonus","Percentage",250000.0),effect("CastSpeedBonus","Percentage",250000.0)]
	var territory: Array = [["ConsumeTerritoryClassID","ConsumeTerritoryClassID",10301.0],["SpellMaterialTypeID","SpellMaterialTypeID",21.0]]
	var haste: Dictionary = PROJECTION.timed_buff(definition(speeds + [effect("RunSpritePoint","Value",1.0,"RunSpriteLevel",2.0)], 2.0, territory))
	var reasons: Array = haste.get("blocked_reasons", [])
	check(haste.get("acceleration_stage") == 2 and haste.get("forbidden_territory_class_ids") == [10301], "an acceleration buff keeps its stage and its 사용 불가 지역")
	for blocked: String in ["conditional_buff_effect:RunSpritePoint","unsupported_item_bonus:ConsumeTerritoryClassID","unsupported_item_bonus:SpellMaterialTypeID","unsupported_buff_priority_or_spell_level_rule","unsupported_buff_effect:CastSpeedBonus"]:
		check(not reasons.has(blocked) or (SOURCE.not_installed() and blocked == "unsupported_buff_effect:CastSpeedBonus"), "acceleration buff no longer blocked by " + blocked)
	if SOURCE.not_installed():
		# Without the original UIUnit scale a percentage stays unsupported, as before.
		check(haste.get("activation_status") == "blocked", "a percentage without its original UIUnit scale stays unsupported")
	else:
		check(haste.get("activation_status") == "unrestricted" and haste.get("typed_effects") == {"move_speed":25,"attack_speed":25,"cast_speed":25,"run_sprite_stage":2}, "acceleration speeds use the original percent")
		var wafer: Dictionary = PROJECTION.timed_buff(definition([effect("MoveSpeedBonus","Percentage",125000.0),effect("RunSpritePoint","Value",1.0,"RunSpriteLevel",2.0)], 1.0))
		check(wafer.get("activation_status") == "unrestricted" and is_equal_approx(float(wafer.typed_effects.get("move_speed",0)), 12.5), "a 12.5 % acceleration is kept exact")
		var plain_fraction: Dictionary = PROJECTION.timed_buff(definition([effect("MoveSpeedBonus","Percentage",125000.0)], 1.0))
		check(plain_fraction.get("activation_status") == "blocked", "a fractional percent outside acceleration still blocks")
	# Every other timed buff is unchanged: priority 2, the territory row and an
	# applied RunSpritePoint without RunSpriteLevel still block.
	var other: Dictionary = PROJECTION.timed_buff(definition([effect("PVEDamageReduction","Value",3.0)], 2.0, territory))
	check(other.get("activation_status") == "blocked" and other.blocked_reasons.has("unsupported_buff_priority_or_spell_level_rule") and other.blocked_reasons.has("unsupported_item_bonus:ConsumeTerritoryClassID") and not other.has("acceleration_stage"), "non-acceleration buffs keep their old blockers")
	var odd: Dictionary = PROJECTION.timed_buff(definition([effect("PVEDamageReduction","Value",3.0),effect("RunSpritePoint","Value",1.0,"Other",1.0)], 1.0))
	check(odd.get("activation_status") == "blocked" and odd.blocked_reasons.has("conditional_buff_effect:RunSpritePoint"), "a RunSpritePoint of another application type stays conditional")

func table() -> void:
	var rows: Dictionary = {}
	for id: int in ITEMS:
		var expected: Array = ITEMS[id]
		var spec: Dictionary = FIELDS.full(D.definition_id(str(id)).get("native_record", {})).get("source_use_spec", {})
		var typed: Dictionary = spec.get("typed_effects", {})
		var ok: bool = spec.get("kind") == "source_timed_buff" and spec.get("activation_status") == "unrestricted" and int(spec.get("buff_class_id", 0)) == int(expected[0]) \
			and int(spec.get("acceleration_stage", 0)) == int(expected[1]) and int(spec.get("duration_seconds", 0)) == int(expected[3])
		for key: String in ["move_speed","attack_speed","cast_speed"]: ok = ok and is_equal_approx(float(typed.get(key, -1)), float(expected[2]))
		rows[str(id)] = {"status":spec.get("activation_status"),"reasons":spec.get("blocked_reasons"),"typed":typed,"stage":spec.get("acceleration_stage"),"seconds":spec.get("duration_seconds")}
		check(ok, "original acceleration item projects usable: " + str(id))
	evidence["items"] = rows

func use(world: Node, id: int) -> Dictionary:
	var staged: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK: return {"granted":false,"reason":str(staged.get("error","save"))}
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var name: String = str(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1).name)
	world.hud.message_label.text = ""
	world._on_inventory_item_activated(name)
	return {"granted":true,"name":name,"count":int(world.inventory.get(name,0)),"message":world.hud.message_label.text,"buff":world.active_item_buffs.get(name,{})}

func runtime() -> void:
	var save_path: String = ""
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	save_path = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}; world.active_item_buffs = {}
	var move0: float = world._effective_move_speed_multiplier(); var attack0: float = world._effective_attack_speed_multiplier()
	var green: Dictionary = use(world, 380)
	var buff: Dictionary = green.get("buff", {})
	check(green.get("count") == 1 and buff.get("source_buff_class", {}).get("ID") == 40 and buff.get("source_snapshot") == "patch523", "the bag drinks 초록 물약 into an original BuffClass 40 buff")
	check(is_equal_approx(world._effective_move_speed_multiplier(), move0 * 1.25) and is_equal_approx(world._effective_attack_speed_multiplier(), clampf(attack0 + 0.25, 0.5, 4.0)), "초록 물약 adds the original 25 % move and attack speed")
	check(is_equal_approx(float(world.player.get("equipment_move_speed_multiplier")), world._effective_move_speed_multiplier()), "the player's move speed multiplier follows the buff")
	world.item_use_cooldowns.clear()
	check(world._quickslot_item_supported(str(green.get("name",""))), "초록 물약 is accepted by the quick slot")
	world._use_quickslot_item(str(green.get("name","")))
	check(not world.inventory.has(str(green.get("name",""))) and world.active_item_buffs.size() == 1, "the quick slot drinks the second unit and the same group keeps one buff")
	var pearl: Dictionary = use(world, 887)
	check(pearl.get("buff", {}).get("source_buff_class", {}).get("ID") == 237 and world.active_item_buffs.size() == 2, "드래곤의 진주 (3단) stacks with 1단 as another group")
	check(is_equal_approx(world._effective_move_speed_multiplier(), move0 * 1.35), "1단 25 % + 3단 10 % move speed")
	var run_points: Variant = load("res://scripts/animation/source_run_points.gd") if ResourceLoader.exists("res://scripts/animation/source_run_points.gd") else null
	if run_points != null: check(int(run_points.from_world(world).get("points", 0)) >= 1, "the run motion reads acceleration points from the buffs")
	var others: Dictionary = {}
	for id: int in [335, 321, 317]:
		world.item_use_cooldowns.clear()
		var outcome: Dictionary = use(world, id)
		others[str(id)] = {"message":outcome.get("message",""),"buff":outcome.get("buff",{}).get("source_buff_class",{}).get("ID")}
		check(outcome.get("granted", false) and (outcome.get("buff",{}).get("source_buff_class",{}).get("ID") == ITEMS[id][0] or str(outcome.get("message","")).contains("직업")), "2단 item is drunk or refused only by its original class limit: " + str(id))
	evidence["class"] = world.job_class; evidence["second_stage"] = others
	world._tick_item_buffs(700.0)
	check(world.active_item_buffs.is_empty() and is_equal_approx(world._effective_move_speed_multiplier(), move0), "expired acceleration restores the speed")
	world.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		if "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("ACCELERATION523_POTION_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
