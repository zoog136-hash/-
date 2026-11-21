extends SceneTree
## 상자 남은 것 (item-use audit 2026-11-21, after #771):
## - a selection box with some test/excluded choices dropped every choice
##   (silent in the bag): now only those choices are left out of the window;
## - a box that still cannot open (all rewards test/excluded …) says so from
##   the bag instead of staying silent (the events window no longer takes it);
## - a box whose rewards include a blessed/cursed non-equipment stack refused
##   "원본 공급 카탈로그 미등록": that stack is the variant of its registered
##   base row (as bless_stack_record reads it);
## - 성장 보상 상자 (m523-growth-item:<ItemClassID>) opens through the
##   original box rule of that ItemClassID.
## Without the pinned 523 tables only the routing rules run. With them the
## counts are checked; with --runtime the boxes are opened in actual Main.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const BOX_KINDS = ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_selectable_bag"]
## 영웅 스킬북 선택 상자(각인): one test choice; 포노스 오크 변신 카드 선택 상자:
## only test choices; 국왕의 하사품(백작): blessed/cursed scroll rewards.
const PARTLY_TEST := 167624
const ONLY_TEST := 172943
const BLESSED_REWARDS := 19543
## The 성장 보상 아이템 keys the growth96 owner grants (m523-growth-item:<ID>),
## as found in the bag audit; 371128 is the token that opens growth96.
const GROWTH_ITEMS = [123383, 146422, 146432, 146552, 146562, 146572, 146582, 147152, 175962, 200753, 245738, 254268, 328274, 95954]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func spec_of(id: int) -> Dictionary:
	return FIELDS.full(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1)).get("source_use_spec", {})

func rules() -> void:
	var stack_text: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	check(stack_text.contains("원본 보상 구성을 지원하지 않는 상자라 열 수 없습니다"), "a refused box says why")
	var events_text: String = FileAccess.get_file_as_string("res://scripts/unconfirmed523/runtime.gd")
	check(events_text.contains('item_name.begins_with("m523-growth-item:")'), "the events owner leaves 성장 보상 상자 and native boxes to the bag")
	var supply_text: String = FileAccess.get_file_as_string("res://scripts/loot/patch523_item_inventory.gd")
	check(supply_text.contains("D.variant_item(base_row, bless)"), "a blessed/cursed stack is the variant of its base catalog row")
	check(FileAccess.get_file_as_string("res://scripts/world.gd").contains("func _open_growth_reward_box("), "World opens 성장 보상 상자")

func table() -> Dictionary:
	var counts: Dictionary = {}
	var growth: Array = []
	for row: Dictionary in SOURCE.rows("ItemClass"):
		if row.get("TestItem", true) != false or int(row.get("ID", 0)) <= 0: continue
		var spec: Dictionary = spec_of(int(row.ID))
		if str(spec.get("kind", "")) not in BOX_KINDS: continue
		var key: String = str(spec.kind) + ":" + str(spec.activation_status)
		counts[key] = int(counts.get(key, 0)) + 1
	evidence["boxes"] = counts
	var partly: Dictionary = spec_of(PARTLY_TEST)
	check(partly.get("activation_status") == "unrestricted" and not partly.get("dropped_source_entity_ids", []).is_empty() and not partly.get("rewards", []).is_empty(), "a selection box keeps its other choices when one is a test row")
	check(spec_of(ONLY_TEST).get("activation_status") == "blocked", "a selection box with only test choices stays closed")
	return {"growth":growth}

var baseline: Dictionary = {}
func reset(world: Node) -> void:
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	world.consumable_service.import_state(baseline.duplicate(true))
	world._save_game(true)
	world.hud.message_label.text = ""

func stage(world: Node, id: int) -> String:
	var staged: Dictionary = INV.stage(world, [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK: return ""
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	for key: Variant in world.inventory: return str(key)
	return ""

func claim(world: Node) -> bool:
	var choice: Variant = world.hud.get_meta("patch523_reward_choice") if world.hud.has_meta("patch523_reward_choice") else null
	if not is_instance_valid(choice): return false
	var rows: Array = choice.call("original_rows")
	var ok: bool = not rows.is_empty() and bool(choice.call("claim_entity", int(rows[0].entity_id)))
	if is_instance_valid(choice): choice.free()
	if world.hud.has_meta("patch523_reward_choice"): world.hud.remove_meta("patch523_reward_choice")
	return ok

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var save_path: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.level = 85
	baseline = world.consumable_service.export_state()
	reset(world)
	var partly: String = stage(world, PARTLY_TEST)
	world._on_inventory_item_activated(partly)
	var rows: int = (world.hud.get_meta("patch523_reward_choice").call("original_rows") as Array).size() if world.hud.has_meta("patch523_reward_choice") else 0
	check(claim(world) and int(world.inventory.get(partly, 0)) == 1, "the selection box opens its window without the test choice and is used (%d rows)" % rows)
	reset(world)
	var only: String = stage(world, ONLY_TEST)
	world._on_inventory_item_activated(only)
	check(int(world.inventory.get(only, 0)) == 2 and world.hud.message_label.text.contains("열 수 없습니다"), "a box that cannot open says so: " + world.hud.message_label.text)
	reset(world)
	var blessed: String = stage(world, BLESSED_REWARDS)
	world._on_inventory_item_activated(blessed)
	var received: int = 0
	for key: Variant in world.inventory:
		if str(key) != blessed: received += 1
	check(int(world.inventory.get(blessed, 0)) == 1 and received > 0, "a box with blessed/cursed scroll rewards opens: " + world.hud.message_label.text)
	evidence["blessed_rewards"] = received
	# 성장 보상 상자: every m523-growth-item whose ItemClass is an original box.
	var opened: int = 0; var refused: Dictionary = {}
	for id: int in GROWTH_ITEMS:
		var kind: String = str(STACK.profile(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1)).get("kind", ""))
		if kind not in ["bag","selection"]: continue
		reset(world)
		var key: String = "m523-growth-item:" + str(id)
		world.inventory[key] = 2
		world._sync_item_instances(); world._save_game(true)
		world._on_inventory_item_activated(key)
		if kind == "selection": claim(world)
		var got: int = 0
		for item: Variant in world.inventory:
			if str(item) != key: got += int(world.inventory[item])
		if int(world.inventory.get(key, 0)) == 1 and (got > 0 or world.hud.message_label.text.contains("직업")): opened += 1
		else: refused[key] = world.hud.message_label.text
		world.patch523_owner_state_problem = ""
	check(opened > 0 and refused.is_empty(), "성장 보상 상자 open through their original box rule: %d, refused %s" % [opened, JSON.stringify(refused).left(800)])
	evidence["growth_boxes"] = {"opened":opened,"refused":refused.size()}
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
	print("ITEM_USE523_BOX_REMAINDERS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
