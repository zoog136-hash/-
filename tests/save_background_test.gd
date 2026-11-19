extends SceneTree
## Background save (world._save_game background, coordinator 2026-11-20:
## pickups and saves within one 33 ms frame, and a crash at any moment must
## neither duplicate nor lose an item):
## - the main thread only checks and snapshots; a worker stages, serialises
##   and writes the file atomically; the bytes equal a direct save's;
## - changes made while the worker runs are kept for the next save;
## - the file is at every moment either the previous or the new complete save:
##   a floor pickup is on the floor (not in the bag) or in the bag (not on the
##   floor), never both and never neither;
## - load/quit wait for the worker.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const ACQUIRE = preload("res://scripts/loot/source523_ground_acquisition.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SAVE_BACKGROUND_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

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

func floor_entry(id: int) -> Dictionary:
	for row: Dictionary in SOURCE.related("NpcItemDropView","ItemClassID",id):
		var npc: Dictionary = SOURCE.row("NpcClass",int(row.get("NpcClassID",0)))
		if npc.is_empty(): continue
		D._current_source_document({"source_input_identity":SOURCE.identity(),"current_source_admitted":true,"source_npc_id":int(npc.ID),"source_sprite_id":npc.get("Sprite"),"source_desc_id":npc.get("DescId"),"source_name":npc.get("Name")})
		for drop: Variant in D.data().get("drops",{}).get(str(int(npc.ID)),[]):
			if not drop is Dictionary or int(drop.get("ItemClassID",0)) != id or int(drop.get("Bless",0)) != 1 or int(drop.get("RequiredQuestID",-1)) != 0: continue
			var item: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
			item["source_m_item_id"] = id; item["bless_state"] = "normal"
			var proof: Dictionary = {"source_snapshot":"patch523","source_npc_id":int(npc.ID),"source_item_class_id":id,"bless_raw":1,"bless_state":"normal","required_quest_id":0,"source_rows":[drop.duplicate(true)],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}
			item["source_m_drop_proof"] = proof
			if ACQUIRE._proof_problem(item,proof,1).is_empty(): return {"item_name":str(item.name),"quantity":1,"item_record":item,"source_m_drop_proof":proof}
	return {}

func pick(world: Node, entry: Dictionary) -> Dictionary:
	var view: Button = world._spawn_ground_drop(str(entry.item_name), world.player.global_position, 1, "", D.ground_metadata(entry))
	var id: String = str(view.get_meta("id"))
	var spawned: Button = view
	for step: int in range(80):
		await process_frame
		view = world.ground_loot.views.get(id)
		if not is_instance_valid(view) and is_instance_valid(spawned) and world.ground_loot.valid_view(spawned): view = spawned
		if is_instance_valid(view): break
		await create_timer(0.05).timeout
	if not is_instance_valid(view): return {"ok":false,"id":id}
	# The drop is made durable first (as the batched save would), so the file
	# before the pickup has it on the floor.
	world._save_game(true)
	world.deferred_save.cancel()
	var sha_before: String = FileAccess.get_sha256(world.save_path())
	var text_before: String = FileAccess.get_file_as_string(world.save_path())
	view = world.ground_loot.views.get(id) if is_instance_valid(world.ground_loot.views.get(id)) else view
	view.set("visible_since", Time.get_ticks_msec()-world.ground_loot.MIN_VISIBLE_MS-50)
	var floor: Dictionary = world.ground_loot.records.get(id,{})
	world.player.global_position = Vector2(float(floor.position[0]), float(floor.position[1]))
	var started: int = Time.get_ticks_usec()
	var ok: bool = world._collect_ground_drop(view)
	return {"ok":ok,"usec":Time.get_ticks_usec()-started,"id":id,"sha_before":sha_before,"text_before":text_before}

## Item count in the bag and whether floor id is on the floor, as a fresh
## game would load them from `text`.
func state_of(world: Node, text: String, name_value: String, floor_id: String) -> Array:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary: return [-1, false]
	var on_floor: bool = false
	for record: Variant in data.get("ground_drops",[]):
		if record is Dictionary and str(record.get("id","")) == floor_id: on_floor = true
	return [int(data.get("inventory",{}).get(name_value,0)), on_floor]

func differing_paths(left: Variant, right: Variant, prefix: String) -> Dictionary:
	var out: Dictionary = {}
	if left is Dictionary and right is Dictionary:
		for key: Variant in left.keys() + right.keys():
			if out.has(prefix+"/"+str(key)): continue
			if not left.has(key) or not right.has(key): out[prefix+"/"+str(key)] = true; continue
			out.merge(differing_paths(left[key], right[key], prefix+"/"+str(key)))
		return out
	if JSON.stringify(left) != JSON.stringify(right): out[prefix] = true
	return out

func runtime() -> void:
	remember_user_files()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world.background_save_enabled = true
	world.deferred_save_enabled = true
	check(world._save_game(true) == OK, "direct save")
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)
	for frame: int in range(20): await process_frame
	# 1. Same bytes as a direct save.
	world.gold += 7
	var started: int = Time.get_ticks_usec()
	check(world._save_game(true,{},{},false,true) == OK, "background save started")
	var main_usec: int = Time.get_ticks_usec() - started
	check(world.background_save_pending() or FileAccess.file_exists(world.save_path()), "worker owns the write")
	world._finish_background_save(true)
	var background_text: String = FileAccess.get_file_as_string(world.save_path())
	started = Time.get_ticks_usec()
	check(world._save_game(true) == OK, "direct save of the same state")
	var direct_usec: int = Time.get_ticks_usec() - started
	evidence["save_usec"] = {"background_main_thread":main_usec,"direct":direct_usec}
	var direct_text: String = FileAccess.get_file_as_string(world.save_path())
	# Clock-driven fields (latest_at, regen timers ...) may tick between two
	# saves: allow exactly the keys two direct saves of this state also differ in.
	check(world._save_game(true) == OK, "second direct save")
	var noise: Dictionary = differing_paths(JSON.parse_string(direct_text), JSON.parse_string(FileAccess.get_file_as_string(world.save_path())), "")
	var against: Dictionary = differing_paths(JSON.parse_string(background_text), JSON.parse_string(direct_text), "")
	var unexplained: Array = []
	for path: String in against:
		# Wall-clock stamps (unconfirmed523 latest_at = now()) also tick per second.
		var covered: bool = path.ends_with("/latest_at") or path.ends_with("_elapsed")
		for clock: String in noise:
			if path.begins_with(clock) or clock.begins_with(path): covered = true
		if not covered: unexplained.append(path)
	evidence["clock_paths"] = noise.keys()
	check(unexplained.is_empty() and (against.is_empty() or not noise.is_empty() or background_text == direct_text), "background file == direct file apart from clock ticks (%s)" % str(unexplained))
	check(int(JSON.parse_string(background_text).get("gold",-1)) == world.gold, "background file holds the change")
	# 2. A change made while the worker runs is kept for the next save.
	check(world._save_game(true,{},{},false,true) == OK, "second background save")
	world.gold += 11
	world._request_deferred_save()
	world._finish_background_save(true)
	check(world.deferred_save.pending(), "the later change keeps its save request")
	check(world._save_game(true) == OK and int(JSON.parse_string(FileAccess.get_file_as_string(world.save_path())).get("gold",-1)) == world.gold, "and the next save writes it")
	# 3. Crash at any moment: the pickup is either fully before or fully after.
	if not SOURCE.not_installed():
		var entry: Dictionary = floor_entry(366)
		if check(not entry.is_empty(), "an original 가죽 drop row"):
			var name_value: String = str(entry.item_name)
			var before: int = int(world.inventory.get(name_value,0))
			var picked: Dictionary = await pick(world, entry)
			evidence["pickup_usec"] = picked.get("usec",0)
			check(picked.ok and int(world.inventory.get(name_value,0)) == before+1, "pickup adopted")
			var images: Array = [str(picked.get("text_before","")), FileAccess.get_file_as_string(world.save_path())]
			check(world._save_game(true,{},{},false,true) == OK, "background save of the pickup")
			for step: int in range(50):
				images.append(FileAccess.get_file_as_string(world.save_path()))
				if not world.background_save_pending(): break
				OS.delay_usec(500)
			world._finish_background_save(true)
			images.append(FileAccess.get_file_as_string(world.save_path()))
			var consistent: bool = true; var seen: Dictionary = {}
			for text: String in images:
				var state: Array = state_of(world, text, name_value, str(picked.id))
				seen[str(state)] = true
				if not (state == [before, true] or state == [before+1, false]): consistent = false
			evidence["file_states"] = seen.keys()
			check(consistent, "every file image: item on the floor xor in the bag (%s)" % str(seen.keys()))
			check(state_of(world, images[-1], name_value, str(picked.id)) == [before+1, false], "after the worker: in the bag, gone from the floor")
			check(state_of(world, images[0], name_value, str(picked.id)) == [before, true], "before it: still on the floor, not in the bag")
			world.item_instances = {}; world.inventory = {}
			world._load_game(true)
			check(int(world.inventory.get(name_value,0)) == before+1 and world.patch523_owner_state_problem.is_empty(), "reload: exactly one picked item")
	# 4. Leaving waits for the worker.
	check(world._save_game(true,{},{},false,true) == OK, "background save before leaving")
	world.queue_free()
	await process_frame
	await process_frame
	var final: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("user://twilight_v20_save.json")) if FileAccess.file_exists("user://twilight_v20_save.json") else "{}")
	check(final is Dictionary, "the file is complete after leaving")
	restore_user_files()

func run() -> void:
	await runtime()
	print("SAVE_BACKGROUND_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
