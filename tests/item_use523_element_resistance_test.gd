extends SceneTree
## Exact installed definitions, through Main's selected inventory activation.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const SAMPLES={
	5:[122734,125592,127314,145003,147782,179234,201392,227221,227301],
	7:[125562,127334,152163],
	10:[6431,168574,183483,186281,195412,206311,211143,216234,222063,222773,246083,282443,290512,293691,295961,301562,309874,318601,325232,332084,343454,348898,358373,367172]
}
const CHANNELS=["fire","water","wind","earth"]
var checks: int=0
var failures: Array[String]=[]
var rejected: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func reject_save(_path: String,data: Dictionary) -> Error:
	rejected=data
	return ERR_CANT_CREATE
func run() -> void:
	var bounded_archive: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--bounded-source="):bounded_archive=argument.trim_prefix("--bounded-source=")
	var world: TwilightWorld
	if not bounded_archive.is_empty():
		# A machine without the memory budget for the full cold startup can
		# boot Main without source, then register these two exact original rows.
		check(SOURCE.not_installed(),"bounded mode needs a clean profile without a preinstalled source")
		if failures.is_empty():
			world=start_main()
			var dormant_awakening_saveable: bool=world.skill_awakening.definitions_not_installed() and not world.skill_awakening.blocks_save()
			check(dormant_awakening_saveable,"untouched unrelated awakening state was saveable before targeted attach")
			if dormant_awakening_saveable:
				# Keep the already saveable test-only state after late attaching;
				# otherwise the unrelated owner reads the newly installed source
				# and refuses while its own definitions have not been loaded.
				world.skill_awakening.problem=""
				OS.set_environment("TWILIGHT_PATCH523_CONTENT",bounded_archive)
				SOURCE.reset()
	check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"installed original archive")
	if failures.is_empty():await exercise(world)
	elif world!=null:world.queue_free()
	print("ELEMENT_RESISTANCE_ITEM523 ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func start_main() -> TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer=-100000
	check(QA.enter_game(world),"actual Main class selection")
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	return world
func exercise(world: TwilightWorld) -> void:
	for amount: int in SAMPLES:
		for id: int in SAMPLES[amount]:
			var record: Dictionary=D.definition_id(str(id)).get("native_record",{})
			var profile: Dictionary=STACK.profile(record)
			var spec: Dictionary=profile.get("spec",{})
			check(profile.get("kind")=="buff" and spec.get("activation_status")=="unrestricted" and spec.get("duration_seconds")==1800,"original timed profile "+str(id))
			for channel: String in CHANNELS:
				check(spec.get("typed_effects",{}).get("element_resist_"+channel)==amount,"exact "+channel+" resistance "+str(id))
			check(not spec.get("typed_effects",{}).has("element_resist_dark"),"no unsupported elemental channel "+str(id))
	if world==null:world=start_main()
	else:
		for id: int in [6431,122734]:
			var record: Dictionary=D.definition_id(str(id)).get("native_record",{})
			if not record.is_empty():world.catalog_db["아이템"].append(record)
		world._index_catalog_item_sources()
	var staged: Dictionary=INV.stage(world,[
		{"item_class_id":6431,"amount":2,"bless_raw":1,"enchant":0},
		{"item_class_id":122734,"amount":1,"bless_raw":1,"enchant":0}
	],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	check(staged.get("ok",false),"actual physical stacks: "+str(staged.get("error","")))
	if not staged.get("ok",false):world.queue_free();return
	world.inventory=staged.overrides.inventory
	world.item_instances=staged.overrides.item_instances
	var refs: Dictionary={}
	for uid: String in world.item_instances:
		var entry: Dictionary=world.item_instances[uid]
		var id: int=int(entry.get("record",{}).get("source_item_class_id",0))
		if id in [6431,122734]:refs[id]={"uid":uid,"key":str(entry.name),"ref":str(entry.name)+"@@@"+uid}
	check(refs.size()==2,"exact physical references")
	if refs.size()!=2:world.queue_free();return
	var item: Dictionary=refs[6431];var expired: Dictionary=refs[122734]
	var baseline: Dictionary={}
	for channel: String in CHANNELS+["dark","physical"]:
		baseline[channel]=world._player_element_resistance(channel)
	var original_policy: bool=D.rotate_ended_dates
	D.rotate_ended_dates=false
	world.hud.inventory_item_activated.emit(expired.ref)
	D.rotate_ended_dates=original_policy
	check(world.inventory.get(expired.key)==1 and world.active_item_buffs.is_empty(),"strict expired-policy refuses and preserves stock")
	world.ui_preferences.item_locks={item.ref:true}
	world.hud.inventory_item_activated.emit(item.ref)
	check(world.inventory[item.key]==2 and world.active_item_buffs.is_empty(),"locked selection refuses")
	world.ui_preferences.item_locks={}
	var baseline_save: Error=world._save_game(false)
	check(baseline_save==OK,"save baseline: "+error_string(baseline_save)+" / "+str(world.hud.message_label.text))
	var before: PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
	var old_inventory: Dictionary=world.inventory.duplicate(true)
	var old_uid: Dictionary=world.item_instances.duplicate(true)
	var old_state: Dictionary=world.consumable_service.export_state().duplicate(true)
	world.equipment_collections.test_save_writer=reject_save
	world.hud.inventory_item_activated.emit(item.ref)
	check(rejected.get("inventory",{}).get(item.key)==1 and rejected.get("active_item_buffs",{}).get(item.key,{}).get("element_resist_fire")==10,"debit and buff share the same save candidate")
	check(world.inventory==old_inventory and world.item_instances==old_uid and world.consumable_service.export_state()==old_state and world.active_item_buffs.is_empty() and FileAccess.get_file_as_bytes(world.save_path())==before,"failed write commits neither stock nor buff")
	world.equipment_collections.test_save_writer=Callable()
	world.patch523_owner_state_problem=""
	world.hud.inventory_item_activated.emit(item.ref)
	check(world.inventory[item.key]==1 and STACK.proof(world,item.uid).get("remaining")==1,"successful activation spends exactly selected unit")
	check(world.active_item_buffs.get(item.key,{}).get("duration")==1800,"source buff duration")
	for channel: String in baseline:
		var expected: float=float(baseline[channel])+(10.0 if channel in CHANNELS else 0.0)
		check(is_equal_approx(world._player_element_resistance(channel),expected),"World incoming resistance "+channel)
	var rng_after: int=world.rng.state
	world.hud.inventory_item_activated.emit(item.ref)
	check(world.inventory[item.key]==1 and world.rng.state==rng_after,"source 500ms cooldown blocks repeated use")
	world.active_item_buffs.clear()
	world._load_game(true)
	check(world.inventory[item.key]==1 and STACK.proof(world,item.uid).get("remaining")==1 and world.active_item_buffs.get(item.key,{}).get("element_resist_fire")==10,"real save reload restores effect and remaining proof")
	world._tick_item_buffs(1801)
	check(world.active_item_buffs.is_empty() and is_equal_approx(world._player_element_resistance("fire"),float(baseline.fire)),"timer expires and no resistance leaks")
	world.queue_free()
	await process_frame
