extends SceneTree
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const U = preload("res://scripts/loot/patch523_item_use.gd")
const BOOK = preload("res://scripts/loot/patch523_skill_book.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var rejected_writes: int = 0

# Contract fixture, not the PR245 engine. No production identity is invented.
class Adapter extends RefCounted:
	var profiles: Dictionary = {}
	var bindings: Dictionary = {}
# skill_catalog.gd now declares source523 itself; the fixture only replaces it.
class BridgedCatalog extends "res://scripts/skills/skill_catalog.gd":
	pass

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("PATCH523_CHOICE_FAIL: ",label)
func reject(_path: String,_data: Dictionary) -> Error:
	rejected_writes += 1
	return ERR_CANT_CREATE
func same_inventory(a: Dictionary,b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key: String in a:
		if not b.has(key) or int(a[key]) != int(b[key]): return false
	return true
func grant(world: TwilightWorld,id: String,amount: int = 1) -> Dictionary:
	var native: Dictionary = D.data().item_definitions[id].native_record
	var record: Dictionary = world._find_catalog_item_record(str(native.name))
	if record.is_empty(): record = world._catalog_item_from_source_id(id)
	if record.is_empty():
		var binding: Dictionary = D.data().bindings.get(id,{})
		record = world._find_catalog_item_record(str(binding.get("name","")))
	check(not record.is_empty(),"canonical catalog grant "+id)
	if not record.is_empty(): world.inventory[str(record.name)] = amount
	world.item_use_cooldowns.clear()
	return record
func snapshot(world: TwilightWorld) -> Dictionary:
	return {"inventory":world.inventory.duplicate(true),"instances":world.item_instances.duplicate(true),"gold":world.gold,"rng":world.rng.state,"cooldowns":world.item_use_cooldowns.duplicate(true),"skills":world.original_skills.catalog.export_state(),"consumables":world.consumable_service.export_state(),"save":FileAccess.get_file_as_bytes(world.save_path())}
func dialog(world: TwilightWorld) -> Control:
	return world.hud.get_meta("patch523_reward_choice") if world.hud.has_meta("patch523_reward_choice") else null
func capture() -> void:
	var folder: String = OS.get_environment("TWILIGHT_DROP_CAPTURE_DIR")
	if folder.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join("patch523-choice-ui.png")) == OK,"actual rendered selection UI capture")
func run() -> void:
	check(D.install_zip(OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP")).get("ok",false),"fresh verified pack install")
	print("PATCH523_CHOICE_STAGE pack_loaded")
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false)
	check(QA.enter_game(world),"actual Main map entry")
	print("PATCH523_CHOICE_STAGE main_entered")
	world.field_population.set_process(false);world.player.set_physics_process(false)
	world._clear_monsters();world._clear_drops();world.level = 90
	world.job_class = "기사"
	var record: Dictionary = grant(world,"353364",2)
	check(world._save_game(true) == OK,"durable baseline")
	var before: Dictionary = snapshot(world)
	world._on_inventory_item_activated(str(record.name));await process_frame
	check(is_instance_valid(dialog(world)),"inventory activation opens actual selection UI")
	check(snapshot(world) == before,"opening does not consume or roll")
	await capture()
	dialog(world).find_child("CancelSourceReward",true,false).emit_signal("pressed");await process_frame
	check(snapshot(world) == before,"cancelling preserves complete state")
	check(not U.claim_selection(world,record,-1) and snapshot(world) == before,"forged entity cannot claim or debit")
	world._on_inventory_item_activated(str(record.name));await process_frame
	var popup: Control = dialog(world)
	var list: ItemList = popup.choices
	list.select(0);list.emit_signal("item_selected",0)
	var chosen_id: int = int(list.get_item_metadata(0))
	world.equipment_collections.test_save_writer = reject
	popup.confirm.emit_signal("pressed")
	world.equipment_collections.test_save_writer = Callable()
	check(rejected_writes == 1 and snapshot(world) == before,"UI save failure rolls back box, awards, RNG, save")
	check(is_instance_valid(popup) and not popup.confirm.disabled,"failed claim keeps usable UI")
	world.ui_preferences["patch523_select_reward_initial_zero_enabled"] = false
	check(not U.claim_selection(world,record,chosen_id),"local initial enchant rule can disable gear claim")
	check(snapshot(world) == before,"disabled local rule preserves complete state")
	world.ui_preferences["patch523_select_reward_initial_zero_enabled"] = true
	popup.confirm.emit_signal("pressed");popup.confirm.emit_signal("pressed");await process_frame
	check(int(world.inventory.get(str(record.name),0)) == 1,"UI double click consumes one box")
	check(world.item_instances.size() == before.instances.size()+1,"UI creates exactly one physical gear reward")
	var ids: Array = world.item_instances.keys().filter(func(key: String) -> bool: return not before.instances.has(key))
	check(ids.size() == 1 and int(world.item_instances[ids[0]].level) == 0 and world.item_instances[ids[0]].source_m_reward_proof.initial_enchant_origin == "twilight_configured_default_zero" and world.item_instances[ids[0]].source_m_reward_proof.original_initial_enchant == null,"physical source proof separates original null from host zero")
	if "--choice-ui-only" in OS.get_cmdline_user_args():
		var settings: VBoxContainer = preload("res://scripts/ui/patch523_drop_settings.gd").new()
		world.hud.add_child(settings)
		world.equipment_collections.test_save_writer = reject
		settings.select_initial.button_pressed = false
		world.equipment_collections.test_save_writer = Callable()
		check(settings.select_initial.button_pressed and world.ui_preferences.patch523_select_reward_initial_zero_enabled,"actual setting failure restores UI and preference")
		settings.select_initial.button_pressed = false
		check(not world.ui_preferences.patch523_select_reward_initial_zero_enabled,"actual setting action persists disabled initial level rule")
		var owned: Dictionary = world.inventory.duplicate(true)
		world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
		check(not world.ui_preferences.patch523_select_reward_initial_zero_enabled and same_inventory(world.inventory,owned),"actual setting and selected reward survive reentry")
		var physical: Dictionary = world.item_instances.get(ids[0],{})
		check(physical.get("source_m_reward_proof",{}).get("original_initial_enchant","lost") == null and physical.get("source_m_reward_proof",{}).get("initial_enchant_origin") == "twilight_configured_default_zero","original null and local provenance survive reentry")
		world.queue_free();await process_frame
		print("PATCH523_CHOICE_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
		quit(0 if failures.is_empty() else 1);return
	# Exercise every explicit entity option, including closure-only books/cards/gear.
	var roots: int = 0
	var options: int = 0
	for id: String in D.data().item_definitions:
		var spec: Dictionary = D.data().item_definitions[id].native_record.get("source_use_spec",{})
		if spec.get("kind") != "source_selectable_reward" or spec.get("activation_status") != "unrestricted": continue
		roots += 1
		for reward: Dictionary in spec.rewards:
			if not U.class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(world.job_class)): continue
			options += 1
			record = grant(world,id)
			var source: Dictionary = D.data().item_definitions[str(int(reward.item_class_id))].native_record
			var key: String = str(D.variant_item(source,int(reward.bless_raw)).name)
			var count: int = int(world.inventory.get(key,0))
			var rng: int = world.rng.state
			check(U.claim_selection(world,record,int(reward.source_entity_id)),"exact entity claim "+id+"/"+str(int(reward.source_entity_id)))
			check(int(world.inventory.get(str(record.name),0)) == 0 and int(world.inventory.get(key,0)) == count+int(reward.amount),"only selected exact item enters inventory "+id)
			check(world.rng.state == rng,"selection never rolls random option "+id)
	check(roots == 21 and options > 90,"all 21 source-ready selectors and their options exercised")
	print("PATCH523_CHOICE_STAGE all_options ",options)
	# New card closure uses the existing fixed-card receipt path as real items.
	for id: String in ["197711","197721","197731","197741","197751","197761","197771","199688","199698","199708","199718"]:
		record = grant(world,id)
		var card_spec: Dictionary = U.canonical(record).source_use_spec
		var total: int = world.card_draw_fusion.total_count(str(card_spec.card_kind),str(card_spec.host_card_identity))
		world._on_inventory_item_activated(str(record.name))
		check(world.card_draw_fusion.total_count(str(card_spec.card_kind),str(card_spec.host_card_identity)) == total+1 and int(world.inventory.get(str(record.name),0)) == 0,"selector card reward actual receive/reveal "+id)
		if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()
		await process_frame
	var expired: Dictionary = grant(world,"174433",2)
	before = snapshot(world)
	world._on_inventory_item_activated(str(expired.name))
	check(snapshot(world) == before,"expired source selector cannot consume or open")
	# Main currently lacks the PR245 adapter: keep the exact source book.
	record = grant(world,"241",2)
	var spec: Dictionary = U.canonical(record).source_use_spec
	check(int(spec.spell_class_id) == 83,"book card joins exact source SpellClass83")
	before = snapshot(world)
	world._on_inventory_item_activated(str(record.name))
	check(snapshot(world) == before,"missing PR245 adapter preserves book and learning")
	# Approved PR245 binding c8f909a: exact SpellClass83 and full-row SHA.
	var local_id: String = "lm_8d11f90e2d104a0a"
	var adapter := Adapter.new()
	adapter.bindings = {"skills":{local_id:{"spell_id":83,"row_sha256":str(spec.source_spell_row_sha256)}}}
	adapter.profiles = {local_id:{"row":spec.source_spell_class.duplicate(true),"row_json":str(spec.source_spell_row_json)}}
	check(not BOOK.resolve(adapter,spec).is_empty(),"real PR245 ID/SHA contract resolves exact source spell")
	adapter.bindings.skills[local_id].row_sha256 = "bad"
	check(BOOK.resolve(adapter,spec).is_empty(),"row SHA mismatch never falls back to name")
	adapter.bindings.skills[local_id].row_sha256 = str(spec.source_spell_row_sha256)
	adapter.bindings.skills[local_id].spell_id = 84
	check(BOOK.resolve(adapter,spec).is_empty(),"source spell ID mismatch rejected")
	adapter.bindings.skills[local_id].spell_id = 83
	var catalog := BridgedCatalog.new()
	catalog.configure(world);catalog.import_state({"original_skill_state":world.original_skills.catalog.export_state()})
	catalog.source523 = adapter;world.original_skills.catalog = catalog
	catalog.learned.erase(local_id)
	check(catalog.reason(catalog.record_for(local_id),true).is_empty(),"exact existing skill can learn in contract fixture")
	check(world._save_game(true) == OK,"book baseline durable")
	before = snapshot(world)
	world.equipment_collections.test_save_writer = reject
	world._on_inventory_item_activated(str(record.name))
	world.equipment_collections.test_save_writer = Callable()
	check(snapshot(world) == before,"book save failure preserves original learned state and receipt")
	world._on_inventory_item_activated(str(record.name))
	check(int(catalog.learned.get(local_id,0)) == 1 and int(world.inventory.get(str(record.name),0)) == 1,"contract fixture atomic book consume and exact local skill learning")
	check(world.consumable_service.source_skill_book_receipts.size() == 1,"exact source book provenance persisted")
	before = snapshot(world);world._on_inventory_item_activated(str(record.name))
	check(snapshot(world) == before,"duplicate learning cannot consume a second book")
	var inventory: Dictionary = world.inventory.duplicate(true)
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(same_inventory(world.inventory,inventory),"every selected item key and quantity survives JSON save reentry")
	check(int(world.original_skills.catalog.learned.get(local_id,0)) == 1 and world.consumable_service.source_skill_book_receipts.size() == 1,"book debit, learning, provenance survive real save reentry")
	world.queue_free();await process_frame
	print("PATCH523_SELECTABLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_selectors":roots,"explicit_options":options,"book_engine":"contract_fixture_only_PR245_not_installed"}))
	quit(0 if failures.is_empty() else 1)
