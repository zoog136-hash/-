extends SceneTree
## Original 523 equipment SpecialResistance / HitSpecialResistance (스턴·홀드·
## 공포·독 내성/적중, application type SpecialResistanceType, unit Percentage
## via UIUnit Denominator 10000) reach the existing status stats in actual Main:
## physical grant -> equip -> stat -> save -> reload. Without the original
## definition ZIP only the static mapping is checked.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const FIELDS: Array[String] = ["stun_resistance","stun_accuracy","hold_resistance","fear_resistance","fear_accuracy","poison_resistance"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_EQUIP_STATUS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(P.STATUS_BONUS.SpecialResistance=="_resistance" and P.STATUS_BONUS.HitSpecialResistance=="_accuracy", "SpecialResistance -> *_resistance, HitSpecialResistance -> *_accuracy")
	check(not P.STATUS_PREFIX.has("Ice") and not P.STATUS_PREFIX.has("Dark") and P.STATUS_PREFIX.Stun=="stun", "only statuses TWILIGHT has are mapped")

func table(world: Node) -> Dictionary:
	# Every original equipment row of these bonuses, by projected field.
	var counts: Dictionary = {}; var items: Dictionary = {}; var picks: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item")!=true or not D.equipment(record): continue
		var full: Dictionary = preload("res://scripts/loot/current523_native_fields.gd").full(record)
		for applied: Dictionary in full.get("source_mapped_bonuses",[]):
			if not applied.has("source_special_resistance_type"): continue
			counts[applied.field] = int(counts.get(applied.field,0))+1
			items[int(record.source_item_class_id)] = true
			var classes: Array = full.get("source_class_names",[])
			if not picks.has(applied.field) and int(full.get("source_level_limit_min",0))<=1 and (classes.is_empty() or classes.has(world.job_class)) and not record.get("source_delete_time_unresolved",false) and not full.has("source_delete_time_raw"):
				picks[applied.field] = {"id":int(record.source_item_class_id),"value":int(applied.value),"slot":str(record.slot)}
	evidence["projected_rows_by_field"] = counts
	evidence["items"] = items.size()
	check(items.size()==360, "360 original equipment items project a status bonus (%d)" % items.size())
	check(int(counts.get("stun_accuracy",0))==188 and int(counts.get("stun_resistance",0))==140 and int(counts.get("hold_resistance",0))==28 and int(counts.get("poison_resistance",0))==22 and int(counts.get("fear_resistance",0))==8 and int(counts.get("fear_accuracy",0))==8, "rows per status match the table (188/140/28/22/8/8)")
	return picks

func stat(world: Node, field: String) -> int:
	match field:
		"stun_resistance": return world._stun_resistance_stat()
		"stun_accuracy": return world._stun_accuracy_stat()
		"hold_resistance": return world._hold_resistance_stat()
		"fear_resistance": return world._fear_resistance_stat()
		"fear_accuracy": return world._fear_accuracy_stat()
		"poison_resistance": return world._poison_resistance_stat()
	return -1

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var picks: Dictionary = table(world)
	evidence["picks"] = picks
	var results: Dictionary = {}
	for field: String in ["stun_resistance","stun_accuracy","hold_resistance","poison_resistance"]:
		if not check(picks.has(field), "an equipable item for %s (job %s)" % [field,str(world.job_class)]): continue
		var pick: Dictionary = picks[field]
		world.equipped_items.clear(); world._invalidate_equipment_static()
		world.inventory = {}; world.item_instances = {}
		var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":int(pick.id),"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not check(staged.get("ok",false) and world._save_game(true,staged.overrides)==OK, "physical grant of #%d: %s" % [int(pick.id),str(staged.get("error",""))]): continue
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var physical: String = ""
		for id: String in world.item_instances: physical = id
		var before: int = stat(world,field)
		world._equip_or_acquire_item(world.item_instances[physical].record,false,physical)
		world._invalidate_equipment_static()
		var after: int = stat(world,field)
		var equipped: bool = world._is_instance_equipped(physical)
		var record_value: int = 0
		for record: Dictionary in world._all_equipped_records(): record_value += int(world.call("_record_"+field,record))
		# The stat adds the record value to its existing base, clamped to 100
		# (accuracy also passes the existing growth96 status curve).
		check(equipped and record_value==int(pick.value) and after>before and (after==100 or after-before>=int(pick.value)), "#%d equipped: record %s=%d, stat %d -> %d" % [int(pick.id),field,record_value,before,after])
		check(world._save_game(true)==OK, "save with #%d equipped" % int(pick.id))
		world.equipped_items.clear(); world._invalidate_equipment_static()
		world._load_game(true)
		await process_frame
		world._invalidate_equipment_static()
		var reloaded: int = stat(world,field)
		check(world._is_instance_equipped(physical) and reloaded==after, "#%d stays equipped after reload with %s %d" % [int(pick.id),field,reloaded])
		results[field] = {"id":pick.id,"slot":pick.slot,"value":pick.value,"before":before,"after":after,"reloaded":reloaded,"equipped":equipped}
	evidence["runtime"] = results
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEMS523_EQUIP_STATUS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
