extends SceneTree
## 장비 상시 버프 (BuffClassID on worn items) — TWILIGHT 근사 (scripts/loot/equipment_buff523.gd).
## With the original ZIP, in actual Main: 샤르나의 영웅 변신 반지 (#286632, BuffClass 78962:
## 공격 속도 +108% · 대미지 리덕션 +2 · 이동 속도 +2% · HP +100 · 시전 속도 · PolymorphSetID) worn
## adds 대미지 리덕션 +2 and the speeds; with a polymorph card worn the speed rows are not
## added (one form at a time); taking it off removes everything.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const RING := 286632
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("EQUIPMENT_BUFF523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func values(world: Node) -> Dictionary:
	world.equipment_buff523.invalidate()
	return {"damage_reduction":world.equipment_buff523.buff_value("damage_reduction"),"attack_speed":world.equipment_buff523.buff_value("attack_speed"),"move_speed":world.equipment_buff523.buff_value("move_speed")}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.level = 90
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.inventory = {}; world.item_instances = {}
	var saved_card: Variant = world.equipped_catalog.get("변신", {})
	world.equipped_catalog["변신"] = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":RING,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [RING,str(staged.get("error",""))]): world.queue_free(); await process_frame; return
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var uid: String = ""
	for key: String in world.item_instances:
		if int(world.item_instances[key].get("record",{}).get("source_item_class_id",-1)) == RING: uid = key
	var buff: Dictionary = world.equipment_buff523.buff_of(world.item_instances[uid].record)
	evidence["buff"] = buff
	check(int(buff.get("buff_id",0)) == 78962 and bool(buff.get("polymorph",false)) and int(buff.values.get("damage_reduction",0)) == 2 and int(buff.values.get("attack_speed",0)) == 108, "BuffClass 78962 rows: "+str(buff))
	var before: Dictionary = values(world)
	world._equip_or_acquire_item(world.item_instances[uid].record,false,uid,"")
	world._invalidate_equipment_static()
	var worn: Dictionary = values(world)
	evidence["values"] = {"before":before,"worn":worn,"equipped":world._is_instance_equipped(uid),"total_dr":world._active_item_buff_total("damage_reduction")}
	check(world._is_instance_equipped(uid) and int(worn.damage_reduction) == 2 and int(worn.attack_speed) == 108 and int(worn.move_speed) == 2, "worn: 리덕션 +2, 공속 +108%, 이속 +2% "+str(evidence.values))
	# A polymorph card worn: the ring's speed rows are not stacked.
	var card: Dictionary = {}
	for value: Variant in world.catalog_db.get("변신", []):
		if value is Dictionary: card = value; break
	world.equipped_catalog["변신"] = card.duplicate(true)
	var with_card: Dictionary = values(world)
	evidence["with_card"] = with_card
	check(card.is_empty() or (int(with_card.damage_reduction) == 2 and int(with_card.attack_speed) == 0 and int(with_card.move_speed) == 0), "polymorph card worn: speeds not stacked "+str(with_card))
	world.equipped_catalog["변신"] = saved_card
	world.equipped_items.clear(); world._invalidate_equipment_static()
	var off: Dictionary = values(world)
	check(int(off.damage_reduction) == 0 and int(off.attack_speed) == 0, "taken off: none "+str(off))
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else: check(true, "without the original ZIP nothing is read")
	print("EQUIPMENT_BUFF523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
