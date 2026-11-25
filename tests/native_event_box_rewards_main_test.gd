extends SceneTree

const Boxes = preload("res://scripts/loot/native_event_boxes523.gd")
const Source = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const Fields = preload("res://scripts/loot/current523_native_fields.gd")
const Inv = preload("res://scripts/loot/patch523_item_inventory.gd")
const Stack = preload("res://scripts/loot/current523_native_stack.gd")
const Retired = preload("res://scripts/quests/retired_quest_items523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks := 0
var opened := 0

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		printerr("EVENT_BOX_FAIL ",message)
	return value

func _initialize() -> void: run.call_deferred()

func run() -> void:
	check(Boxes.RULES.size() == 150,"reviewed original Balrog sources")
	var required := {}
	for id: int in Boxes.RULES:
		required[id] = true
		for row: Array in Boxes.RULES[id][1]:
			check(row.size() == 4 and row[0] != id and row[1] > 0 and row[2] >= 0 and (row[3] == -1) == Retired.IDS.has(row[0]), "valid row or expressly retired output #"+str(id))
			if row[3] >= 0: required[row[0]] = true
	check(Boxes.RULES[212671][1] == [[212661,1,7,0]] and Boxes.RULES[229702][1] == [[229662,1,0,-1],[229622,1,0,0],[229712,1,0,0]],"correct Balrog +7 weapon and first growth cube")
	var archive := OS.get_environment("TWILIGHT_EVENT_BOX_DEFINITIONS")
	if not archive.is_empty() and check(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated QA profile"):
		await exact(archive,required)
	print("NATIVE_EVENT_BOX_RESULT ",JSON.stringify({"checks":checks,"opened":opened,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exact(archive: String, required: Dictionary) -> void:
	var w: Node = load("res://Main.tscn").instantiate()
	root.add_child(w)
	w.set_process(false)
	w.save_timer = -100000
	check(QA.enter_game(w),"real Main entered")
	await process_frame
	w.field_population.set_process(false)
	w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	Source.reset()
	check(Source.identity().get("source_sha256") == Source.SOURCE_SHA,"pinned original 523 definitions")
	w.skill_awakening = w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	var records := {}
	for id: int in required:
		var row := D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
		if not check(not row.is_empty(),"registered original participant #"+str(id)): continue
		records[id] = row
		w.catalog_db["아이템"].append(row)
	w._index_catalog_item_sources()
	var baseline: Dictionary = w.inventory.duplicate(true)
	var instances: Dictionary = w.item_instances.duplicate(true)
	var base_state: Dictionary = w.consumable_service.export_state()
	for id: int in Boxes.RULES:
		w.inventory = baseline.duplicate(true)
		w.item_instances = instances.duplicate(true)
		w.consumable_service.import_state(base_state.duplicate(true))
		var record: Dictionary = records[id]
		var spec: Dictionary = Fields.field(record,"source_use_spec",{})
		if not check(spec.get("kind") == "source_event_box" and spec.story_desc_id == Source.row("ItemClass",id).StoryDescID and not spec.has("lucky_bag_class_id"),"source description and offline rule #"+str(id)): continue
		var classes: Array = Fields.field(record,"source_class_names",[])
		w.job_class = "기사" if classes.is_empty() else classes[0]
		w.level = maxi(1,int(Fields.field(record,"source_level_limit_min",0)))
		if not check(Inv.commit(w,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"qa_event_box"}),"issue original box #"+str(id)): continue
		var uid := ""
		for key: String in w.item_instances:
			if int(w.item_instances[key].get(Stack.RECEIPT,{}).get("item_class_id",0)) == id: uid = key
		if not check(not uid.is_empty(),"physical input #"+str(id)): continue
		var reference := str(record.name)+"@@@"+uid
		var class_id := Stack.current_class(w)
		var expected := {}
		for reward: Array in Boxes.RULES[id][1]:
			if reward[3] in [0,class_id]: expected[reward[0]] = [reward[1],reward[2]]
		if id == 212671:
			w._set_item_locked(reference,true)
			w.hud.inventory_item_activated.emit(reference)
			check(w.item_instances.has(uid),"locked receipt preserved")
			w._set_item_locked(reference,false)
			w.equipment_collections.test_save_writer = func(_path: String,_payload: Dictionary) -> Error: return ERR_CANT_CREATE
			var before := FileAccess.get_sha256(w.save_path())
			w.hud.inventory_item_activated.emit(reference)
			check(w.item_instances.has(uid) and FileAccess.get_sha256(w.save_path()) == before,"writer failure preserves box and original save bytes")
			w.equipment_collections.test_save_writer = Callable()
			w._load_game(true)
		w.hud.inventory_item_activated.emit(reference)
		if not check(not w.item_instances.has(uid),"bag use #"+str(id)+" "+str(w.hud.message_label.text)): continue
		opened += 1
		if id == 212671: w._load_game(true)
		var actual := {}
		for key: String in w.item_instances:
			var entry: Dictionary = w.item_instances[key]
			var count := int(entry.get(Stack.QUANTITY,1))
			# Stack origins deliberately retain only their kind after save compaction.
			# Compare against the pre-grant inventory; this also counts merged stacks.
			var original: Dictionary = instances.get(key,{})
			if not original.is_empty():
				count -= int(original.get(Stack.QUANTITY,1))
			if count <= 0 or not entry.get("record",{}).has("source_item_class_id"): continue
			var output := int(entry.record.source_item_class_id)
			var received: Array = actual.get(output,[0,int(entry.level)])
			received[0] += count
			actual[output] = received
		check(actual == expected,"all counts and enchant values #"+str(id)+" expected "+str(expected)+" got "+str(actual))
	w.queue_free()
	await process_frame
