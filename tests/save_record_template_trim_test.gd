extends SceneTree
## Owned item records are saved without the heavy definition fields that are
## exactly the installed template's (save_provenance_trim.gd for_file /
## loaded_save, user 2026-11-19 "쓸데없이 비용만 차지하는 데이터 다 삭제").
## Rules: exact round trip, differing values kept, nothing shortened when a
## template key is missing from the record, no template -> stays marked (never
## saved bare), input never edited. With the original definition ZIP: actual
## Main saves smaller records and reloads the identical full records, bag and
## ownership; save -> load -> save keeps the bag.
const TRIM = preload("res://scripts/loot/save_provenance_trim.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakeStore extends Object:
	var rows: Dictionary = {}
	func record(id: String) -> Variant: return rows.get(id)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SAVE_RECORD_TEMPLATE_TRIM_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var store := FakeStore.new()
	var row := {"ID":366.0,"MaxStackAmount":10000.0,"Name":"가죽"}
	store.rows["366"] = {"name":"가죽","source_item_class_id":366,"source_original_item":row,"source_use_spec":{"kind":"none"},"source_class_ids":[1,2],"source_weight":1}
	store.rows["9"] = {"name":"검","source_item_class_id":9,"source_original_item":{"ID":9.0},"source_use_spec":{}}
	FIELDS.bind(store)
	var full := {"name":"가죽","slot":"material","source_m_native_item":true,"source_item_class_id":366,"source_original_item":row.duplicate(true),"source_use_spec":{"kind":"none"},"source_class_ids":[1,2],"source_weight":1,"level_note":"x"}
	var before: Dictionary = full.duplicate(true)
	var slim: Dictionary = TRIM.slim_record(full)
	check(full == before, "slim_record never edits its input")
	check(slim.get(TRIM.SAVED_TEMPLATE) == true and not slim.has("source_original_item") and not slim.has("source_use_spec") and slim.level_note == "x" and slim.name == "가죽", "template-equal heavy fields left out, light fields kept")
	check(JSON.stringify(slim).length() < JSON.stringify(full).length(), "shorter on disk")
	check(TRIM.expand_record(slim) == full, "load puts back the exact record")
	var changed: Dictionary = full.duplicate(true); changed.source_use_spec = {"kind":"edited"}
	var changed_slim: Dictionary = TRIM.slim_record(changed)
	check(changed_slim.source_use_spec == {"kind":"edited"} and TRIM.expand_record(changed_slim) == changed, "a value differing from the template is kept")
	var missing: Dictionary = full.duplicate(true); missing.erase("source_weight")
	check(is_same(TRIM.slim_record(missing), missing), "a record lacking a template field is not shortened (round trip would add it)")
	var other: Dictionary = {"name":"검","source_m_native_item":false,"source_item_class_id":9,"source_original_item":{"ID":9.0}}
	check(is_same(TRIM.slim_record(other), other), "non-native records untouched")
	var unknown: Dictionary = full.duplicate(true); unknown.source_item_class_id = 777
	check(is_same(TRIM.slim_record(unknown), unknown), "no template -> not shortened")
	var save: Dictionary = {"item_instances":{"u1":{"name":"가죽","level":0,"record":full.duplicate(true),"source_native_stack_quantity":3}},"warehouse":{"stacks":{},"instances":{"w1":{"name":"가죽","level":0,"record":full.duplicate(true)}}},"ground_drops":[{"id":"g","player_dropped":true,"item_record":full.duplicate(true),"physical_item":{"id":"p","data":{"name":"가죽","record":full.duplicate(true)}}}]}
	var save_before: Dictionary = save.duplicate(true)
	var on_disk: Dictionary = TRIM.for_file(save)
	check(save == save_before, "for_file never edits the live save")
	check(on_disk.item_instances.u1.record.has(TRIM.SAVED_TEMPLATE) and on_disk.warehouse.instances.w1.record.has(TRIM.SAVED_TEMPLATE) and on_disk.ground_drops[0].item_record.has(TRIM.SAVED_TEMPLATE) and on_disk.ground_drops[0].physical_item.data.record == on_disk.ground_drops[0].item_record, "bag, warehouse and floor records shortened alike")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(on_disk))
	TRIM.loaded_save(parsed)
	check(parsed.item_instances.u1.record.source_original_item == row and not parsed.item_instances.u1.record.has(TRIM.SAVED_TEMPLATE) and parsed.warehouse.instances.w1.record.source_use_spec == {"kind":"none"}, "loaded records are full again")
	check(int(parsed.item_instances.u1.source_native_stack_quantity) == 3, "quantity kept")
	var again: Dictionary = TRIM.for_file(parsed)
	check(JSON.stringify(again, "", true, true) == JSON.stringify(JSON.parse_string(JSON.stringify(on_disk)), "", true, true), "save -> load -> save writes the same form")
	FIELDS.bind(null)
	var kept: Dictionary = TRIM.expand_record(slim)
	check(kept.has(TRIM.SAVED_TEMPLATE) and is_same(TRIM.slim_record(kept), kept), "without a definition a marked record stays marked (never saved bare)")
	store.free()

var _prior_files: Dictionary = {}
func remember_user_files() -> void:
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save"): _prior_files[name] = FileAccess.get_file_as_bytes(directory.path_join(name))
func restore_user_files() -> void:
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save") and not _prior_files.has(name): DirAccess.remove_absolute(directory.path_join(name))
	for name: String in _prior_files:
		var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
		if file != null: file.store_buffer(_prior_files[name]); file.close()

## Equipment enhancement options are re-derived on every load
## (world._refresh_patch523_equipment_options), with or without this change.
const DERIVED := ["enhancement_options","enhancement_extra_options","patch523_blessing_bonus","patch523_effect_basis","patch523_invoke_options"]
func without_derived(entry: Dictionary) -> Dictionary:
	var copy: Dictionary = entry.duplicate(true)
	if copy.get("record") is Dictionary:
		for key: String in DERIVED: copy.record.erase(key)
	return copy

func norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)

func grant(world: Node, id: int, amount: int) -> bool:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [id, str(staged.get("error",""))]): return false
	if not check(world._save_game(true,staged.overrides) == OK, "grant #%d save" % id): return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return true

func runtime() -> void:
	remember_user_files()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	check(world._save_game(true) == OK, "clean bag save")
	for id: int in [366, 237, 313, 377]: grant(world, id, 1 if id == 377 else 3)
	var records: Dictionary = {}
	for uid: String in world.item_instances: records[uid] = world.item_instances[uid].duplicate(true)
	var bag: Dictionary = world.inventory.duplicate(true); var weight: int = world._inventory_total_weight()
	check(world._save_game(true) == OK, "save")
	var text: String = FileAccess.get_file_as_string(world.save_path())
	var saved: Dictionary = JSON.parse_string(text)
	var marked: int = 0; var disk_bytes: int = 0; var memory_bytes: int = 0
	for uid: String in saved.get("item_instances",{}):
		if saved.item_instances[uid].get("record",{}).has(TRIM.SAVED_TEMPLATE): marked += 1
		disk_bytes += JSON.stringify(saved.item_instances[uid]).length()
		memory_bytes += JSON.stringify(records.get(uid,{})).length()
	evidence["records"] = {"marked":marked,"of":saved.get("item_instances",{}).size(),"disk_bytes":disk_bytes,"full_bytes":memory_bytes}
	check(marked == records.size() and marked >= 4 and disk_bytes*2 < memory_bytes, "every owned record is shortened on disk (%s)" % str(evidence.records))
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)
	check(world.patch523_owner_state_problem.is_empty() and not world.source_item_save_blocked, "reload without an ownership problem")
	var same: bool = world.item_instances.size() == records.size()
	for uid: String in records:
		if norm(without_derived(world.item_instances.get(uid,{}))) != norm(without_derived(records[uid])):
			same = false; evidence["differs"] = uid
			var now: Dictionary = JSON.parse_string(JSON.stringify(world.item_instances.get(uid,{})))
			var was: Dictionary = JSON.parse_string(JSON.stringify(records[uid]))
			var keys: Array = []
			for key: Variant in now.keys() + was.keys():
				if JSON.stringify(now.get(key)) != JSON.stringify(was.get(key)): keys.append(str(key))
			var record_keys: Array = []
			for key: Variant in now.get("record",{}).keys() + was.get("record",{}).keys():
				if JSON.stringify(now.get("record",{}).get(key)) != JSON.stringify(was.get("record",{}).get(key)) and not str(key) in record_keys: record_keys.append(str(key))
			evidence["differs_keys"] = {"entry":keys,"record":record_keys,"name":str(was.get("name",""))}
		if world.item_instances.get(uid,{}).get("record",{}).has(TRIM.SAVED_TEMPLATE): same = false; evidence["still_marked"] = uid
	check(same, "memory holds the identical full records after reload")
	check(norm(world.inventory) == norm(bag) and world._inventory_total_weight() == weight, "bag counts and weight unchanged")
	for uid: String in world.item_instances:
		if world.item_instances[uid].has(STACK.RECEIPT): check(not STACK.proof(world, uid).is_empty(), "ownership proof %s" % uid.left(6))
	var first_load: Dictionary = {}
	for uid: String in world.item_instances: first_load[uid] = norm(world.item_instances[uid])
	for round: int in range(2):
		check(world._save_game(true) == OK, "save round %d" % round)
		world.item_instances = {}; world.inventory = {}
		world._load_game(true)
		var stable: bool = world.item_instances.size() == first_load.size()
		for uid: String in first_load:
			if norm(world.item_instances.get(uid,{})) != first_load[uid]: stable = false
		check(stable, "reload %d gives exactly the same full records (derived options included)" % round)
	check(norm(world.inventory) == norm(bag) and world.item_instances.size() == records.size(), "save -> load repeated keeps the bag")
	world.queue_free()
	await process_frame
	restore_user_files()

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		await runtime()
	print("SAVE_RECORD_TEMPLATE_TRIM_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
