extends SceneTree
## Same results, less work per pickup/kill/save (coordinator 2026-11-20:
## pickups 583 ms, saves 1.3-1.6 s stalled hunting):
## - account stage_save reuses the envelope of the file this process last
##   wrote/read while its SHA-256 is unchanged (no second parse + validate),
##   and _seal does not re-prove its own projection: the staged payload is
##   byte-identical to the full path, and any outside file change falls back;
## - current523_native_stack.proof_entry results are reused for an equal
##   entry and the same definition identity;
## - events_domain.event skips quests that have no goal of the event's kind
##   (and kinds no goal type can match): identical state to the full scan;
## - unconfirmed523 live events use the light event context.
const STORE = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const ACQUIRE = preload("res://scripts/loot/source523_ground_acquisition.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakeCatalog extends RefCounted:
	var problem: String = ""
	func profile(id: int, gender: int) -> Dictionary:
		return {"name":STORE.JOBS[id],"stats":{"str":16,"dex":13,"con":16,"int":8,"wis":7,"cha":8},"source":{"ID":id}} if STORE.JOBS.has(id) and gender in [1,2] else {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SAVE_PATH_COST_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func sorted(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)

func account_rules() -> void:
	var base: String = "user://save-path-cost-" + str(Time.get_ticks_usec())
	var store = STORE.new(); store.path = base + ".json"
	store.open()
	var first: Dictionary = store.create_character("비용첫째",1,1,FakeCatalog.new())
	store.create_character("비용둘째",3,2,FakeCatalog.new())
	if not check(first.get("ok",false) and store.select_character(first.id).get("ok",false), "account with two characters"):
		cleanup(base); return
	var body: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path)); STORE.expand(body)
	body.gold = 5; body.inventory = {"가죽":3}
	var items: Dictionary = {}
	for index: int in 50: items["%032x" % index] = {"name":"가죽","level":0,"record":{"name":"가죽"}}
	body.item_instances = items
	STORE.forget_durable()
	var slow: Dictionary = STORE.stage_save(store.path, body)
	check(slow.get("ok",false) and STORE.validate(slow.payload).is_empty(), "full path stages a valid payload")
	check(WRITER.write(store.path, STORE.compact(slow.payload)) == OK, "written like world._save_game")
	STORE.remember_durable(store.path, slow.payload[STORE.KEY])
	body.gold = 6
	var started: int = Time.get_ticks_usec()
	var fast: Dictionary = STORE.stage_save(store.path, body)
	var fast_usec: int = Time.get_ticks_usec() - started
	STORE.forget_durable()
	started = Time.get_ticks_usec()
	var full: Dictionary = STORE.stage_save(store.path, body)
	var full_usec: int = Time.get_ticks_usec() - started
	evidence["stage_usec"] = {"fast":fast_usec,"full":full_usec}
	check(fast.get("ok",false) and full.get("ok",false), "both paths stage")
	check(sorted(fast.get("payload",{})) == sorted(full.get("payload",{})), "trusted stage == full stage (same bytes after JSON)")
	check(STORE.validate(fast.payload).is_empty(), "the trusted result passes the full validate()")
	# An outside change of the file is never trusted.
	STORE.remember_durable(store.path, slow.payload[STORE.KEY])
	var other: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	other[STORE.KEY].revision = int(other[STORE.KEY].revision) + 7
	WRITER.write(store.path, other)
	var after_change: Dictionary = STORE.stage_save(store.path, body)
	check(after_change.get("ok",false) and int(after_change.payload[STORE.KEY].revision) >= int(other[STORE.KEY].revision), "a changed file is re-read (its newer revision wins)")
	STORE.remember_durable(store.path, after_change.payload[STORE.KEY])
	var broken: Dictionary = other.duplicate(true); broken[STORE.KEY].characters = []
	WRITER.write(store.path, broken)
	check(not STORE.stage_save(store.path, body).get("ok",true), "a damaged outside file is still rejected (no stale trust)")
	cleanup(base)

func cleanup(base: String) -> void:
	STORE.forget_durable(); STORE.session.clear()
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with(base.get_file()): DirAccess.remove_absolute(directory.path_join(name))

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

func runtime() -> void:
	remember_user_files()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	for id: int in [366, 237, 313]:
		var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":3,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if check(staged.get("ok",false), "grant #%d" % id) and check(world._save_game(true,staged.overrides) == OK, "grant save #%d" % id):
			world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var same: bool = true; var proven: int = 0
	for uid: String in world.item_instances:
		var entry: Dictionary = world.item_instances[uid]
		if not entry.has(STACK.RECEIPT): continue
		var cached: Dictionary = STACK.proof_entry(entry, uid); var again: Dictionary = STACK.proof_entry(entry, uid)
		var direct: Dictionary = STACK._proof_entry(entry, uid)
		if sorted(cached) != sorted(direct) or sorted(again) != sorted(direct): same = false
		if not direct.is_empty(): proven += 1
		var edited: Dictionary = entry.duplicate(true); edited[STACK.QUANTITY] = int(edited[STACK.QUANTITY]) + 1
		if sorted(STACK.proof_entry(edited, uid)) != sorted(STACK._proof_entry(edited, uid)): same = false
	check(same and proven >= 3, "cached proofs equal direct proofs, an edited entry is re-proven (%d)" % proven)
	var domain: Variant = world.unconfirmed523.domains.get("events")
	if check(domain != null, "events domain"):
		var context: Dictionary = world.unconfirmed523._fresh_context(world.unconfirmed523.state)
		var state: Dictionary = world.unconfirmed523.state.domains.events
		for kind: String in ["kill","pickup","blessing_use","item_use"]:
			var event: Dictionary = {"kind":kind,"source_id":45,"amount":1,"event_id":"cost:"+kind}
			domain.goal_kind_filter = false
			var started: int = Time.get_ticks_usec()
			var reference: Dictionary = domain.event(event, context, state)
			var full_usec: int = Time.get_ticks_usec() - started
			domain.goal_kind_filter = true
			started = Time.get_ticks_usec()
			var filtered: Dictionary = domain.event(event, context, state)
			evidence["event_usec_"+kind] = {"full":full_usec,"filtered":Time.get_ticks_usec()-started}
			check(sorted(filtered) == sorted(reference), "%s event: filtered scan == full scan" % kind)
	await deferred_pickup(world)
	var saves: Array = []
	for round: int in range(3):
		var started: int = Time.get_ticks_usec()
		check(world._save_game(true) == OK, "save %d" % round)
		saves.append(Time.get_ticks_usec() - started)
	evidence["save_usec"] = saves
	var bag: String = sorted(world.inventory)
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)
	check(sorted(world.inventory) == bag and world.patch523_owner_state_problem.is_empty(), "reload keeps the bag")
	check(world._save_game(true) == OK, "save after reload (envelope remembered from the load)")
	world.queue_free()
	await process_frame
	STORE.forget_durable(); STORE.session.clear()
	restore_user_files()

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
	if not is_instance_valid(view):
		evidence["pick_problem_"+id] = {"records":world.ground_loot.records.has(id)}
		return {"ok":false,"id":id}
	view.set("visible_since", Time.get_ticks_msec()-world.ground_loot.MIN_VISIBLE_MS-50)
	var floor: Dictionary = world.ground_loot.records.get(id,{})
	world.player.global_position = Vector2(float(floor.position[0]), float(floor.position[1]))
	var started: int = Time.get_ticks_usec()
	var ok: bool = world._collect_ground_drop(view)
	return {"ok":ok,"usec":Time.get_ticks_usec()-started,"id":id}

## A source floor pickup is validated at once and written by the batched save.
func deferred_pickup(world: Node) -> void:
	var entry: Dictionary = floor_entry(366)
	if not check(not entry.is_empty(), "an original 가죽 drop row"): return
	world.deferred_save_enabled = true
	world.deferred_save.cancel()
	check(world._save_game(true) == OK, "settled save before the pickup")
	var name_value: String = str(entry.item_name)
	var before: int = int(world.inventory.get(name_value,0))
	var sha: String = FileAccess.get_sha256(world.save_path())
	var first: Dictionary = await pick(world, entry)
	evidence["pickup_usec"] = [first.get("usec",0)]
	check(first.ok and int(world.inventory.get(name_value,0)) == before+1, "pickup adopted in memory")
	check(FileAccess.get_sha256(world.save_path()) == sha and world.deferred_save.pending(), "no file write in the pickup frame; batched save pending")
	# Crash before the batched save: the item is back on the floor, not in the bag.
	world.deferred_save.cancel()
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)
	for frame: int in range(20): await process_frame
	var on_floor: int = 0
	for record: Dictionary in world.ground_loot.records.values():
		if str(record.get("id","")) == str(first.id): on_floor += 1
	check(int(world.inventory.get(name_value,0)) == before and on_floor == 1, "without the batched save: bag unchanged, item still on the floor (no duplicate, no loss)")
	var second: Dictionary = await pick(world, entry)
	evidence["pickup_usec"].append(second.get("usec",0))
	check(second.ok and world.deferred_save.pending(), "second pickup pending")
	check(world._save_game(true) == OK, "batched save writes it")
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)
	for frame: int in range(20): await process_frame
	var left: int = 0
	for record: Dictionary in world.ground_loot.records.values():
		if str(record.get("id","")) == str(second.id): left += 1
	check(int(world.inventory.get(name_value,0)) == before+1 and left == 0 and world.patch523_owner_state_problem.is_empty(), "after the batched save: one item in the bag, gone from the floor")

func run() -> void:
	account_rules()
	if not SOURCE.not_installed():
		await runtime()
	print("SAVE_PATH_COST_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
